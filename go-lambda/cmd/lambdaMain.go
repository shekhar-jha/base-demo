package main

import (
	"fmt"
	errext "github.com/shekhar-jha/base-demo/go-utils/pkg/err"
	"github.com/shekhar-jha/base-demo/go-utils/pkg/log"
)

var ErrMissingRequest = errext.NewErrorTemplate("Missing Request", "No request detail was provided.")
var ErrInvalidRequest = errext.NewErrorTemplate("Invalid Request Type", "Request is not of type map[string]interface{}. Actual {{ .Data.RequestType }}")
var ErrMissingParameter = errext.NewErrorTemplate("Missing Request Parameter", "Request parameter {{ .Data.ParamName }} is missing")

func HandleRequest(ctx Context) errext.Error {
	request := ctx.GetRequest()
	if request == nil {
		logger.LogWithLevel(log.Error, "Missing request details")
		return ErrMissingRequest.New()
	}
	if requestAsEvent, isEvent := request.(map[string]interface{}); isEvent {
		if nameValue, hasNameKey := requestAsEvent["Name"]; hasNameKey {
			var response = fmt.Sprintf("Hello %s!", nameValue)
			logger.LogWithLevel(log.Debug, "Response: %s", response)
			ctx.SetResponse(response)
		} else {
			return ErrMissingParameter.New(struct {
				ParamName string
			}{ParamName: "Name"})

		}
	} else {
		return ErrInvalidRequest.New(struct {
			RequestType string
		}{RequestType: fmt.Sprintf("%T", request)})
	}
	return nil
}

func main() {
	NewApplication().RegisterHandler(HandleRequest).Run()
}
