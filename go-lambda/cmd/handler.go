package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	errext "github.com/shekhar-jha/base-demo/go-utils/pkg/err"
	"github.com/shekhar-jha/base-demo/go-utils/pkg/log"
	"os"
	"strings"
)

func init() {
	log.Configure(log.NewConfigLogger(log.Debug, "GoLogger"), "github.com/shekhar-jha/base-demo")
}

var logger = log.GetLogger("github.com/shekhar-jha/base-demo", "go-lambda", "cmd")

type Handle[Request any, Response any] func(context Context[Request, Response]) errext.Error

type Context[Request any, Response any] interface {
	GetRequest() *Request
	SetResponse(response Response)
}

type simpleContext[Request any, Response any] struct {
	request  *Request
	response *Response
}

func (context *simpleContext[Request, Response]) GetRequest() *Request {
	return context.request
}

func (context *simpleContext[Request, Response]) SetResponse(response Response) {
	context.response = &response
}

type Application[Request any, Response any] interface {
	RegisterHandler(handle Handle[Request, Response]) Application[Request, Response]
	Run() errext.Error
}

func NewApplication[Request any, Response any]() Application[Request, Response] {
	return &simpleApplication[Request, Response]{}
}

type simpleApplication[Request any, Response any] struct {
	lambdaHandler lambda.Handler
}

func (app *simpleApplication[Request, Response]) RegisterHandler(handler Handle[Request, Response]) Application[Request, Response] {
	if os.Getenv("AWS_LAMBDA_RUNTIME_API") != "" {
		logger.LogWithLevel(log.Info, "AWS Lambda runtime detected")
		app.lambdaHandler = lambda.NewHandler(lambdaHandler(func(ctx context.Context, bytes []byte) ([]byte, error) {
			return simpleLambdaHandler(handler, ctx, bytes)
		}))
	}
	return app
}

func (app *simpleApplication[Request, Response]) Run() errext.Error {
	if app.lambdaHandler != nil {
		lambda.Start(app.lambdaHandler)
	}
	return nil
}

type lambdaHandler func(context.Context, []byte) ([]byte, error)

func (handler lambdaHandler) Invoke(ctx context.Context, payload []byte) ([]byte, error) {
	return handler(ctx, payload)
}

type ProtocolType int

const (
	Unknown ProtocolType = iota
	TCP
	HTTP
	AWS_LAMBDA_HTTP
	AWS_LAMBDA_INVOKE
)

var ErrRequestParsingError = errext.NewErrorTemplate("Parsing Error", "Failed to parse {{ .Data.Parameter }} payload as JSON due to error {{ .Data.ParseError }}")
var ErrResponseGenerationError = errext.NewErrorTemplate("Response Generation Error", "Failed to generate response payload due to error {{ .Data }}")

