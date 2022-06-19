package errext

import (
	"errors"
	"fmt"
	"strings"
	"testing"
)

type testObject struct {
	str    string
	isBool bool
}

func runTemplateTest(t *testing.T, template *errorTemplate, messageChunks ...interface{}) {
	t.Run("EmptyNew", func(t *testing.T) {
		err := template.New()
		if len(messageChunks) == 0 {
			runErrorTest(t, err, template.errorName, nil, template)
		} else {
			runErrorTest(t, err, buildMessage([]interface{}{}, messageChunks...), nil, template)
		}
	})
	t.Run("1Arg", func(t *testing.T) {
		err := template.New("Arg1")
		runErrorTest(t, err, buildMessage([]interface{}{"Arg1"}, messageChunks...), nil, template)
	})
	t.Run("2Arg", func(t *testing.T) {
		err := template.New("Arg1", "Arg2")
		runErrorTest(t, err, buildMessage([]interface{}{"Arg1", "Arg2"}, messageChunks...), nil, template)
	})
	t.Run("MixedArg", func(t *testing.T) {
		arguments := []interface{}{1, "Arg2", true, testObject{
			str:    "Arg4",
			isBool: true,
		}, 0xAB, &testObject{
			str: "Arg6",
		}}
		err := template.New(arguments...)
		runErrorTest(t, err, buildMessage(arguments, messageChunks...), nil, template)
	})
	t.Run("ErrorNoArg", func(t *testing.T) {
		childErr := errors.New("SomeErr")
		err := template.NewWithError(childErr)
		if len(messageChunks) == 0 {
			runErrorTest(t, err, template.errorName, childErr, template)
		} else {
			runErrorTest(t, err, buildMessage([]interface{}{}, messageChunks...), childErr, template)
		}
	})
	t.Run("ErrorMixedArg", func(t *testing.T) {
		childErr := errors.New("AnotherErr")
		arguments := []interface{}{childErr, "is the error"}
		err := template.NewWithError(childErr, childErr, "is the error")
		runErrorTest(t, err, buildMessage(arguments, messageChunks...), childErr, template)
	})
}

func runErrorTest(t *testing.T, testError Error, value string, err Error, template ErrorTemplate) {
	if testError == nil {
		t.Error("Expected not nil, Actual nil")
		t.FailNow()
	}
	if errString := testError.Error(); errString != value {
		t.Error("Expected ", value, ", Actual ", errString)
	}
	if unwrappedErr := errors.Unwrap(testError); unwrappedErr != err {
		t.Error("Expected ", err, ", actual: ", unwrappedErr)
	}
	if !template.Is(testError) {
		t.Error("Expected template ", template, "to match error")
	}
}

func getTemplate(t *testing.T, errorTemplateObject ErrorTemplate) *errorTemplate {
	asErrorTemplate, isErrorTemplate := errorTemplateObject.(*errorTemplate)
	if !isErrorTemplate {
		t.Errorf("Expected an errorTemplateObject object, got %v", asErrorTemplate)
		t.FailNow()
	}
	return asErrorTemplate
}

func buildMessage(arguments []interface{}, messageChunks ...interface{}) string {
	if len(messageChunks) > 0 {
		returnStringBuilder := strings.Builder{}
		for messageIndex, messageChunk := range messageChunks {
			if messageIndex > 0 {
				if messageIndex <= len(arguments) {
					returnStringBuilder.WriteString(fmt.Sprint(arguments[messageIndex-1]))
				} else {
					returnStringBuilder.WriteString("<no value>")
				}
			}
			returnStringBuilder.WriteString(fmt.Sprint(messageChunk))
		}
		return returnStringBuilder.String()
	} else {
		return strings.TrimSuffix(fmt.Sprintln(arguments...), "\n")
	}
}

func TestUnknownError(t *testing.T) {
	unknownError := UnknownError()
	if unknownError != errorUnknown {
		t.Error("Expected: errorUnknown(", errorUnknown, "), Actual ", unknownError)
	}
}

func TestSuccess(t *testing.T) {
	success := Success()
	if success != errorSuccess {
		t.Error("Expected: errorSuccess(", errorSuccess, "), Actual ", success)
	}
	anotherSuccessTemplate := &errorTemplate{
		errorCode:     0,
		errorTemplate: nil,
	}
	anotherSuccess := anotherSuccessTemplate.New()
	if anotherSuccess != Success() {
		t.Error("Expected singleton Success, received another instance ", anotherSuccess)
	}
}

