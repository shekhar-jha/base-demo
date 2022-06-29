package log

import (
	"os"
	"strings"
	"testing"
)

func TestGoDriver_GetAppender(t *testing.T) {
	if appender := defaultGoDriver.GetAppender(nil); appender != defaultGoLogger {
		t.Error("Expected ", defaultGoLogger, " Actual: ", appender)
	}
}

func TestGoAppenderFormatter_Format(t *testing.T) {
	if result := (&goAppenderFormatter{}).Format(nil); result != "NA" {
		t.Error("Expected NA, Actual: ", result)
	}
	simpleConfig := getGoLoggerConfig("InternalConfig", nil)
	goLogConfig := simpleConfig.config.(*GoLogConfig)

	goLogConfig.Prefix = "PREFIX"
	goLogConfig.OutputFile = "./test.log"
	goLogConfig.out = nil
	goLogConfig.Flags.LongFile = true
	goLogConfig.Flags.PrefixAtStartOfLine = true
	logger := defaultGoDriver.GetAppender(simpleConfig)
	logger.Log(&simplePackageEvent{
		packageContext: (&simpleContextPackage{}).Add(RootContext),
		simpleLogEvent: simpleLogEvent{
			level:   Warn,
			message: "Log warn with no args",
			args:    nil,
		},
	})
	err := os.Remove("./test.log")
	if err != nil {
		t.Error("Expected no error while deleting file. Actual: ", err)
	}
}

func TestCreateGoLogger(t *testing.T) {
	if createGoLogger(nil) == nil {
		t.Error("Expected not nil logger, Actual nil")
	}
	simpleConfig := getGoLoggerConfig("InternalConfig", nil)
	goLogConfig := simpleConfig.config.(*GoLogConfig)
	goLogConfig.OutputFile = "./test.log/"
	goLogConfig.out = nil
	goLogConfig.Flags.ShortFile = true
	goLogConfig.Flags.TimeInUTC = true
	goLogConfig.Flags.PrefixAtStartOfLine = true
	logger := defaultGoDriver.GetAppender(simpleConfig)
	logger.Log(&simplePackageEvent{
		packageContext: (&simpleContextPackage{}).Add(RootContext),
		simpleLogEvent: simpleLogEvent{
			level:   Warn,
			message: "Log warn with no args",
			args:    nil,
		},
	})
}

func TestEmptyFlagConfig(t *testing.T) {
	if createGoLogger(nil) == nil {
		t.Error("Expected not nil logger, Actual nil")
	}
	logCapture := &strings.Builder{}
	simpleConfig := getGoLoggerConfig("InternalConfig", logCapture)
	goLogConfig := simpleConfig.config.(*GoLogConfig)
	goLogConfig.Flags = nil
	logger := defaultGoDriver.GetAppender(simpleConfig)
	logger.Log(&simplePackageEvent{
		packageContext: (&simpleContextPackage{}).Add(RootContext),
		simpleLogEvent: simpleLogEvent{
			level:   Warn,
			message: "Log warn with no args",
			args:    nil,
		},
	})
	if logCapture.String() == "" {
		t.Error("Expected not empty string")
	}
}

func TestDisabledFlags(t *testing.T) {
	logCapture := &strings.Builder{}
	simpleConfig := getGoLoggerConfig("InternalConfig", logCapture)
	goLogConfig := simpleConfig.config.(*GoLogConfig)
	goLogConfig.Flags = &GoLogFlags{}
	logger := defaultGoDriver.GetAppender(simpleConfig)
	logger.Log(&simplePackageEvent{
		packageContext: (&simpleContextPackage{}).Add(RootContext),
		simpleLogEvent: simpleLogEvent{
			level:   Warn,
			message: "Log warn with no args",
			args:    nil,
		},
	})
	if logCapture.String() == "" {
		t.Error("Expected not empty string")
	}
}
