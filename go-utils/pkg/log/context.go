package log

import "strings"

// ContextType defines the different types of Contexts.
type ContextType int

//Types of Contexts
const (
	ContextPackageType  = 0b0001
	ContextFunctionType = 0b0010
)

// Context defines the basic functions for all Contexts
type Context interface {
	Is(contextType ContextType) bool
}

// ContextPackage defines methods like Add and GetContext to build a hierarchical Context representing the Go Package
// structure
type ContextPackage interface {
	Add(contextItem ...string) ContextPackage
	GetContext() string
	Context
}

// ContextMethod represents the context of a method with method name and passed arguments
type ContextMethod interface {
	GetMethod() string
	GetArguments() []interface{}
}

// ContextHierarchical has GetParentContext that returns the parent Context.
type ContextHierarchical interface {
	GetParentContext() Context
	Context
}

// ContextHierarchicalConfigurable allows setting parent context.
type ContextHierarchicalConfigurable interface {
	SetParentContext(context Context)
}

var packageContextDelimiter = "."

type simpleContextPackage struct {
	context string
}

func (contextVal *simpleContextPackage) Add(contextItem ...string) ContextPackage {
	stringBuilder := strings.Builder{}
	stringBuilder.WriteString(contextVal.context)
	size := len(contextItem)
	for index, item := range contextItem {
		if item != "" {
			if index == 0 {
				if len(contextVal.context) > 0 {
					stringBuilder.WriteString(packageContextDelimiter)
				}
			}
			stringBuilder.WriteString(item)
			if index < size-1 {
				stringBuilder.WriteString(packageContextDelimiter)
			}
		}
	}
	contextVal.context = stringBuilder.String()
	return contextVal
}

func (contextVal *simpleContextPackage) GetContext() string {
	return contextVal.context
}

func (contextVal *simpleContextPackage) Is(contextType ContextType) bool {
	if contextType == ContextPackageType {
		return true
	}
	return false
}

type simpleContextMethod struct {
	method string
	values []interface{}
}

func (context *simpleContextMethod) GetMethod() string {
	return context.method
}

func (context *simpleContextMethod) GetArguments() []interface{} {
	return context.values
}

// ContextFunction defines the complete context within a function which is a combination of Package in which function is
// present, method name and arguments and the calling function.
type ContextFunction interface {
	GetPackageContext() ContextPackage
	GetMethodContext() ContextMethod
	ContextHierarchical
}

type simpleContextFunction struct {
	packageContext ContextPackage
	method         ContextMethod
	parent         Context
}

func (contextVal *simpleContextFunction) Is(contextType ContextType) bool {
	if contextType == ContextFunctionType {
		return true
	}
	return false
}

func (contextVal *simpleContextFunction) GetParentContext() Context {
	return contextVal.parent
}

func (contextVal *simpleContextFunction) GetPackageContext() ContextPackage {
	return contextVal.packageContext
}

func (contextVal *simpleContextFunction) SetParentContext(context Context) {
	contextVal.parent = context
}

func (contextVal *simpleContextFunction) GetMethodContext() ContextMethod {
	return contextVal.method
}
