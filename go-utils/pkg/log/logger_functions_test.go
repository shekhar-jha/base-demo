package log

import (
	"context"
	"testing"
)

func TestRootLogger(t *testing.T) {
	var defaultLogger = defaultLoggerSystem.GetLogger()
	t.Run("DefaultRunNoTest", func(t *testing.T) {
		defaultLogger.LogWithLevel(Trace, "Trace message with 1 arg %s", "Arg1")
		defaultLogger.LogWithLevel(Debug, "Debug message with 2 arg %s and %d", "Arg1", 2)
		defaultLogger.LogWithLevel(Info, "Info message with 1 arg %s", "Arg1")
		defaultLogger.LogWithLevel(Warn, "Warn message")
		defaultLogger.LogWithLevel(Error, "Error message")
		defaultLogger.Log("Logging without Level")
		methodLogger := defaultLogger.Push("Method1", "Arg1", "Arg2")
		methodLogger.Log("Logging method without level")
		methodLogger.LogWithLevel(Error, "Error message in method")
		methodLogger.Pop()
	})
}

func TestSimpleLogger_Supported(t *testing.T) {
	if !Default().GetLogger().Supported(CapabilityContextLogger) {
		t.Error("Expected to support CapabilityContextLogger, Actual: Not supported")
	}
	if Default().GetLogger().Supported(CapabilityFunctionLogger) {
		t.Error("Expected to not support CapabilityFunctionLogger, Actual: Supported")
	}
}

func Example_package() {
	// Output
	// [Info][packageA] Logging at Info level with argument Arg1
	// [Error][packageA] Logging error with error code 2
	logger := GetLogger("packageA")
	logger.LogWithLevel(Debug, "Do not log debug level")
	logger.Log("Logging at Info level with argument %s", "Arg1")
	logger.LogWithLevel(Error, "Logging error with error code %d", 2)
	// Output:
}

func Example_method() {
	// Output
	// [Info][Example_method.Method1([Arg1 2])] Entering Method1
	// [Info][Example_method.Method1([Arg1 2])] Logging in a method.
	logger := GetLogger("Example_method")
	func(arg1 string, arg2 int) {
		methodLogger := logger.Push("Method1", arg1, arg2)
		defer methodLogger.Pop()
		methodLogger.Log("Entering Method1")
		methodLogger.Log("Logging in a method.")
		methodLogger.LogWithLevel(Debug, "Return value: %d", 0)
	}("Arg1", 2)
	//Output:
}

func Example_context() {
	// Output
	// [Info][Example_Context1.MethodA([Arg1 2])] Entering MethodA
	// [Info][Example_Context1.MethodA([Arg1 2])] Calling methodB
	// [Info][Example_Context2.MethodB([Arg2 false])] Entering MethodB
	// [Info][Example_Context2.MethodB([Arg2 false])] Caller function MethodA
	// [Info][Example_Context2.MethodB([Arg2 false])] Return value: Result2
	// [Info][Example_Context1.MethodA([Arg1 2])] Return value: Result1

	// package Example_Context2
	loggerCTX2 := GetLogger("Example_Context2")
	var ctx2MethodB = func(context context.Context, arg1 string, arg2 bool) string {
		methodBLogger, methodBContext := loggerCTX2.PushWithContext(context, "MethodB", arg1, arg2)
		defer methodBLogger.Pop()
		methodBLogger.Log("Entering MethodB")
		callingFunctionContext := GetFunctionContext(methodBContext).GetParentContext()
		callingMethodDetails := callingFunctionContext.(ContextFunction).GetMethodContext()
		methodBLogger.Log("Caller function %s", callingMethodDetails.GetMethod())
		methodBLogger.LogWithLevel(Info, "Caller function arguments %s, %s", callingMethodDetails.GetArguments()...)
		methodBLogger.Log("Return value: %s", "Result2")
		return "Result2"
	}
	// package Example_Context1
	rootContext := context.TODO()
	loggerCTX1 := GetLogger("Example_Context1")
	func(context context.Context, arg1 string, arg2 int) string {
		methodALogger, methodAContext := loggerCTX1.PushWithContext(context, "MethodA", arg1, arg2)
		defer methodALogger.Pop()
		methodALogger.Log("Entering MethodA")
		methodALogger.Log("Calling methodB")
		ctx2MethodB(methodAContext, "Arg2", false)
		methodALogger.Log("Return value: %s", "Result1")
		return "Result1"
	}(rootContext, "Arg1", 2)
	// Output:
}
