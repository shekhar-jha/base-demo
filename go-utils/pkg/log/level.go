package log

type levelValue int

// Level values for comparison
const (
	LevelValueInvalid levelValue = -1
	LevelStart                   = 0
	levelTrace                   = 1000
	levelDebug                   = 5000
	levelInfo                    = 10000
	levelWarn                    = 15000
	levelError                   = 20000
	LevelValueMax                = 32768
)

// CompareResult defines Result of comparison
type CompareResult int

// Besides standard Less, Equals and Greater it supports CanNotCompare to support scenarios where comparison is not possible
const (
	Less          CompareResult = -1
	Equals        CompareResult = 0
	Greater       CompareResult = 1
	CanNotCompare CompareResult = 10
)

type simpleLevel struct {
	level int
	name  string
}

// Level interface defines the methods to be supported by various levels.
type Level interface {
	String() string
	Compare(level Level) CompareResult
}

var (
	Trace Level = &simpleLevel{level: levelTrace, name: "Trace"}
	Debug Level = &simpleLevel{level: levelDebug, name: "Debug"}
	Info  Level = &simpleLevel{level: levelInfo, name: "Info"}
	Warn  Level = &simpleLevel{level: levelWarn, name: "Warn"}
	Error Level = &simpleLevel{level: levelError, name: "Error"}
)

func (level *simpleLevel) String() string { return level.name }

func (level *simpleLevel) Compare(input Level) CompareResult {
	if input == nil {
		return CanNotCompare
	}
	if levelAsDefault, isDefaultLevel := input.(*simpleLevel); isDefaultLevel {
		if level.level > levelAsDefault.level {
			return Greater
		}
		if level.level < levelAsDefault.level {
			return Less
		}
		return Equals
	}
	return CanNotCompare
}
