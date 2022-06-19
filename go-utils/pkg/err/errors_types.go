package errext

import "text/template"

type errExt struct {
	errorCode ErrorCode
	text      string
	err       error
}

type Error interface {
	error
}

type ErrorTemplate interface {
	New(arguments ...interface{}) Error
	NewWithError(err error, arguments ...interface{}) Error
	Is(err error) bool
}

type errorTemplate struct {
	errorCode     ErrorCode
	errorName     string
	errorTemplate *template.Template
}
type ErrorCode int

const (
	ErrorCodeUnknown ErrorCode = -1
	ErrorCodeSuccess ErrorCode = 0
)

var errorUnknown Error = &errExt{
	errorCode: ErrorCodeUnknown,
	text:      "Unknown Error occurred",
	err:       nil,
}

var errorSuccess Error = &errExt{
	errorCode: ErrorCodeSuccess,
	text:      "Success",
	err:       nil,
}

var unknownErrorTemplate = &errorTemplate{
	errorCode:     ErrorCodeUnknown,
	errorTemplate: nil,
}
