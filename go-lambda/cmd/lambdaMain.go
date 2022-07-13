package main

import (
	"fmt"
	errExt "github.com/shekhar-jha/base-demo/go-utils/pkg/err"
	"github.com/shekhar-jha/base-demo/go-utils/pkg/log"
	"os"
)

var ErrMissingRequest = errExt.NewErrorTemplate("Missing Request", "No request detail was provided.")

type MyEvent struct {
	Name string
}

type Message struct {
	Response string
}

func HandleRequest[Request MyEvent, Response Message](ctx Context[MyEvent, Message]) errExt.Error {
	var request = ctx.GetRequest()
	if request == nil {
		logger.LogWithLevel(log.Error, "Missing request details")
		return ErrMissingRequest.New()
	}
	var response = Message{
		Response: fmt.Sprintf("Hello %s!", request.Name),
	}
	logger.LogWithLevel(log.Debug, "Response: %s", response)
	ctx.SetResponse(response)
	return nil
}

func main() {
	logger.LogWithLevel(log.Debug, "=========    Environment    =========")
	for _, envValue := range os.Environ() {
		logger.LogWithLevel(log.Debug, "%s", envValue)
	}
	logger.LogWithLevel(log.Debug, "=========    Arguments    =========")
	for _, arg := range os.Args {
		logger.LogWithLevel(log.Debug, "%s", arg)
	}
	err := NewApplication[MyEvent, Message]().RegisterHandler(HandleRequest[MyEvent, Message]).Run()
	if err != nil {
		logger.LogWithLevel(log.Error, "Failed to Run server due to error %v", err)
	}
}
