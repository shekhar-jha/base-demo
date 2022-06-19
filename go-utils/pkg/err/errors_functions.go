package errext

import (
	"fmt"
	"strings"
	"sync"
	"text/template"
)

func UnknownError() Error {
	return errorUnknown
}

func Success() Error {
	return errorSuccess
}
func UnknownErrorTemplate() ErrorTemplate {
	return unknownErrorTemplate
}

func (wrappedError *errExt) Unwrap() error {
	return wrappedError.err
}

func (wrappedError *errExt) Error() string {
	return wrappedError.text
}

func (errorTemplate *errorTemplate) New(arguments ...interface{}) Error {
	return errorTemplate.NewWithError(nil, arguments...)
}

type errorTemplateData struct {
	Error error
	Data  interface{}
}

func (errorTemplate *errorTemplate) NewWithError(err error, arguments ...interface{}) Error {
	var returnError = UnknownError()
	if errorTemplate.errorCode == 0 {
		return Success()
	}
	var returnErrorMessage = ""
	if errorTemplate.errorTemplate != nil {
		var stringWriter = &strings.Builder{}
		var data = errorTemplateData{
			Error: err,
		}
		if len(arguments) >= 1 {
			data.Data = arguments[0]
		}
		templateError := errorTemplate.errorTemplate.Execute(stringWriter, data)
		if templateError == nil {
			returnErrorMessage = stringWriter.String()
		} else {
			returnErrorMessage = fmt.Sprintf("%v%s%v", strings.TrimSuffix(fmt.Sprintln(arguments...), "\n"), ". Error while building error message ", templateError)
		}
	}
	if returnErrorMessage == "" {
		if len(arguments) > 0 {
			returnErrorMessage = strings.TrimSuffix(fmt.Sprintln(arguments...), "\n")
		} else {
			returnErrorMessage = errorTemplate.errorName
		}
	}
	returnError = &errExt{
		errorCode: errorTemplate.errorCode,
		text:      returnErrorMessage,
		err:       err,
	}
	return returnError
}

func (errorTemplate *errorTemplate) Is(err error) bool {
	if asError, isError := err.(*errExt); isError {
		if asError.errorCode == errorTemplate.errorCode {
			return true
		}
	}
	return false
}

func NewErrorTemplate(errorName string, errorTemplate string) ErrorTemplate {
	errorTemplateObject, _ := NewErrorTemplateE(errorName, errorTemplate)
	return errorTemplateObject
}

func NewErrorTemplateP(errorName string, errorTemplate string) ErrorTemplate {
	errorTemplateObject, err := NewErrorTemplateE(errorName, errorTemplate)
	if err != nil {
		panic(err)
	}
	return errorTemplateObject
}

var ErrMessageParseError = &errorTemplate{
	errorCode:     GetUniqueErrorCode(),
	errorTemplate: nil,
}

var ErrMessageEmptyString = &errorTemplate{
	errorCode:     GetUniqueErrorCode(),
	errorTemplate: nil,
}

func init() {
	parseErrorMessage, _ := template.New("Message Parse Error").Parse("Failed to parse message {{.data}} due to error {{.error}}.")
	ErrMessageParseError.errorTemplate = parseErrorMessage
	emptyStringErrorMessage, _ := template.New("Empty Message Error").Parse("Message template provided is empty")
	ErrMessageEmptyString.errorTemplate = emptyStringErrorMessage
}

func NewErrorTemplateE(errorName string, errorTemplateString string) (ErrorTemplate, Error) {
	var returnError Error = nil
	var returnErrorTemplate ErrorTemplate = nil
	if errorName != "" && errorTemplateString != "" {
		templateObject, err := template.New(errorName).Parse(errorTemplateString)
		if err == nil {
			returnErrorTemplate = &errorTemplate{
				errorCode:     GetUniqueErrorCode(),
				errorName:     errorName,
				errorTemplate: templateObject,
			}
		} else {
			returnError = ErrMessageParseError.NewWithError(err, errorTemplateString)
		}
	} else if errorName == "" {
		returnError = ErrMessageEmptyString.New(errorTemplateString)
	} else {
		returnErrorTemplate = &errorTemplate{
			errorCode:     GetUniqueErrorCode(),
			errorName:     errorName,
			errorTemplate: nil,
		}
	}
	if returnErrorTemplate == nil {
		returnErrorTemplate = unknownErrorTemplate
	}
	return returnErrorTemplate, returnError
}

var currentAvailableErrorCode ErrorCode = 0
var errorCodeMutex = sync.Mutex{}

func GetUniqueErrorCode() ErrorCode {
	errorCodeMutex.Lock()
	defer errorCodeMutex.Unlock()
	currentAvailableErrorCode += 1
	return currentAvailableErrorCode
}
