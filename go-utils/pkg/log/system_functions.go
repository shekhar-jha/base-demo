package log

import errext "github.com/shekhar-jha/base-demo/go-utils/pkg/err"

func (system *simpleSystem) GetDriver() Driver {
	if system == nil {
		return defaultLoggerSystem.GetDriver()
	}
	return system.logDriver
}

// GetLogger finds the node corresponding to given context and applicable
// configuration by looking for node in context hierarchy with Set configuration
// If no attached logger is found, it creates a new logger using the available
// configuration. If the applicable node has configuration Set (i.e. applicable
// config node is same as applicable node) then Logger is created otherwise Inherited
// configuration is populated on the node and then Logger is created.
func (system *simpleSystem) GetLogger(context ...string) Logger {
	if system == nil {
		return defaultLoggerSystem.GetLogger()
	}
	var returnLogger = system.rootLoggerNode.systemContext.logger
	var applicableConfigNode = system.rootLoggerNode
	var applicableLoggerNode = findNode(system.rootLoggerNode, func(node *node, context string) int {
		if node != nil && node.systemContext.inherited == Set {
			applicableConfigNode = node
		}
		return 0
	}, context...)
	if applicableLoggerNode != nil {
		if applicableLoggerNode.systemContext.logger == nil {
			if applicableLoggerNode == applicableConfigNode {
				applicableLoggerNode.AddLogger()
			} else {
				applicableLoggerNode.PopulateFromNode(applicableConfigNode).AddLogger()
			}
			returnLogger = applicableLoggerNode.systemContext.logger
		} else {
			returnLogger = applicableLoggerNode.systemContext.logger
		}
	}
	return returnLogger
}

func (system *simpleSystem) ConfigureAppender(appenderConfig ConfigAppender) {
	if system == nil {
		defaultLoggerSystem.ConfigureAppender(appenderConfig)
	} else {
		system.appenders[appenderConfig.GetName()] = appenderConfig
	}
}

// Configure setups logger for the given ConfigLogger and context. It finds the applicable node
// for given context, populates the new configuration and refreshes attached logger with new
// configuration. All the child nodes that had inherited the configuration are updated with the new configuration
// and the logger is refreshed.
func (system *simpleSystem) Configure(loggerConfig ConfigLogger, context ...string) {
	var applicableLoggerNode = findNode(system.rootLoggerNode, nil, context...)
	if applicableLoggerNode != nil {
		newAppender := system.GetDriver().GetAppender(system.appenders[loggerConfig.GetAppenderName()])
		applicableLoggerNode.Populate(loggerConfig, newAppender).RefreshLogger()
		updateChildNodes(applicableLoggerNode, func(node *node, context string) int {
			if node.systemContext.inherited == Inherited {
				node.PopulateFromNode(applicableLoggerNode).RefreshLogger()
				// Continue processing child nodes since this node inherited value so may have child nodes
				// that inherited values
				return 0
			} else if node.systemContext.inherited == Set {
				// Stop processing child nodes since this node has explicitly set values.
				return 1
			}
			// Continue processing child nodes since this node does not have any associated loggers and so may have
			// child nodes with associated inherited or set appender
			return 0
		})
	}
}

type processNode func(node *node, context string) int

func findNode(rootLoggerNode *node, nodeProcessor processNode, context ...string) *node {
	var returnLoggerNode = rootLoggerNode
	if len(context) > 0 {
		var currentLoggerNode = rootLoggerNode
		for _, contextItem := range context {
			if childLoggerNode, contextItemExists := currentLoggerNode.childNodeMap[contextItem]; contextItemExists && childLoggerNode != nil {
				currentLoggerNode = childLoggerNode
			} else {
				currentLoggerNode = newNode(contextItem, currentLoggerNode)
			}
			if nodeProcessor != nil {
				nodeProcessor(currentLoggerNode, contextItem)
			}
		}
		returnLoggerNode = currentLoggerNode
	}
	return returnLoggerNode
}

func updateChildNodes(node *node, nodeProcessor processNode) {
	if node != nil && nodeProcessor != nil {
		if len(node.childNodeMap) > 0 {
			for _, childNode := range node.childNodeMap {
				returnCode := nodeProcessor(childNode, childNode.context)
				if returnCode == 0 {
					updateChildNodes(childNode, nodeProcessor)
				}
			}
		}
	}
}

// GetLogger returns the Logger for the given context in the Default() system.
func GetLogger(context ...string) Logger {
	return defaultLoggerSystem.GetLogger(context...)
}

// ConfigureAppender configures the Appender in the Default() system.
func ConfigureAppender(appenderConfig ConfigAppender) {
	defaultLoggerSystem.ConfigureAppender(appenderConfig)
}

