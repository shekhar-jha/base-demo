package log

import (
	"context"
	"fmt"
	"strings"
	"testing"
)

func TestDefaultMethodLogger_BaseObject(t *testing.T) {
	defMetLog := &simpleMethodLogger{
		parentLogger:     nil,
		functionContext:  nil,
		level:            nil,
		logSystemContext: nil,
	}
	t.Run("Pop", func(t *testing.T) {
		if popped := defMetLog.Pop(); popped != nil {
			t.Error("Expected nil, Actual: ", popped)
		}
	})
	t.Run("Log", func(t *testing.T) {
		defer func() {
			if err := recover(); err != nil {
				t.Error("Failed to log message with default method logger. Expected no error, Actual: ", err)
			}
		}()
		defMetLog.Log("Message with no args")
	})
	t.Run("LogWithLevel", func(t *testing.T) {
		defer func() {
			if err := recover(); err != nil {
				t.Error("Failed to log Error message with default method logger. Expected no error, Actual: ", err)
			}
		}()
		var a = struct {
			hello string
		}{
			hello: "World",
		}
		defMetLog.LogWithLevel(Error, "Message with 1 args %s", a)
	})
	t.Run("Supported", func(t *testing.T) {
		if !defMetLog.Supported(CapabilityFunctionLogger) {
			t.Error("CapabilityFunctionLogger: Expected True, Actual False")
		}
		if defMetLog.Supported(CapabilityContextLogger) {
			t.Error("CapabilityContextLogger: Expected false, Actual true")
		}
	})
}

func TestDefaultMethodLogger_Valid(t *testing.T) {
	var logCapture = &strings.Builder{}
	ConfigureAppender(getGoLoggerConfig("TestDefaultMethodLogger_Valid", logCapture))
	Configure(&simpleLogConfig{
		level:    Info,
		appender: "TestDefaultMethodLogger_Valid",
	}, "CTX1")
	var ctxLogger1 = GetLogger("CTX1")
	var method1 = ctxLogger1.Push("Method1")
	t.Run("MethodNoArgs", func(t *testing.T) {
		logCapture.Reset()
		method1.Log("Log with no args")
		logResult := logCapture.String()
		if !strings.Contains(logCapture.String(), "{Info}{CTX1.Method1[]} Log with no args") {
			t.Error("Expected: {Info}{CTX1.Method1[]} Log with no args Log with no args, Actual: ", logResult)
		}
	})
	Configure(&simpleLogConfig{
		level:    Error,
		appender: "TestDefaultMethodLogger_Valid",
	}, "CTX1", "CTX2")
	var ctxLogger2 = GetLogger("CTX1", "CTX2", "CTX3")
	var method2 = ctxLogger2.Push("Method2", "A1")
	t.Run("Method2With1Arg", func(t *testing.T) {
		logCapture.Reset()
		method2.LogWithLevel(Warn, "Method2 Log warn with 1 arg %s", "Arg1")
		method2.LogWithLevel(Error, "Method2 Log error with 1 arg %s", "Arg1")
		logResult := logCapture.String()
		if !strings.Contains(logCapture.String(), "{Error}{CTX1.CTX2.CTX3.Method2[A1]} Method2 Log error with 1 arg Arg1") {
			t.Error("Expected: {Error}{CTX1.CTX2.CTX3.Method2[A1]} Method2 Log error with 1 arg Arg1, Actual: ", logResult)
		}
	})
	baseContext := context.TODO()
	var method3, method3Context = ctxLogger1.PushWithContext(baseContext, "Method3", "A1", 2, true)
	t.Run("Method3WithContext", func(t *testing.T) {
		logCapture.Reset()
		if method3Context == nil {
			t.Error("Expected Method3 Context not nil, Actual nil")
			t.FailNow()
		}
		method3ContextValue := GetFunctionContext(method3Context)
		checkFunctionContextValue(t, "Method3", method3ContextValue, false, nil, "CTX1", "Method3", "A1", 2, true)
		method3.LogWithLevel(Info, "Method3 Calling method")
		if method3LogResult := logCapture.String(); !strings.Contains(method3LogResult, "{Info}{CTX1.Method3[A1 2 true]} Method3 Calling method") {
			t.Error("Expected {Info}{CTX1.Method3[A1 2 true]} Method3 Calling method, Actual: ", method3LogResult)
		}
		method4, method4Context := ctxLogger2.PushWithContext(method3Context, "Method4", 3, false)
		method4ContextValue := GetFunctionContext(method4Context)
		checkFunctionContextValue(t, "Method4", method4ContextValue, false, method3ContextValue, "CTX1.CTX2.CTX3", "Method4", 3, false)
		logCapture.Reset()
		method4.LogWithLevel(Error, "Method4 Log error with no args")
		if method4LogResult := logCapture.String(); !strings.Contains(method4LogResult, "{Error}{CTX1.CTX2.CTX3.Method4[3 false]} Method4 Log error with no args") {
			t.Error("Expected: {Error}{CTX1.CTX2.CTX3.Method4[3 false]} Method4 Log error with no args, Actual: ", method4LogResult)
		}
	})
}

func checkFunctionContextValue(t *testing.T, name string, functionContextValue ContextFunction, expectedNil bool, parentContext Context, packageContext string, methodName string, args ...interface{}) {
	if expectedNil {
		if functionContextValue != nil {
			t.Error("Expected ", name, " Context to be nil, Actual not nil")
		}
	} else {
		if functionContextValue == nil {
			t.Error("Expected ", name, " Context to be not nil, Actual nil")
			t.FailNow()
		}
		if !functionContextValue.Is(ContextFunctionType) {
			t.Error("Expected ", name, " Context to be of function type, Actual: it is not of that type")
		}
		if functionContextValue.Is(ContextPackageType) {
			t.Error("Expected ", name, " Context to be of function type, Actual: ContextPackageType(", ContextPackageType, ")")
		}
		actualParentContext := functionContextValue.GetParentContext()
		if actualParentContext != parentContext {
			t.Error("Expected ", name, " parent context to be ", parentContext, " Actual: ", actualParentContext)
		}
		actualPackageContext := functionContextValue.GetPackageContext().GetContext()
		if actualPackageContext != packageContext {
			t.Error("Expected ", name, " package context to be ", packageContext, " Actual: ", actualPackageContext)
		}
		actualMethodContext := functionContextValue.GetMethodContext()
		if actualMethodContext.GetMethod() != methodName {
			t.Error("Expected ", name, " context's method name to be ", methodName, " Actual: ", actualMethodContext.GetMethod())
		}
		for index, argument := range actualMethodContext.GetArguments() {
			if fmt.Sprint(argument) != fmt.Sprint(args[index]) {
				t.Error("Expected ", name, " context argument to be ", args[index], " Actual: ", argument)
			}
		}
	}
}

func getGoLoggerConfig(name string, builder *strings.Builder) *simpleConfigAppender {
	return &simpleConfigAppender{
		name: name,
		formatter: &goAppenderFormatter{
			contextFormatter:  "{%s}{%s} ",
			functionFormatter: "{%s}{%s.%s%v} ",
		},
		config: &GoLogConfig{
			Prefix:     "",
			OutputFile: "",
			out:        builder,
			Flags: &GoLogFlags{
				Date:                true,
				Time:                true,
				TimeInMicrosecond:   true,
				TimeInUTC:           false,
				LongFile:            false,
				ShortFile:           false,
				PrefixAtStartOfLine: false,
			},
			PrefixContextFormat:  "{%s}{%s} ",
			PrefixFunctionFormat: "{%s}{%s.%s%s} ",
			logConfigName:        name,
		},
	}
}
