package log

import (
	"io"
	"log"
	"os"
)

// GoLogConfig defines the configuration for out of box Appender implementation
// that uses Go Log package.
type GoLogConfig struct {
	Prefix               string `json:"prefix"`
	OutputFile           string `json:"outputFile"`
	out                  io.Writer
	Flags                *GoLogFlags `json:"flags"`
	PrefixContextFormat  string      `json:"prefixContextFormat"`
	PrefixFunctionFormat string      `json:"prefixFunctionFormat"`
	logConfigName        string
}

// GoLogFlags defines the flags available as part of GoLogConfig configuration.
type GoLogFlags struct {
	Date                bool `json:"date"`
	Time                bool `json:"time"`
	TimeInMicrosecond   bool `json:"timeInMicrosecond"`
	TimeInUTC           bool `json:"timeInUTC"`
	LongFile            bool `json:"longFile"`
	ShortFile           bool `json:"shortFile"`
	PrefixAtStartOfLine bool `json:"prefixAtStartOfLine"`
}

type goDriver struct {
}

type goAppender struct {
	config    *GoLogConfig
	logger    *log.Logger
	formatter Formatter
}

var defaultGoLogConfig = &GoLogConfig{
	Prefix:     "",
	OutputFile: "",
	out:        os.Stdout,
	Flags: &GoLogFlags{
		Date:                true,
		Time:                true,
		TimeInMicrosecond:   false,
		TimeInUTC:           false,
		LongFile:            false,
		ShortFile:           false,
		PrefixAtStartOfLine: false,
	},
	PrefixContextFormat:  "[%s][%s] ",
	PrefixFunctionFormat: "[%s][%s.%s(%v)] ",
	logConfigName:        "GoLogger",
}

type goAppenderFormatter struct {
	contextFormatter  string
	functionFormatter string
}

var defaultGoDriver = &goDriver{}

var defaultGoLogger = &goAppender{
	config:    defaultGoLogConfig,
	logger:    log.Default(),
	formatter: createFormatter(defaultGoLogConfig),
}
