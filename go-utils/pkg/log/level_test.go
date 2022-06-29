package log

import "testing"

func TestDefaultLevel_defaultObject(t *testing.T) {
	levelDefaultObject := simpleLevel{}
	if levelDefaultObject.level != 0 {
		t.Error("Default Level expected 0.Actual: ", levelDefaultObject.level)
	}
	if levelDefaultObject.name != "" {
		t.Error("Default Level name expected ''.Actual: ", levelDefaultObject.name)
	}
}

type differentLevel struct{}

func (level *differentLevel) String() string                    { return "" }
func (level *differentLevel) Compare(input Level) CompareResult { return Equals }

func TestDefaultLevel_ValidObject(t *testing.T) {
	testObject := Info
	if testObject.String() != "Info" {
		t.Error("Expected: Info, Actual: ", testObject.String())
	}
	if warnCompare := testObject.Compare(Warn); warnCompare != Less {
		t.Error("Info < Warn. Expected Less, Actual: ", warnCompare)
	}
	if debugCompare := testObject.Compare(Debug); debugCompare != Greater {
		t.Error("Info > Debug. Expected Greater, Actual: ", debugCompare)
	}
	equalInfo := &simpleLevel{
		level: levelInfo,
		name:  "Inform",
	}
	if infoCompare := testObject.Compare(equalInfo); infoCompare != Equals {
		t.Error("Info == InfoAlt. Expected Equals, Actual: ", infoCompare)
	}
	if nilCompare := testObject.Compare(nil); nilCompare != CanNotCompare {
		t.Error("Info ? nil. Expected CanNotCompare, Actual: ", nilCompare)
	}
	diffLevel := &differentLevel{}
	if diffCompare := testObject.Compare(diffLevel); diffCompare != CanNotCompare {
		t.Error("Info ? diffLevel. Expected CanNotCompare, Actual: ", diffCompare)
	}
}
