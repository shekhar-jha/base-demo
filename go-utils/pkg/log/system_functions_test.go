package log

import (
	errext "github.com/shekhar-jha/base-demo/go-utils/pkg/err"
	"strings"
	"testing"
)

func TestSimpleSystem_GetRootLogger(t *testing.T) {
	t.Run("Nil", func(t *testing.T) {
		var nilSystem *simpleSystem = nil
		if nilSystem.GetLogger() == nil {
			t.Error("Expected not nil, Actual nil")
		}
		if nilSystem.GetLogger() != defaultLoggerSystem.GetLogger() {
			t.Error("Expected ", defaultLoggerSystem.GetLogger(), ", Actual: ", nilSystem.GetLogger())
		}
		var logCapture = &strings.Builder{}
		goLoggerConfigName := "TestSimpleSystem_GetRootLogger"
		loggerConfig := getGoLoggerConfig(goLoggerConfigName, logCapture)
		nilSystem.ConfigureAppender(loggerConfig)
		if actualConfig, contains := defaultLoggerSystem.(*simpleSystem).appenders[goLoggerConfigName]; !contains {
			t.Error("Expected default logger to contains logger with matching name ", goLoggerConfigName)
		} else if actualConfig != loggerConfig {
			t.Error("Expected config ", loggerConfig, " Actual: ", actualConfig)
		}
	})
}

func TestSimpleSystem_Configure(t *testing.T) {
	var logCapture = &strings.Builder{}
	var aSimpleSystem = NewSystem(Info, defaultGoDriver, getGoLoggerConfig("TestSimpleSystem_Configure", logCapture))
	aSimpleSystem.Configure(&simpleLogConfig{
		level:    Warn,
		appender: "TestSimpleSystem_Configure",
	}, "CTX1")
	ctx1Logger := aSimpleSystem.GetLogger("CTX1")
	testLog(t, ctx1Logger, logCapture, Debug, false, "", "Do not log debug")
	testLog(t, ctx1Logger, logCapture, Info, false, "", "Do not log Info")
	testLog(t, ctx1Logger, logCapture, Warn, true, "{Warn}{CTX1} Log warn with no args", "Log warn with no args")
	ctx123Logger := aSimpleSystem.GetLogger("CTX1", "CTX2", "CTX3")
	testLog(t, ctx123Logger, logCapture, Debug, false, "", "Do not log debug")
	testLog(t, ctx123Logger, logCapture, Info, false, "", "Do not log Info")
	testLog(t, ctx123Logger, logCapture, Warn, true, "{Warn}{CTX1.CTX2.CTX3} Log warn with no args", "Log warn with no args")
	aSimpleSystem.Configure(&simpleLogConfig{
		level:    Error,
		appender: "TestSimpleSystem_Configure",
	}, "CTX1")
	testLog(t, ctx1Logger, logCapture, Debug, false, "", "Do not log debug")
	testLog(t, ctx1Logger, logCapture, Info, false, "", "Do not log info")
	testLog(t, ctx1Logger, logCapture, Error, true, "{Error}{CTX1} Log error with no args", "Log error with no args")
	testLog(t, ctx123Logger, logCapture, Debug, false, "", "Do not log debug")
	testLog(t, ctx123Logger, logCapture, Info, false, "", "Do not log info")
	testLog(t, ctx123Logger, logCapture, Error, true, "{Error}{CTX1.CTX2.CTX3} Log error with no args", "Log error with no args")
	aSimpleSystem.Configure(&simpleLogConfig{
		level:    Debug,
		appender: "TestSimpleSystem_Configure",
	}, "CTX1", "CTX2")
	testLog(t, ctx1Logger, logCapture, Debug, false, "", "Do not log debug")
	testLog(t, ctx1Logger, logCapture, Info, false, "", "Do not log info")
	testLog(t, ctx1Logger, logCapture, Error, true, "{Error}{CTX1} Log error with no args", "Log error with no args")
	testLog(t, ctx123Logger, logCapture, Debug, true, "{Debug}{CTX1.CTX2.CTX3} Log debug message with 1 args Arg1", "Log debug message with 1 args %s", "Arg1")
	testLog(t, ctx123Logger, logCapture, Info, true, "{Info}{CTX1.CTX2.CTX3} Log info", "Log info")
	testLog(t, ctx123Logger, logCapture, Error, true, "{Error}{CTX1.CTX2.CTX3} Log error with no args", "Log error with no args")
	aSimpleSystem.Configure(&simpleLogConfig{
		level:    Info,
		appender: "TestSimpleSystem_Configure",
	}, "CTX1")
	testLog(t, ctx1Logger, logCapture, Debug, false, "", "Do not log debug")
	testLog(t, ctx1Logger, logCapture, Info, true, "{Info}{CTX1} Log info with 1 arg Arg1", "Log info with 1 arg %s", "Arg1")
	testLog(t, ctx1Logger, logCapture, Error, true, "{Error}{CTX1} Log error with no args", "Log error with no args")
	testLog(t, ctx123Logger, logCapture, Debug, true, "{Debug}{CTX1.CTX2.CTX3} Log debug message with 1 args Arg1", "Log debug message with 1 args %s", "Arg1")
	testLog(t, ctx123Logger, logCapture, Info, true, "{Info}{CTX1.CTX2.CTX3} Log info", "Log info")
	testLog(t, ctx123Logger, logCapture, Error, true, "{Error}{CTX1.CTX2.CTX3} Log error with no args", "Log error with no args")

}