func TestUnknownErrorTemplate(t *testing.T) {
	var unknownErrTemp = UnknownErrorTemplate()
	if unknownErrTemp == nil {
		t.Error("Expected unknownErrorTemplate to be not nil")
	} else {
		runTemplateTest(t, getTemplate(t, unknownErrTemp))
	}
}

func TestNewErrorTemplateE(t *testing.T) {
	t.Run("EmptyNameAndTemplate", func(t *testing.T) {
		errorTemplateObject, templateErr := NewErrorTemplateE("", "")
		if errorTemplateObject == nil {
			t.Error("Expected not nil, Actual nil")
			t.FailNow()
		}
		if errorTemplateObject != UnknownErrorTemplate() {
			t.Error("Expected unknownErrorTemplate, actual: ", errorTemplateObject)
			asErrorTemplate := getTemplate(t, errorTemplateObject)
			runTemplateTest(t, asErrorTemplate)
		}
		if templateErr == nil {
			t.Error("Expected error, Actual nil")
			t.FailNow()
		}
		if !ErrMessageEmptyString.Is(templateErr) {
			t.Error("Expected ErrMessageEmptyString error, actual: ", templateErr)
		}
		if templateErr.Error() != "Message template provided is empty" {
			t.Error("Expected , Actual: ", templateErr.Error())
		}
	})
	t.Run("EmptyTemplate", func(t *testing.T) {
		errorTemplateObject, templateErr := NewErrorTemplateE("ErrorWithEmptyTemplate", "")
		if errorTemplateObject == nil {
			t.Error("Expected not nil, Actual nil")
			t.FailNow()
		}
		asErrorTemplate := getTemplate(t, errorTemplateObject)
		if templateErr != nil {
			t.Errorf("Expected no error, Actual %v", templateErr)
			if ErrMessageEmptyString.Is(templateErr) {
				t.Error("Did not expect ErrMessageEmptyString error")
			}
			if ErrMessageParseError.Is(templateErr) {
				t.Error("Did not expect ErrMessageParseError error")
			}
		}
		if errorTemplateObject == UnknownErrorTemplate() {
			t.Error("Did expect unknown error template")
		}
		runTemplateTest(t, asErrorTemplate)
	})
	t.Run("TemplateWithNoParameters", func(t *testing.T) {
		var templateObject, err = NewErrorTemplateE("ErrorWithNoParam", "Template with no parameters")
		if err != nil {
			t.Errorf("Expected no error, Actual: %v", err)
			if ErrMessageParseError.Is(err) {
				t.Error("Did not expect Message parsing error.")
			}
		}
		if templateObject == nil {
			t.Error("Expected not nil template, actual nil")
			t.FailNow()
		}
		runTemplateTest(t, getTemplate(t, templateObject), "Template with no parameters")
	})
	t.Run("TemplateWith1Param", func(t *testing.T) {
		var templateObject, err = NewErrorTemplateE("ErrorWith1Param", "Template with {{.Data}} parameters")
		if err != nil {
			t.Error("Expected no error, Actual: ", err)
			t.FailNow()
		}
		if templateObject == nil {
			t.Error("Expected not nil template, actual nil")
			t.FailNow()
		}
		runTemplateTest(t, getTemplate(t, templateObject), "Template with ", " parameters")
	})
	t.Run("TemplateWith2Param", func(t *testing.T) {
		type data struct {
			Arg1 interface{}
			Arg2 interface{}
		}
		var templateObject, err = NewErrorTemplateE("ErrorWith2Param", "Template with {{.Data.Arg2}} & {{.Data.Arg1}} parameters")
		if err != nil {
			t.Error("Expected no error, Actual: ", err)
			t.FailNow()
		}
		if templateObject == nil {
			t.Error("Expected not nil template, actual nil")
			t.FailNow()
		}
		errNoArgs := templateObject.New()
		runErrorTest(t, errNoArgs, ". Error while building error message template: ErrorWith2Param:1:21: executing \"ErrorWith2Param\" at <.Data.Arg2>: nil pointer evaluating interface {}.Arg2", nil, templateObject)
		err1ArgsInvalidType := templateObject.New("TestString")
		runErrorTest(t, err1ArgsInvalidType, "TestString. Error while building error message template: ErrorWith2Param:1:21: executing \"ErrorWith2Param\" at <.Data.Arg2>: can't evaluate field Arg2 in type interface {}", nil, templateObject)
		err1ArgsValidType := templateObject.New(data{
			Arg1: "Arg1",
			Arg2: "Arg2",
		})
		runErrorTest(t, err1ArgsValidType, "Template with Arg2 & Arg1 parameters", nil, templateObject)
	})
	t.Run("TemplateWithParsingIssue", func(t *testing.T) {
		var templateObject, err = NewErrorTemplateE("ErrorWithParsingIssue", "Template with {{.Data[0]}} parameters")
		if err == nil {
			t.Error("Expected error, Actual: nil ")
			t.FailNow()
		}
		if templateObject != UnknownErrorTemplate() {
			t.Error("Expected UnknownErrorTemplate Actual ", templateObject)
		}
	})
}

