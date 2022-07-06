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
)

func init() {
	log.Configure(log.NewConfigLogger(log.Debug, "GoLogger"), "github.com/shekhar-jha/base-demo")
}

var logger = log.GetLogger("github.com/shekhar-jha/base-demo", "go-lambda", "cmd")

type Handle func(context Context) errext.Error

type Context interface {
	GetRequest() interface{}
	SetResponse(response interface{})
}

type simpleContext struct {
	request  interface{}
	response interface{}
}

func (context *simpleContext) GetRequest() interface{} {
	return context.request
}

func (context *simpleContext) SetResponse(response interface{}) {
	context.response = response
}

type Application interface {
	RegisterHandler(handle Handle) Application
	Run() errext.Error
}

func NewApplication() Application {
	return &simpleApplication{}
}

type simpleApplication struct {
	lambdaHandler lambda.Handler
}

func (app *simpleApplication) RegisterHandler(handler Handle) Application {
	if os.Getenv("AWS_LAMBDA_RUNTIME_API") != "" {
		logger.LogWithLevel(log.Info, "AWS Lambda runtime detected")
		app.lambdaHandler = lambda.NewHandler(lambdaHandler(func(ctx context.Context, bytes []byte) ([]byte, error) {
			return simpleLambdaHandler(handler, ctx, bytes)
		}))
	}
	return app
}

func (app *simpleApplication) Run() errext.Error {
	if app.lambdaHandler != nil {
		lambda.Start(app.lambdaHandler)
	}
	return nil
}

type lambdaHandler func(context.Context, []byte) ([]byte, error)

func (handler lambdaHandler) Invoke(ctx context.Context, payload []byte) ([]byte, error) {
	return handler(ctx, payload)
}

func simpleLambdaHandler(handler Handle, ctx context.Context, payload []byte) ([]byte, error) {
	var response = events.APIGatewayV2HTTPResponse{
		StatusCode:        200,
		Headers:           nil,
		MultiValueHeaders: nil,
		Body:              "",
		IsBase64Encoded:   false,
		Cookies:           nil,
	}
	var requestContext = &simpleContext{request: string(payload)}
	logger.LogWithLevel(log.Debug, "Invoking handler with context %v, request %#v", ctx, requestContext.request)
	err := handler(requestContext)
	logger.LogWithLevel(log.Debug, "Response %#v; Error %v", requestContext.response, err)
	if err != nil {
		response.Body = fmt.Sprintf("{ \"Message\" : \"%s\"}", err.Error())
	} else {
		marshaledValue, marshalErr := json.Marshal(requestContext.response)
		if marshalErr != nil {
			response.Body = fmt.Sprintf("{ \"Message\" : \"%#v\"}", marshalErr)
		} else {
			response.StatusCode = 200
			response.Body = string(marshaledValue)
		}
	}
	respByte, _ := json.Marshal(response)
	return respByte, nil
}
