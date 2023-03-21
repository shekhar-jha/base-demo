package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	logger "github.com/grinps/go-utils/base-utils/logs"
	"github.com/grinps/go-utils/errext"
	"net/http"
	"os"
	"strings"
)

type Handle[Request any, Response any] func(context Context[Request, Response]) error

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
	Run() error
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
	logger.Log("Invoked request with %v", request)
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
	logger.Log("Invoking handler with request", simpleContext.request)
	err := handler.handler(simpleContext)
	logger.Log("Response %#v; Error", simpleContext.response, err)
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
				logger.Warn("Failed to write error response", simpleContext.response, "(only", size, "written) due to error ", writeErr)
			}
		}
	}
}

func writeError(writer http.ResponseWriter, code int, err error) {
	writer.WriteHeader(code)
	writer.Header().Set("Content-Type", "application/json")
	size, writeErr := writer.Write([]byte("{ \"Response\" : \"" + err.Error() + "\"}"))
	if writeErr != nil {
		logger.Warn("Failed to write response", err, "(only ", size, "written) due to error", writeErr)
	}
}

func (app *simpleApplication[Request, Response]) RegisterHandler(handler Handle[Request, Response]) Application[Request, Response] {
	if os.Getenv("AWS_LAMBDA_RUNTIME_API") != "" {
		logger.Log("AWS Lambda runtime detected")
		app.lambdaHandler = lambda.NewHandler(lambdaHandler(func(ctx context.Context, bytes []byte) ([]byte, error) {
			return simpleLambdaHandler(handler, ctx, bytes)
		}))
	} else if os.Getenv("PORT") != "" {
		logger.Log("GCP Cloud Run runtime detected.")
		app.httpHandler = http.NewServeMux()
		app.httpHandler.Handle("/", &httpHandler[Request, Response]{
			handler: handler,
		})
	}
	return app
}

var ErrStartupFailed = errext.NewErrorCodeWithOptions(errext.WithTemplate("Failed to start server due to error", "[error]"))

func (app *simpleApplication[Request, Response]) Run() error {
	if app.lambdaHandler != nil {
		lambda.Start(app.lambdaHandler)
	} else {
		err := http.ListenAndServe(":"+os.Getenv("PORT"), app.httpHandler)
		if err != nil {
			return ErrStartupFailed.NewWithErrorF(err, "error", err)
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
	ProtocolTypeUnknown ProtocolType = iota
	//	Support various protocols like TCP, HTTP, etc
	AwsLambdaHttp
	AwsLambdaInvoke
)

var ErrRequestParsingError = errext.NewErrorCodeWithOptions(errext.WithTemplate("Failed to parse", "[Parameter]", "payload as JSON due to error", "[ParseError]"))
var ErrResponseGenerationError = errext.NewErrorCodeWithOptions(errext.WithTemplate("Failed to generate response payload due to error", "[error]"))

func simpleLambdaHandler[Request any, Response any](handler Handle[Request, Response], ctx context.Context, payload []byte) ([]byte, error) {
	readData := map[string]interface{}{}
	unmarshalErr := json.Unmarshal(payload, &readData)
	if unmarshalErr != nil {
		return nil, ErrRequestParsingError.NewWithErrorF(unmarshalErr, "Parameter", "Request", "ParseError", unmarshalErr)
	}
	requestObject := map[string]interface{}{}
	logger.Log("Parsed request object", readData)
	var eventType ProtocolType
	if _, isHTTP := asMap(readData, "requestContext", "http"); isHTTP {
		logger.Log("Request is an Lambda HTTP Request")
		eventType = AwsLambdaHttp
		requestId, _ := asString(readData, "requestContext", "requestId")
		logger.Log("Request Id", requestId)
		if queryParams, hasQueryParams := asMap(readData, "queryStringParameters"); hasQueryParams {
			copyMap(queryParams, requestObject)
			logger.Log("Added query parameters", queryParams)
		}
		if body, hasBody := asString(readData, "body"); hasBody {
			logger.Log("Request body is present")
			if contentType, hasContentType := asString(readData, "headers", "content-type"); hasContentType {
				switch strings.ToLower(contentType) {
				case "application/json":
					logger.Log("Parsing content type application/json")
					bodyUnmarshalError := json.Unmarshal([]byte(body), &requestObject)
					if bodyUnmarshalError != nil {
						return nil, ErrRequestParsingError.NewWithErrorF(unmarshalErr, "Parameter", "Body", "ParseError", bodyUnmarshalError)
					}
				default:
					logger.Warn("Failed to identify request body content type", contentType, "for request", requestId)
				}
			} else {
				logger.Warn("Request body is present but no content-type header is available for validation.")
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

	logger.Log("Invoking handler with context", ctx, "request", requestContext.request)
	err := handler(requestContext)
	logger.Log("Response", requestContext.response, "Error", err)
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
	case ProtocolTypeUnknown:
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
	logger.Log("Input:", input)
	returnValue := map[string]interface{}{}
	if input == nil {
		return returnValue, false
	}
	totalKeys := len(key)
	logger.Log("Total keys:", totalKeys)
	if totalKeys > 0 {
		var applicableMap = input
		for remainingKeys := totalKeys; remainingKeys >= 1; remainingKeys-- {
			logger.Log("Applicable map:", applicableMap)
			logger.Log("Remaining keys:", remainingKeys)
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

func createObject[Request any](requestObject map[string]interface{}) (Request, error) {
	var requestObjectAsStruct Request
	generatedRequest, requestMarshalErr := json.Marshal(requestObject)
	if requestMarshalErr != nil {
		return requestObjectAsStruct, ErrRequestParsingError.NewWithErrorF(requestMarshalErr,
			"Parameter", "ObjectMarshal", "ParseError", requestMarshalErr)
	}
	requestUnmarshalErr := json.Unmarshal(generatedRequest, &requestObjectAsStruct)
	if requestUnmarshalErr != nil {
		return requestObjectAsStruct, ErrRequestParsingError.NewWithErrorF(requestMarshalErr,
			"Request Object", "ObjectMarshal", "ParseError", requestUnmarshalErr)
	}
	return requestObjectAsStruct, nil
}
