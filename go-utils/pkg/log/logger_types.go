package log

import (
	"context"
)

// LoggerCapability defines the capability supported by an implementation of Logger.
type LoggerCapability int

// LoggerCapability defines the types of capabilities supported which translated to
// corresponding interface.
const (
	CapabilityLogger         LoggerCapability = 0b00001
	CapabilityContextLogger  LoggerCapability = 0b00010
	CapabilityFunctionLogger LoggerCapability = 0b00100
)

// LoggerBase defines the basic Logging APIs
//
// Log and LogWithLevel defines the method used to log.
//
// Supported checks whether given Logger supports a specific capbility.
type LoggerBase interface {
	Log(message string, values ...any) LoggerBase
	LogWithLevel(level Level, message string, values ...any) LoggerBase
	Supported(capability LoggerCapability) bool
}

// Logger interface provides method specific functions i.e. Push and PushWithContext to
// add method specific details for logging. See Example_Method and Example_Context examples.
type Logger interface {
	Push(name string, values ...any) LoggerFunction
	PushWithContext(context context.Context, name string, values ...any) (LoggerFunction, context.Context)
	LoggerBase
}

// LoggerFunction provides the methods that can be called on a logger for function.
type LoggerFunction interface {
	Pop() Logger
	LoggerBase
}

// LoggerConfigurable interface allows System to configure Logger after creation. At this time
// SetLevel is supported.
type LoggerConfigurable interface {
	SetLevel(level Level)
}

// SystemContext interface allows Logger to interact with System at runtime. At this time
// Append method is available to publish event to System.
type SystemContext interface {
	Append(event Event)
}

type simpleLogger struct {
	loggerSystem   SystemContext
	packageContext ContextPackage
	logLevel       Level
}
