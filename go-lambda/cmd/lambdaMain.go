package main

import (
	"context"
	"fmt"
	"github.com/grinps/go-utils/base-utils/logs"
	"github.com/grinps/go-utils/errext"
	"github.com/shekhar-jha/base-demo/go-lambda/cmd/cfg/viper"
	"github.com/shekhar-jha/base-demo/go-lambda/cmd/common"
	db2 "github.com/shekhar-jha/base-demo/go-lambda/cmd/db"
	"github.com/shekhar-jha/base-demo/go-lambda/cmd/db/dynamodb"
	"os"
	"sync"
)

var ErrMissingRequest = errext.NewErrorCodeWithOptions(errext.WithTemplate("No request detail was provided."))

const ErrParamOps = "operation"
const EnvCfgEnvName = "CFG_ENV_NAME"

var ErrInitFailed = errext.NewErrorCodeWithOptions(errext.WithTemplate("Failed to perform", "[operation]", "during initialization due to", "[error]"))

func initialize() error {
	ctx := context.TODO()
	contexts := []string{}
	envName := os.Getenv(EnvCfgEnvName)
	if envName != "" {
		contexts = append(contexts, envName)
	}
	contexts = append(contexts, viper.DefaultContext)
	cfg, cfgErr := viper.NewViperConfigE(ctx, "config.cfg", []string{"./"}, viper.SetConfigHierarchy(ctx, contexts...))
	if cfgErr != nil {
		logger.Warn("Failed to load configuration config.cfg from ./", cfgErr)
		return ErrInitFailed.NewWithErrorF(cfgErr, ErrParamOps, "configuration load", common.ErrParamCause, cfgErr)
	}
	localDb, newErr := dynamodb.NewDynamoDBE(ctx, dynamodb.SetupWithConfig(ctx, cfg))
	if newErr != nil {
		logger.Warn("Failed to open database due to error", newErr)
		return ErrInitFailed.NewWithErrorF(newErr, ErrParamOps, "database open", common.ErrParamCause, newErr)
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
var db db2.Database

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
