package log

// ConfigLogger defines the configuration associated with a Logger. At this time, it consists of Level and name of Appender
type ConfigLogger interface {
	//	Matches(key string, value string) bool
	GetLogLevel() Level
	GetAppenderName() string
}

type simpleLogConfig struct {
	level    Level
	appender string
}

func (config *simpleLogConfig) GetLogLevel() Level {
	return config.level
}

func (config *simpleLogConfig) GetAppenderName() string {
	return config.appender
}

// NewConfigLogger creates an instance of ConfigLogger using the given Level and name of Appender.
func NewConfigLogger(level Level, appenderName string) ConfigLogger {
	return &simpleLogConfig{
		level:    level,
		appender: appenderName,
	}
}

// ConfigAppender defines the Format and configuration associated with an Appender.
type ConfigAppender interface {
	GetName() string
	GetFormatter() Formatter
	GetConfig() interface{}
}

type simpleConfigAppender struct {
	name      string
	formatter Formatter
	config    interface{}
}

func (config *simpleConfigAppender) GetName() string {
	return config.name
}

func (config *simpleConfigAppender) GetFormatter() Formatter {
	return config.formatter
}

func (config *simpleConfigAppender) GetConfig() interface{} {
	return config.config
}

// NewConfigAppender creates a new ConfigAppender
func NewConfigAppender(name string, formatter Formatter, configuration interface{}) ConfigAppender {
	return &simpleConfigAppender{
		name:      name,
		formatter: formatter,
		config:    configuration,
	}
}