func TestErrorTemplate_Is(t *testing.T) {
	template1 := NewErrorTemplate("Error", "Template")
	error1NoArg := template1.New()
	error1AArg := template1.New("arg1")
	error1ErrorAnd2Arg := template1.New(errors.New("AnError"), "arg1", true)

	template2 := NewErrorTemplate("Error", "Template")
	error2NoArg := template2.New()
	error2AArg := template2.New("arg1")
	error2ErrorAnd2Arg := template2.New(errors.New("AnError"), "arg1", true)
	checkIs(t, "T1E1NoArg", template1, error1NoArg, true)
	checkIs(t, "T1E1AArg", template1, error1AArg, true)
	checkIs(t, "T1E1ErrorAnd2Arg", template1, error1ErrorAnd2Arg, true)
	checkIs(t, "T2E1NoArg", template2, error1NoArg, false)
	checkIs(t, "T2E1AArg", template2, error1AArg, false)
	checkIs(t, "T2E1ErrorAnd2Arg", template2, error1ErrorAnd2Arg, false)
	checkIs(t, "T1E2NoArg", template1, error2NoArg, false)
	checkIs(t, "T1E2AArg", template1, error2AArg, false)
	checkIs(t, "T1E2ErrorAnd2Arg", template1, error2ErrorAnd2Arg, false)
	checkIs(t, "T2E2NoArg", template2, error2NoArg, true)
	checkIs(t, "T2E2AArg", template2, error2AArg, true)
	checkIs(t, "T2E2ErrorAnd2Arg", template2, error2ErrorAnd2Arg, true)
}

func checkIs(t *testing.T, testName string, template ErrorTemplate, err Error, shouldMatch bool) {
	t.Run(testName, func(t *testing.T) {
		if !template.Is(err) {
			if shouldMatch {
				t.Error("Expected error match with template.")
			}
		} else {
			if !shouldMatch {
				t.Error("Expected error to not match with template.")
			}
		}
	})
}

func TestNewErrorTemplateP(t *testing.T) {
	t.Run("Valid Template", func(t *testing.T) {
		defer func() {
			if err := recover(); err != nil {
				t.Error("Expected no error, Actual: Panic occurred: ", err)
			}
		}()
		_ = NewErrorTemplateP("Error", "Template")
	})
	t.Run("InvalidTemplate", func(t *testing.T) {
		defer func() {
			if err := recover(); err == nil {
				t.Error("Expected panic, Actual: No panic occurred")
			}
		}()
		_ = NewErrorTemplateP("Error", "Template {{.Data[]}}")
	})
}

func TestNewErrorTemplate(t *testing.T) {
	t.Run("Valid Template", func(t *testing.T) {
		var validTemplate = NewErrorTemplate("Error", "Template")
		if validTemplate == nil {
			t.Error("Expected not nil template object, Actual nil")
		}
	})
	t.Run("InvalidTemplate", func(t *testing.T) {
		var invalidTemplate = NewErrorTemplate("Error", "Template {{.Data[]}}")
		if invalidTemplate != UnknownErrorTemplate() {
			t.Error("Expected UnknownErrorTemplate, Actual ", invalidTemplate)
		}
	})
}
