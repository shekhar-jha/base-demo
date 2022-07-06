package main

import (
	"fmt"
	errext "github.com/shekhar-jha/base-demo/go-utils/pkg/err"
	"github.com/shekhar-jha/base-demo/go-utils/pkg/log"
)

var ErrMissingRequest = errext.NewErrorTemplate("Missing Request", "No request detail was provided.")

type MyEvent struct {
	Name string
}

type Message struct {
	Response string
}

func HandleRequest[Request MyEvent, Response Message](ctx Context[MyEvent, Message]) errext.Error {
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
	NewApplication[MyEvent, Message]().RegisterHandler(HandleRequest[MyEvent, Message]).Run()
}
