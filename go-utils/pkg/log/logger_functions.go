package log

import (
	"context"
)

func (logger *simpleLogger) Push(name string, values ...any) LoggerFunction {
	returnLogger, _ := logger.PushWithContext(nil, name, values...)
	return returnLogger
}

func (logger *simpleLogger) Supported(capability LoggerCapability) bool {
	if capability&CapabilityLogger != 0 ||
		capability&CapabilityContextLogger != 0 {
		return true
	}
	return false
}

type loggerContextKeyType struct{}

var commonLoggerContextKey = loggerContextKeyType{}

func (logger *simpleLogger) PushWithContext(parentContext context.Context, methodName string, values ...any) (LoggerFunction, context.Context) {
	var returnContext = parentContext
	methodPackageContext := &simpleContextPackage{context: logger.packageContext.GetContext()}
	functionalContext := &simpleContextFunction{
		packageContext: methodPackageContext,
		method:         &simpleContextMethod{method: methodName, values: values},
		parent:         nil,
	}
	var returnLogger LoggerFunction = &simpleMethodLogger{
		level:            logger.logLevel,
		parentLogger:     logger,
		logSystemContext: logger.loggerSystem,
		functionContext:  functionalContext,
	}
	returnContext = SetFunctionContext(parentContext, functionalContext)
	return returnLogger, returnContext
}

func (logger *simpleLogger) Log(message string, values ...any) LoggerBase {
	return logger.LogWithLevel(Info, message, values...)
}

func (logger *simpleLogger) LogWithLevel(level Level, message string, values ...any) LoggerBase {
	var compareResult = logger.logLevel.Compare(level)
	if compareResult == Equals || compareResult == Less {
		logger.loggerSystem.Append(&simplePackageEvent{
			packageContext: logger.packageContext,
			simpleLogEvent: simpleLogEvent{
				level:   level,
				message: message,
				args:    values,
			},
		})
	}
	return logger
}

func (logger *simpleLogger) SetLevel(level Level) {
	logger.logLevel = level
}

// GetFunctionContext extracts the embedded ContextFunction from the given Context.
func GetFunctionContext(context context.Context) ContextFunction {
	if context != nil {
		contextValue := context.Value(commonLoggerContextKey)
		if contextValue != nil {
			if contextValueAsFunction, isFunction := contextValue.(ContextFunction); isFunction {
				return contextValueAsFunction
			}
		}
	}
	return nil
}

// SetFunctionContext creates a new Context with the given ContextFunction and given Context and associated ContextFunction
// as parent of new Context and given ContextFunction respectively.
func SetFunctionContext(parentContext context.Context, functionalContext ContextFunction) context.Context {
	returnContext := parentContext
	if asConfigurable, isConfigurable := functionalContext.(ContextHierarchicalConfigurable); isConfigurable {
		asConfigurable.SetParentContext(GetFunctionContext(parentContext))
	}
	if parentContext != nil {
		returnContext = context.WithValue(parentContext, commonLoggerContextKey, functionalContext)
	} else {
		returnContext = context.WithValue(context.TODO(), commonLoggerContextKey, functionalContext)
	}
	return returnContext
}
