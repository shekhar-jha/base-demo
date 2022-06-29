package log

// Event defines methods for a log event
type Event interface {
	//	GetTime() time.Time
	//	GetLogger() LoggerBase
	GetLevel() Level
	GetMessage() string
	GetArguments() []interface{}
	//	GetError() error
}

type simpleLogEvent struct {
	level   Level
	message string
	args    []interface{}
}

func (event *simpleLogEvent) GetLevel() Level {
	return event.level
}

func (event *simpleLogEvent) GetMessage() string {
	return event.message
}

func (event *simpleLogEvent) GetArguments() []interface{} {
	return event.args
}

// EventPackage extends the Event interface and adds ContextPackage to the event.
type EventPackage interface {
	GetPackage() ContextPackage
	Event
}

type simplePackageEvent struct {
	packageContext ContextPackage
	simpleLogEvent
}

func (event *simplePackageEvent) GetPackage() ContextPackage {
	return event.packageContext
}

// EventFunction extends the Event interface and adds ContextFunction to the event.
type EventFunction interface {
	GetFunction() ContextFunction
	Event
}

type simpleFunctionEvent struct {
	function ContextFunction
	simpleLogEvent
}

func (event *simpleFunctionEvent) GetFunction() ContextFunction {
	return event.function
}
