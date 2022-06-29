package log

type simpleMethodLogger struct {
	logSystemContext SystemContext
	parentLogger     Logger
	functionContext  ContextFunction
	level            Level
}

func (logger *simpleMethodLogger) Pop() Logger {
	if logger.parentLogger != nil {
		return logger.parentLogger
	}
	return nil
}

func (logger *simpleMethodLogger) Log(message string, values ...any) LoggerBase {
	logger.LogWithLevel(Info, message, values...)
	return logger
}

func (logger *simpleMethodLogger) LogWithLevel(level Level, message string, values ...any) LoggerBase {
	result := level.Compare(logger.level)
	if result == Greater || result == Equals {
		logger.logSystemContext.Append(&simpleFunctionEvent{
			function: logger.functionContext,
			simpleLogEvent: simpleLogEvent{
				level:   level,
				message: message,
				args:    values,
			},
		})
	}
	return logger
}

func (logger *simpleMethodLogger) Supported(capability LoggerCapability) bool {
	if capability == CapabilityLogger || capability == CapabilityFunctionLogger {
		return true
	}
	return false
}
