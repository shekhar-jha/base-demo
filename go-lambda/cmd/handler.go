package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	errExt "github.com/shekhar-jha/base-demo/go-utils/pkg/err"
	"github.com/shekhar-jha/base-demo/go-utils/pkg/log"
	"net/http"
	"os"
	"strings"
)

func init() {
	log.Configure(log.NewConfigLogger(log.Debug, "GoLogger"), "github.com/shekhar-jha/base-demo")
}

var logger = log.GetLogger("github.com/shekhar-jha/base-demo", "go-lambda", "cmd")

type Handle[Request any, Response any] func(context Context[Request, Response]) errExt.Error

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
	Run() errExt.Error
}

func NewApplication[Request any, Response any]() Application[Request, Response] {
	return &simpleApplication[Request, Response]{}
}

type simpleApplication[Request any, Response any] struct {
	lambdaHandler lambda.Handler
	httpHandler   *http.ServeMux
}

type httpHandler[Request any, Response any] struct {
	handler Handle[Request, Response]
}

func (handler *httpHandler[Request, Response]) ServeHTTP(writer http.ResponseWriter, request *http.Request) {
	logger.LogWithLevel(log.Debug, "Invoked request with %v", request)
	var requestObjectMap = map[string]interface{}{}
	for key, value := range request.URL.Query() {
		if len(value) >= 1 {
			requestObjectMap[key] = value[0]
		}
	}
	requestObject, generateErr := createObject[Request](requestObjectMap)
	if generateErr != nil {
		writeError(writer, http.StatusInternalServerError, generateErr)
		return
	}
	var simpleContext = &simpleContext[Request, Response]{request: &requestObject}
	logger.LogWithLevel(log.Debug, "Invoking handler with request %#v", simpleContext.request)
	err := handler.handler(simpleContext)
	logger.LogWithLevel(log.Debug, "Response %#v; Error %v", simpleContext.response, err)
	if err != nil {
		writeError(writer, http.StatusInternalServerError, err)
	} else {
		responseOut, err := json.Marshal(simpleContext.response)
		if err != nil {
			writeError(writer, http.StatusInternalServerError, err)
		} else {
			writer.WriteHeader(http.StatusOK)
			writer.Header().Set("Content-Type", "application/json")
			size, writeErr := writer.Write(responseOut)
			if writeErr != nil {
				logger.LogWithLevel(log.Warn, "Failed to write error response %v (only %d written) due to error %v", simpleContext.response, size, writeErr)
			}
		}
	}
}

func writeError(writer http.ResponseWriter, code int, err errExt.Error) {
	writer.WriteHeader(code)
	writer.Header().Set("Content-Type", "application/json")
	size, writeErr := writer.Write([]byte("{ \"Response\" : \"" + err.Error() + "\"}"))
	if writeErr != nil {
		logger.LogWithLevel(log.Warn, "Failed to write response %v (only %d written) due to error %v", err, size, writeErr)
	}
}

func (app *simpleApplication[Request, Response]) RegisterHandler(handler Handle[Request, Response]) Application[Request, Response] {
	if os.Getenv("AWS_LAMBDA_RUNTIME_API") != "" {
		logger.LogWithLevel(log.Info, "AWS Lambda runtime detected")
		app.lambdaHandler = lambda.NewHandler(lambdaHandler(func(ctx context.Context, bytes []byte) ([]byte, error) {
			return simpleLambdaHandler(handler, ctx, bytes)
		}))
	} else if os.Getenv("PORT") != "" {
		logger.LogWithLevel(log.Info, "GCP Cloud Run runtime detected.")
		app.httpHandler = http.NewServeMux()
		app.httpHandler.Handle("/", &httpHandler[Request, Response]{
			handler: handler,
		})
	}
	return app
}

var ErrStartupFailed = errExt.NewErrorTemplate("Server Start Failed", "Failed to start server due to error {{ .Error }}")

func (app *simpleApplication[Request, Response]) Run() errExt.Error {
	if app.lambdaHandler != nil {
		lambda.Start(app.lambdaHandler)
	} else {
		err := http.ListenAndServe(":"+os.Getenv("PORT"), app.httpHandler)
		if err != nil {
			return ErrStartupFailed.NewWithError(err)
		}
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
	//	Support various protocols like TCP, HTTP, etc
	AwsLambdaHttp
	AwsLambdaInvoke
)

var ErrRequestParsingError = errExt.NewErrorTemplate("Parsing Error", "Failed to parse {{ .Data.Parameter }} payload as JSON due to error {{ .Data.ParseError }}")
var ErrResponseGenerationError = errExt.NewErrorTemplate("Response Generation Error", "Failed to generate response payload due to error {{ .Data }}")

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
		eventType = AwsLambdaHttp
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
		eventType = AwsLambdaInvoke
		requestObject = readData
	}
	requestObjectAsStruct, parseErr := createObject[Request](requestObject)
	if parseErr != nil {
		return nil, parseErr
	}
	var requestContext = &simpleContext[Request, Response]{request: &requestObjectAsStruct}

	logger.LogWithLevel(log.Debug, "Invoking handler with context %v, request %#v", ctx, requestContext.request)
	err := handler(requestContext)
	logger.LogWithLevel(log.Debug, "Response %#v; Error %v", requestContext.response, err)
	switch eventType {
	case AwsLambdaInvoke:
		if err != nil {
			return nil, err
		}
		if requestContext.response != nil {
			output, marshalErr := json.Marshal(requestContext.response)
			return output, marshalErr
		} else {
			return []byte("{}"), nil
		}
	case AwsLambdaHttp:
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
	case Unknown:
		unsupportedFormatErr := fmt.Sprintf("Event type has not been set")
		return nil, ErrResponseGenerationError.New(unsupportedFormatErr)
	default:
		unsupportedFormatErr := fmt.Sprintf("Event type %d is not supported", eventType)
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

func createObject[Request any](requestObject map[string]interface{}) (Request, errExt.Error) {
	var requestObjectAsStruct Request
	generatedRequest, requestMarshalErr := json.Marshal(requestObject)
	if requestMarshalErr != nil {
		return requestObjectAsStruct, ErrRequestParsingError.New(struct {
			Parameter  string
			ParseError error
		}{Parameter: "ObjectMarshal", ParseError: requestMarshalErr})
	}
	requestUnmarshalErr := json.Unmarshal(generatedRequest, &requestObjectAsStruct)
	if requestUnmarshalErr != nil {
		return requestObjectAsStruct, ErrRequestParsingError.New(struct {
			Parameter  string
			ParseError error
		}{Parameter: "Request Object", ParseError: requestUnmarshalErr})
	}
	return requestObjectAsStruct, nil
}
