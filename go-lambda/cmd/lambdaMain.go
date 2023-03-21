package main

import (
	"context"
	"fmt"
	"github.com/grinps/go-utils/base-utils/logs"
	"github.com/grinps/go-utils/errext"
	"os"
	"sync"
)

var ErrMissingRequest = errext.NewErrorCodeWithOptions(errext.WithTemplate("No request detail was provided."))

var ErrInitFailed = errext.NewErrorCodeWithOptions(errext.WithTemplate("Failed to perform", "[operation]", "during initialization due to", "[error]"))

func initialize() error {
	ctx := context.TODO()
	cfg, cfgErr := NewViperConfigE(ctx, "config.cfg", []string{"./"})
	if cfgErr != nil {
		logger.Warn("Failed to load configuration config.cfg from ./", cfgErr)
		return ErrInitFailed.NewWithErrorF(cfgErr, ErrDBParamOps, "configuration load", ErrParamCause, cfgErr)
	}
	localDb, newErr := NewDynamoDBE(ctx, SetupWithConfig(ctx, cfg))
	if newErr != nil {
		logger.Warn("Failed to open database due to error", newErr)
		return ErrInitFailed.NewWithErrorF(newErr, ErrDBParamOps, "database open", ErrParamCause, newErr)
	}
	db = localDb
	return nil
}

type MyEvent struct {
	Name string
}

type Message struct {
	Response string
}

var doOnce sync.Once
var initErr error
var db Database

func HandleRequest[Request MyEvent, Response Message](ctx Context[MyEvent, Message]) error {
	doOnce.Do(func() {
		initErr = initialize()
	})
	var request = ctx.GetRequest()
	if request == nil {
		logger.Warn("Missing request details")
		return ErrMissingRequest.NewF()
	}
	var response = Message{
		Response: "ProtocolTypeUnknown",
	}
	if initErr == nil {
		_, createErr := db.Create(context.TODO(), "messages", map[string]any{"Name": request.Name})
		if createErr != nil {
			response.Response = fmt.Sprintf("You have not been saved %s! Err: %#v", request.Name, createErr)
		} else {
			response.Response = fmt.Sprintf("You have been saved %s!", request.Name)
		}
	} else {
		response.Response = fmt.Sprintf("Initialization failed due to error %s", initErr)
	}
	logger.Log("Response:", response)
	ctx.SetResponse(response)
	return nil
}

func main() {
	logger.Log("=========    Environment    =========")
	for _, envValue := range os.Environ() {
		logger.Log(envValue)
	}
	logger.Log("=========    Arguments    =========")
	for _, arg := range os.Args {
		logger.Log(arg)
	}
	err := NewApplication[MyEvent, Message]().RegisterHandler(HandleRequest[MyEvent, Message]).Run()
	if err != nil {
		logger.Warn("Failed to Run server due to error", err)
	}
}
