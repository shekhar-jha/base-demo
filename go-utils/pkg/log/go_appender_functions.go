package log

import (
	"fmt"
	"io"
	"log"
	"os"
)

func init() {
	if defaultGoLogger.config != nil {
		var newLogger = createGoLogger(defaultGoLogger.config)
		if newLogger != nil {
			defaultGoLogger.logger = newLogger
		}
	}
}

func (writer *goAppender) Log(event Event) {
	writer.logger.Print(writer.formatter.Format(event))
}

func (writer *goAppender) GetName() string {
	return writer.config.GetName()
}

func (driver *goDriver) GetAppender(config ConfigAppender) Appender {
	if config != nil {
		if goConfig, ok := config.GetConfig().(*GoLogConfig); ok && goConfig != nil {
			var newGoWriter = &goAppender{
				config:    goConfig,
				logger:    createGoLogger(goConfig),
				formatter: config.GetFormatter(),
			}
			return newGoWriter
		}
	}
	return defaultGoLogger
}

func (config *GoLogConfig) GetName() string {
	return config.logConfigName
}

func createFormatter(config *GoLogConfig) Formatter {
	return &goAppenderFormatter{
		contextFormatter:  config.PrefixContextFormat,
		functionFormatter: config.PrefixFunctionFormat,
	}

}

func (formatter *goAppenderFormatter) Format(event Event) string {
	if asPackage, isPackage := event.(EventPackage); isPackage {
		return fmt.Sprintf(formatter.contextFormatter, asPackage.GetLevel().String(), asPackage.GetPackage().GetContext()) + fmt.Sprintf(asPackage.GetMessage(), asPackage.GetArguments()...)
	} else if asFunction, isFunction := event.(EventFunction); isFunction {
		return fmt.Sprintf(formatter.functionFormatter, asFunction.GetLevel().String(), asFunction.GetFunction().GetPackageContext().GetContext(), asFunction.GetFunction().GetMethodContext().GetMethod(), asFunction.GetFunction().GetMethodContext().GetArguments()) + fmt.Sprintf(asFunction.GetMessage(), asFunction.GetArguments()...)
	}
	return "NA"
}

func createGoLogger(config *GoLogConfig) *log.Logger {
	if config == nil {
		config = defaultGoLogger.config
	}
	var flag = getFlag(config.Flags)
	var outputFileReference io.Writer = os.Stderr
	if config.out != nil {
		outputFileReference = config.out
	} else {
		if config.OutputFile != "" {
			if openedLogFile, openFileErr := os.OpenFile(config.OutputFile, os.O_APPEND|os.O_WRONLY|os.O_CREATE, 0644); openFileErr == nil {
				outputFileReference = openedLogFile
			} else {
				log.Print("Failed to open file ", config.OutputFile, " due to error ", openFileErr)
				outputFileReference = os.Stderr
			}
		}
	}
	return log.New(outputFileReference, config.Prefix, flag)
}

func getFlag(flagConfig *GoLogFlags) int {
	if flagConfig != nil {
		var returnFlag int = 0
		var config = *flagConfig
		if config.Date {
			returnFlag = returnFlag | log.Ldate
		}
		if config.Time {
			returnFlag = returnFlag | log.Ltime
		}
		if config.Time && config.TimeInMicrosecond {
			returnFlag = returnFlag | log.Lmicroseconds
		}
		if config.LongFile && !config.ShortFile {
			returnFlag = returnFlag | log.Llongfile
		}
		if config.ShortFile && !config.LongFile {
			returnFlag = returnFlag | log.Lshortfile
		}
		if config.PrefixAtStartOfLine {
			returnFlag = returnFlag | log.Lmsgprefix
		}
		if config.TimeInUTC {
			returnFlag = returnFlag | log.LUTC
		}
		if returnFlag == 0 {
			returnFlag = log.LstdFlags
		}
		return returnFlag
	} else {
		return log.LstdFlags
	}
}
