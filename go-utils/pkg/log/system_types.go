// Package log implements functions to log messages.
//
// Logging
//
// Any go package can import and start using Logger as follows.
//   logger := GetLogger(context ...string)
// The GetLogger function creates a new logger for the given context using default System.
//   logger.Log("Logging message with %s argument and %d value", "string_arg", 2)
//   logger.LogWithLevel(Error, "Method4 Log error with no args")
// The LoggerBase.Log and LoggerBase.LogWithLevel can be used to log the message. Depending on the configured Level
// the message would be formatted using configured Formatter and then written to configured Appender.
//
// Context
//
// Context defines the context in which logging is being performed. Contexts are hierarchical with RootContext at top.
// Configuration associated with parent context ("CTX11") is inherited by child context ("CTX11.CTX11.CTX111", "CTX1.CXT12.CTX121")
// if the configuration for the child context has not been set.
//
// Configuration
//
// Logging can be controlled by setting Level and Appender. The ConfigLogger defines the Level associated with a Logger
// while ConfigAppender defines the Appender configuration. Driver takes ConfigAppender as input and creates corresponding
// Appender
package log

// RootContext is the context that is root of all the other context.
const RootContext string = "ROOT"

// System is the interface that defines a self-contained logging system.
// Default() is the default system available to caller.
//
// GetDriver returns the Driver associated with System. At this time only one driver is supported.
//
// GetLogger returns the Logger for the given Context Hierarchy.
//
// ConfigureAppender implementation is expected to configure Appender for the given ConfigAppender.
//
// Configure configures a Logger corresponding to the given context hierarchy.
type System interface {
	GetDriver() Driver
	GetLogger(context ...string) Logger
	ConfigureAppender(appenderConfig ConfigAppender)
	Configure(loggerConfig ConfigLogger, context ...string)
}

type simpleSystem struct {
	rootLoggerNode *node
	appenders      map[string]ConfigAppender
	logDriver      Driver
}

// Driver defines the method to be implemented by any Logging implementation.
//
// GetAppender returns an Appender for the given ConfigAppender.
type Driver interface {
	GetAppender(config ConfigAppender) Appender
}

// Appender defines the Logging implementation that logs the given logging Event.
//
// GetName returns the name of the Appender which is referred to by the ConfigLogger
type Appender interface {
	GetName() string
	Log(event Event)
}

// Formatter interface must be implemented to define how a log event should be structured for logging.
// The Formatter is provided to Appender as part of ConfigAppender configuration.
type Formatter interface {
	Format(event Event) string
}

// IsInherited defines whether the configuration is Inherited or Set.
type IsInherited int

// Different settings for IsInherited flag.
const (
	// NotSet is default value if the configuration has not been set.
	NotSet IsInherited = iota
	// Inherited defines that a given Context has inherited the configuration
	Inherited
	// Set defines that configuration has been explicitly set.
	Set
)

// systemContext captures the details that are attached to a Context node.
type systemContext struct {
	logger    Logger
	config    ConfigLogger
	appender  Appender
	inherited IsInherited
}

// node represents the information associated with a particular Context.
// node is hierarchical to align with Context structure.
type node struct {
	context       string
	systemContext systemContext
	parentNode    *node
	childNodeMap  map[string]*node
}

// defaultLoggerSystem provides out of box System.
var defaultLoggerSystem = NewSystemP(Info, defaultGoDriver,
	NewConfigAppender(defaultGoLogConfig.logConfigName, &goAppenderFormatter{
		contextFormatter:  defaultGoLogConfig.PrefixContextFormat,
		functionFormatter: defaultGoLogConfig.PrefixFunctionFormat,
	}, defaultGoLogConfig))
