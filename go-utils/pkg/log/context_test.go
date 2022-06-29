package log

import "testing"

func TestPackageContext_Add(t *testing.T) {
	defaultPackage := simpleContextPackage{}
	if defaultPackage.context != "" {
		t.Error("Expected empty string, actual: ", defaultPackage.context)
	}
	defaultPackage.Add("")
	if defaultPackage.context != "" {
		t.Error("Expected empty string, actual: ", defaultPackage.context)
	}
	defaultPackage.Add("CTX1")
	if defaultPackage.context != "CTX1" {
		t.Error("Expected CTX1, actual: ", defaultPackage.context)
	}
	defaultPackage.Add("")
	if defaultPackage.context != "CTX1" {
		t.Error("Expected CTX1, actual: ", defaultPackage.context)
	}
	defaultPackage.Add("CTX2")
	if defaultPackage.context != "CTX1.CTX2" {
		t.Error("Expected CTX1.CTX2, actual: ", defaultPackage.context)
	}
	defaultPackage.Add("CTX3", "CTX4", "@##.@#", "CTX6")
	if defaultPackage.context != "CTX1.CTX2.CTX3.CTX4.@##.@#.CTX6" {
		t.Error("Expected CTX1.CTX2.CTX3.CTX4.@##.@#.CTX6, actual: ", defaultPackage.context)
	}
	defaultPackage.Add("CTX7", "", "jdksjdkjsd")
	if defaultPackage.context != "CTX1.CTX2.CTX3.CTX4.@##.@#.CTX6.CTX7.jdksjdkjsd" {
		t.Error("Expected CTX1.CTX2.CTX3.CTX4.@##.@#.CTX6.CTX7.jdksjdkjsd, actual: ", defaultPackage.context)
	}
}

func TestPackageContext_Is(t *testing.T) {
	contextPackage := (&simpleContextPackage{}).Add("CTX1", "CTX2")
	contextFunction := simpleContextFunction{
		packageContext: contextPackage,
		method: &simpleContextMethod{
			method: "Method1",
			values: nil,
		},
		parent: nil,
	}
	if !contextPackage.Is(ContextPackageType) {
		t.Error("Context package ", contextPackage, " of type ", ContextPackageType, "Expected: True, Actual : False")
	}
	if contextPackage.Is(ContextFunctionType) {
		t.Error("Context package ", contextPackage, " of type ", ContextFunctionType, "Expected: False, Actual : True")
	}
	if contextFunction.Is(ContextPackageType) {
		t.Error("Context function ", contextFunction, " of type ", ContextPackageType, "Expected: False, Actual : True")
	}
	if !contextFunction.Is(ContextFunctionType) {
		t.Error("Context function ", contextFunction, " of type ", ContextFunctionType, "Expected: True, Actual : False")
	}
}