// Configure configures the Logger for given context using given ConfigLogger in the Default() system.
func Configure(loggerConfig ConfigLogger, context ...string) {
	defaultLoggerSystem.Configure(loggerConfig, context...)
}

// Default returns the default System.
func Default() System {
	return defaultLoggerSystem
}

// NewSystem creates a new System using the given details.
func NewSystem(defaultLevel Level, driver Driver, defaultConfig ConfigAppender) System {
	newSystem, _ := NewSystemE(defaultLevel, driver, defaultConfig)
	return newSystem
}

// NewSystemP creates a new System using the given details. In case of an error, it panics.
func NewSystemP(defaultLevel Level, driver Driver, defaultConfig ConfigAppender) System {
	if newSystem, err := NewSystemE(defaultLevel, driver, defaultConfig); err != nil {
		panic(err)
	} else {
		return newSystem
	}
}

// ErrNilDriver is errext.ErrorTemplate to create error in case Driver is invalid.
var ErrNilDriver = errext.NewErrorTemplate("InvalidDriver", "Nil Driver is not valid")

// ErrEmptyLogConfigName is errext.ErrorTemplate to create error in case ConfigAppender is invalid.
var ErrEmptyLogConfigName = errext.NewErrorTemplate("InvalidLoggerConfigName", "Empty Configuration name is not valid")

// ErrAppenderCreationFailed is errext.ErrorTemplate to create error in case Appender could not be created.
var ErrAppenderCreationFailed = errext.NewErrorTemplate("AppenderCreationFailed", "Could not create appender for configuration {{ .Data.ConfigName }} using driver {{ .Data.Driver }}")

// NewSystemE creates a new System for the given Level, Driver and Appender configuration.
func NewSystemE(defaultLevel Level, driver Driver, defaultConfig ConfigAppender) (System, errext.Error) {
	if driver == nil {
		return nil, ErrNilDriver.New()
	}
	if defaultLevel == nil {
		defaultLevel = Info
	}
	if defaultConfig == nil {
		return nil, ErrEmptyLogConfigName.New()
	}
	configName := defaultConfig.GetName()
	if defaultConfig.GetName() == "" {
		return nil, ErrEmptyLogConfigName.New()
	}
	appender := driver.GetAppender(defaultConfig)
	if appender == nil {
		return nil, ErrAppenderCreationFailed.New(struct {
			Driver     Driver
			ConfigName string
		}{Driver: driver, ConfigName: configName})
	}
	rootLogConfig := NewConfigLogger(defaultLevel, appender.GetName())
	return &simpleSystem{
		rootLoggerNode: newNode(RootContext, nil).Populate(rootLogConfig, appender).AddLogger(),
		appenders:      map[string]ConfigAppender{configName: defaultConfig},
		logDriver:      driver,
	}, nil
}

func newNode(context string, parentNode *node) *node {
	var aNewNode = &node{
		context:      context,
		parentNode:   parentNode,
		childNodeMap: map[string]*node{},
		systemContext: systemContext{
			logger:   nil,
			config:   nil,
			appender: nil,
		},
	}
	if parentNode != nil {
		parentNode.childNodeMap[aNewNode.context] = aNewNode
	}
	return aNewNode
}

func (node *node) Append(event Event) {
	if node != nil {
		if node.systemContext.appender != nil {
			node.systemContext.appender.Log(event)
		}
	}
}

func (node *node) Populate(loggerConfig ConfigLogger, appender Appender) *node {
	node.systemContext.inherited = Set
	node.systemContext.appender = appender
	node.systemContext.config = loggerConfig
	return node
}

func (node *node) PopulateFromNode(sourceNode *node) *node {
	node.systemContext.inherited = Inherited
	node.systemContext.appender = sourceNode.systemContext.appender
	node.systemContext.config = sourceNode.systemContext.config
	return node
}

func (node *node) AddLogger() *node {
	var contextStack = []string{node.context}
	for currentNode := node.parentNode; currentNode != nil; currentNode = currentNode.parentNode {
		if currentNode.context != RootContext {
			contextStack = append(contextStack, currentNode.context)
		}
	}
	var applicablePackage = &simpleContextPackage{}
	for contextIndex := len(contextStack) - 1; contextIndex >= 0; contextIndex-- {
		applicablePackage.Add(contextStack[contextIndex])
	}
	node.systemContext.logger = &simpleLogger{
		loggerSystem:   node,
		packageContext: applicablePackage,
		logLevel:       node.systemContext.config.GetLogLevel(),
	}
	return node
}

func (node *node) RefreshLogger() *node {
	if asConfigurableLogger, isConfigurableLogger := node.systemContext.logger.(LoggerConfigurable); isConfigurableLogger {
		asConfigurableLogger.SetLevel(node.systemContext.config.GetLogLevel())
	}
	return node
}