func testLog(t *testing.T, logger LoggerBase, logCapture *strings.Builder, level Level, logged bool, expectedMessage string, message string, args ...interface{}) {
	logCapture.Reset()
	logger.LogWithLevel(level, message, args...)
	if logged {
		if !strings.Contains(logCapture.String(), expectedMessage) {
			t.Error("Expected ", expectedMessage, ", Actual: ", logCapture.String())
		}
	} else {
		if logCapture.String() != "" {
			t.Error("Expected message to not be logged. Actual: ", logCapture.String())
		}
	}
}
func TestSimpleSystem_GetDriver(t *testing.T) {
	t.Run("Nil", func(t *testing.T) {
		var simpleSystem *simpleSystem = nil
		if simpleSystem.GetDriver() == nil {
			t.Error("Expected not nil, Actual nil")
		}
	})
	t.Run("default", func(t *testing.T) {
		if defaultLoggerSystem.GetDriver() == nil {
			t.Error("Expected not nil, Actual nil")
		}
	})
}

func TestGetLoggerMultipleCalls(t *testing.T) {
	logger1 := GetLogger("CTX1")
	GetLogger("CXT1", "CTX2")
	logger1Again := GetLogger("CTX1")
	if logger1Again != logger1 {
		t.Error("Expected multiple calls to get logger for context CTX1 to return same logger.")
	}
}

func TestGetLoggerWithConfig(t *testing.T) {
	var logTracker = &strings.Builder{}
	testLogSystem := NewSystem(Info, defaultGoDriver, getGoLoggerConfig("TestGetLoggerWithConfig", logTracker))
	logger1 := testLogSystem.GetLogger("CTX1")
	logger1.Log("Logger1 with no arguments")
}

func TestDefault(t *testing.T) {
	defaultSystem := Default()
	defaultSystem.GetLogger("CTXA").Log("Hello world")
}

type nilDriver struct{}

func (driver *nilDriver) GetAppender(appender ConfigAppender) Appender {
	return nil
}

func TestNewSystemE(t *testing.T) {
	logCapture := &strings.Builder{}
	t.Run("TestNilDriver", func(t *testing.T) {
		_, err := NewSystemE(Info, nil, getGoLoggerConfig("TestNilDriver", logCapture))
		if err == nil {
			t.Error("Expected error, Actual nil error")
			t.FailNow()
		}
		if !ErrNilDriver.Is(err) {
			t.Error("Expected error of type ErrNilDriver, Actual: ", err)
		}
	})
	t.Run("TestNilConfig", func(t *testing.T) {
		_, err := NewSystemE(Info, defaultGoDriver, nil)
		if err == nil {
			t.Error("Expected error, Actual nil error")
			t.FailNow()
		}
		if !ErrEmptyLogConfigName.Is(err) {
			t.Error("Expected error of type ErrEmptyLogConfigName, Actual: ", err)
		}
	})
	t.Run("TestEmptyConfigName", func(t *testing.T) {
		_, err := NewSystemE(Info, defaultGoDriver, getGoLoggerConfig("", logCapture))
		if err == nil {
			t.Error("Expected error, Actual nil error")
			t.FailNow()
		}
		if !ErrEmptyLogConfigName.Is(err) {
			t.Error("Expected error of type ErrEmptyLogConfigName, Actual: ", err)
		}
	})
	t.Run("TestNilLevel", func(t *testing.T) {
		newSystem, err := NewSystemE(nil, defaultGoDriver, getGoLoggerConfig("TestNilLevel", logCapture))
		if err != nil {
			t.Error("Expected success, Actual ", err)
		}
		if newSystem == nil {
			t.Error("Expected not nil system, Actual: nil")
		}
	})
	t.Run("TestAppenderNil", func(t *testing.T) {

		newSystem, err := NewSystemE(nil, &nilDriver{}, getGoLoggerConfig("TestNilLevel", logCapture))
		if newSystem != nil {
			t.Error("Expected nil, Actual: ", newSystem)
		}
		if err == nil {
			t.Error("Expected failure, Actual success")
			t.FailNow()
		}
		if !ErrAppenderCreationFailed.Is(err) {
			t.Error("Expected ErrAppenderCreationFailed, Actual: ", err)
		}
		expectedErrString := "Could not create appender for configuration TestNilLevel using driver &{}"
		if err.Error() != expectedErrString {
			t.Error("Expected: ", expectedErrString, "Actual: ", err.Error())
		}
	})
}

func TestNewSystemP(t *testing.T) {
	logCapture := &strings.Builder{}
	t.Run("TestNilDriver", func(t *testing.T) {
		defer func() {
			if err := recover(); err == nil {
				t.Error("Expected Error, Actual nil")
			} else if !ErrNilDriver.Is(err.(errext.Error)) {
				t.Error("Expected ErrNilDriver, Actual ", err)
			}
		}()
		NewSystemP(Info, nil, getGoLoggerConfig("TestNilDriver", logCapture))
	})
}