func simpleLambdaHandler[Request any, Response any](handler Handle[Request, Response], ctx context.Context, payload []byte) ([]byte, error) {
	readData := map[string]interface{}{}
	unmarshalErr := json.Unmarshal(payload, &readData)
	if unmarshalErr != nil {
		return nil, ErrRequestParsingError.New(struct {
			Parameter  string
			ParseError error
		}{Parameter: "Request", ParseError: unmarshalErr})
	}
	requestObject := map[string]interface{}{}
	logger.LogWithLevel(log.Debug, "Parsed request object %#v", readData)
	var eventType ProtocolType
	if _, isHTTP := asMap(readData, "requestContext", "http"); isHTTP {
		logger.LogWithLevel(log.Debug, "Request is an Lambda HTTP Request")
		eventType = AWS_LAMBDA_HTTP
		requestId, _ := asString(readData, "requestContext", "requestId")
		logger.LogWithLevel(log.Debug, "Request Id %s", requestId)
		if queryParams, hasQueryParams := asMap(readData, "queryStringParameters"); hasQueryParams {
			copyMap(queryParams, requestObject)
			logger.LogWithLevel(log.Debug, "Added query parameters %#v", queryParams)
		}
		if body, hasBody := asString(readData, "body"); hasBody {
			logger.LogWithLevel(log.Debug, "Request body is present")
			if contentType, hasContentType := asString(readData, "headers", "content-type"); hasContentType {
				switch strings.ToLower(contentType) {
				case "application/json":
					logger.LogWithLevel(log.Debug, "Parsing content type application/json")
					bodyUnmarshalError := json.Unmarshal([]byte(body), &requestObject)
					if bodyUnmarshalError != nil {
						return nil, ErrRequestParsingError.New(struct {
							Parameter  string
							ParseError error
						}{Parameter: "Body", ParseError: bodyUnmarshalError})
					}
				default:
					logger.LogWithLevel(log.Warn, "Failed to identify request body content type %s for request %s", contentType, requestId)
				}
			} else {
				logger.LogWithLevel(log.Warn, "Request body is present but no content-type header is available for validation.")
			}
		}
	} else {
		eventType = AWS_LAMBDA_INVOKE
		requestObject = readData
	}
	var requestObjectAsStruct Request
	generatedRequest, requestMarshalErr := json.Marshal(requestObject)
	if requestMarshalErr != nil {
		return nil, ErrRequestParsingError.New(struct {
			Parameter  string
			ParseError error
		}{Parameter: "ObjectMarshal", ParseError: requestMarshalErr})
	}
	requestUnmarshalErr := json.Unmarshal(generatedRequest, &requestObjectAsStruct)
	if requestUnmarshalErr != nil {
		return nil, ErrRequestParsingError.New(struct {
			Parameter  string
			ParseError error
		}{Parameter: "Request Object", ParseError: requestUnmarshalErr})
	}
	var requestContext = &simpleContext[Request, Response]{request: &requestObjectAsStruct}
	logger.LogWithLevel(log.Debug, "Invoking handler with context %v, request %#v", ctx, requestContext.request)
	err := handler(requestContext)
	logger.LogWithLevel(log.Debug, "Response %#v; Error %v", requestContext.response, err)
	switch eventType {
	case AWS_LAMBDA_INVOKE:
		if err != nil {
			return nil, err
		}
		if requestContext.response != nil {
			output, marshalErr := json.Marshal(requestContext.response)
			return output, marshalErr
		} else {
			return []byte("{}"), nil
		}
	case AWS_LAMBDA_HTTP:
		var response = events.APIGatewayV2HTTPResponse{
			StatusCode:        200,
			Headers:           nil,
			MultiValueHeaders: nil,
			Body:              "",
			IsBase64Encoded:   false,
			Cookies:           nil,
		}

		marshaledValue, marshalErr := json.Marshal(requestContext.response)
		if marshalErr != nil {
			response.Body = fmt.Sprintf("{ \"Message\" : \"%#v\"}", marshalErr)
		} else {
			response.StatusCode = 200
			response.Body = string(marshaledValue)
		}
		respByte, httpMarshalErr := json.Marshal(response)
		return respByte, httpMarshalErr
	default:
		unsupportedFormatErr := fmt.Sprintf("Event type %s is not supported", eventType)
		return nil, ErrResponseGenerationError.New(unsupportedFormatErr)
	}
}

func asString(input map[string]interface{}, key ...string) (string, bool) {
	totalKeys := len(key)
	if input == nil || totalKeys == 0 {
		return "", false
	}
	applicableMap := input
	if totalKeys > 1 {
		if processedMap, validProcess := asMap(applicableMap, key[0:totalKeys-1]...); validProcess {
			applicableMap = processedMap
		} else {
			return "", false
		}
	}
	if value, hasValue := applicableMap[key[totalKeys-1]]; hasValue && value != nil {
		if valueAsString, isString := value.(string); isString {
			return valueAsString, true
		}
	}
	return "", false
}
func asMap(input map[string]interface{}, key ...string) (map[string]interface{}, bool) {
	asMapLogger := logger.Push("asMap", key)
	logger.LogWithLevel(log.Trace, "Input: %#v", input)
	returnValue := map[string]interface{}{}
	if input == nil {
		return returnValue, false
	}
	totalKeys := len(key)
	asMapLogger.LogWithLevel(log.Trace, "Total keys: %d", totalKeys)
	if totalKeys > 0 {
		var applicableMap = input
		for remainingKeys := totalKeys; remainingKeys >= 1; remainingKeys-- {
			asMapLogger.LogWithLevel(log.Trace, "Applicable map: %v", applicableMap)
			asMapLogger.LogWithLevel(log.Trace, "Remaining keys: %d", remainingKeys)
			if value, hasValue := applicableMap[key[totalKeys-remainingKeys]]; hasValue && value != nil {
				if valueAsMap, isMap := value.(map[string]interface{}); isMap {
					applicableMap = valueAsMap
				} else {
					return returnValue, false
				}
			} else {
				return returnValue, false
			}
		}
		return applicableMap, true
	} else {
		return input, true
	}
}

func copyMap(src map[string]interface{}, dest map[string]interface{}) {
	for queryKey, value := range src {
		dest[queryKey] = value
	}
}
