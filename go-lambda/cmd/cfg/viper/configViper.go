package viper

import (
	"context"
	"errors"
	logger "github.com/grinps/go-utils/base-utils/logs"
	"github.com/grinps/go-utils/errext"
	"github.com/shekhar-jha/base-demo/go-lambda/cmd/cfg"
	"github.com/shekhar-jha/base-demo/go-lambda/cmd/common"
	"github.com/spf13/viper"
	"reflect"
)

const (
	DefaultContext          = ""
	DefaultContextSeparator = "."
)

type ViperConfig = cfg.ConfigType[*configImpl]

var ViperGen ViperConfig = func() *configImpl {
	return &configImpl{
		name:             "Invalid Configuration",
		loadedConfig:     viper.New(),
		format:           cfg.FormatInvalid,
		contexts:         []string{""}, // empty string represents configuration key without suffixes
		contextSeparator: DefaultContextSeparator,
	}
}

func NewViperConfig(ctx context.Context, fileName string, paths []string, additionalConfigs ...cfg.WithConfigParameter[*configImpl]) cfg.Config {
	newConfig, _ := NewViperConfigE(ctx, fileName, paths, additionalConfigs...)
	return newConfig
}

func NewViperConfigP(ctx context.Context, fileName string, paths []string, additionalConfigs ...cfg.WithConfigParameter[*configImpl]) cfg.Config {
	newConfig, err := NewViperConfigE(ctx, fileName, paths, additionalConfigs...)
	if err != nil {
		panic(err)
	}
	return newConfig
}

func NewViperConfigE(ctx context.Context, fileName string, paths []string, additionalConfigs ...cfg.WithConfigParameter[*configImpl]) (cfg.Config, error) {
	var configs []cfg.WithConfigParameter[*configImpl]
	configs = append(configs, SetConfigFileName(ctx, fileName), AddConfigPaths(ctx, paths...))
	configs = append(configs, SetConfigFormat(ctx, cfg.FormatYAML))
	configs = append(configs, additionalConfigs...)
	return cfg.NewConfig[ViperConfig, *configImpl](ctx, ViperGen, configs...)
}

type configImpl struct {
	name             string
	fileName         string
	paths            []string
	format           cfg.ConfigFormat
	contexts         []string
	contextSeparator string
	loadedConfig     *viper.Viper
}

func (config *configImpl) String() string {
	if config != nil && config.name != "" {
		return config.name
	}
	return "Uninitialized Config"
}

func (config *configImpl) Load(ctx context.Context) (cfg.Config, error) {
	if config == nil {
		return config, cfg.ErrConfigOpsError.NewF(cfg.ErrCfgName, config, cfg.ErrCfgParamOps, cfg.ErrCfgParamOpsLoad, common.ErrParamCause, "Nil config passed")
	}
	if config.loadedConfig == nil {
		return config, cfg.ErrConfigOpsError.NewF(cfg.ErrCfgName, config, cfg.ErrCfgParamOps, cfg.ErrCfgParamOpsLoad, common.ErrParamCause, "nil cfg config (not initialized)")
	}
	cfgReadErr := config.loadedConfig.ReadInConfig()
	if cfgReadErr != nil {
		return config, cfg.ErrConfigOpsError.NewWithErrorF(cfgReadErr, cfg.ErrCfgName, config, cfg.ErrCfgParamOps, cfg.ErrCfgParamOpsLoad, common.ErrParamCause, cfgReadErr, errext.NewField("configFileName", config.fileName), errext.NewField("paths", config.paths))
	}
	logger.Log("Loaded keys:", config.loadedConfig.AllKeys())
	return config, nil
}

func (config *configImpl) GetValue(ctx context.Context, key string) interface{} {
	return config.GetValueIfAvailable(ctx, key, nil)
}

func (config *configImpl) GetValueIfAvailable(ctx context.Context, key string, defaultValue any) any {
	if config != nil && config.loadedConfig != nil {
		for _, cfgCtx := range config.contexts {
			applicableKey := key
			if cfgCtx != DefaultContext {
				applicableKey = key + config.contextSeparator + cfgCtx
			}
			returnValue := config.loadedConfig.Get(applicableKey)
			logger.Log("Got value of key", applicableKey, "as", returnValue, "(", reflect.TypeOf(returnValue), ")")
			if returnValue != nil && returnValue != "" {
				return returnValue
			}
		}
	}
	return defaultValue
}

func SetConfigFileName(ctx context.Context, fileName string) cfg.WithConfigParameter[*configImpl] {
	var validateErr error
	if fileName == "" {
		validateErr = cfg.ErrConfigParamError.NewF(cfg.ErrCfgParamConfigParamName, "file name", cfg.ErrCfgParamConfigParamValue, "", common.ErrParamCause, "file name can not empty string")
	}
	return func(config *configImpl) error {
		if validateErr != nil {
			return validateErr
		}
		config.fileName = fileName
		config.loadedConfig.SetConfigFile(fileName)
		return nil
	}
}

func AddConfigPaths(ctx context.Context, paths ...string) cfg.WithConfigParameter[*configImpl] {
	var validateErr []error
	if len(paths) == 0 {
		validateErr = append(validateErr, cfg.ErrConfigParamError.NewF(cfg.ErrCfgParamConfigParamName, "search paths", cfg.ErrCfgParamConfigParamValue, paths, common.ErrParamCause, "at least one path must be provided"))
	}
	return func(config *configImpl) error {
		if len(validateErr) > 0 {
			return errors.Join(validateErr...)
		}
		config.paths = paths
		for _, path := range paths {
			config.loadedConfig.AddConfigPath(path)
		}
		return nil
	}
}

func SetConfigFormat(ctx context.Context, format cfg.ConfigFormat) cfg.WithConfigParameter[*configImpl] {
	return func(config *configImpl) error {
		switch format {
		case cfg.FormatYAML:
			config.format = cfg.FormatYAML
			config.loadedConfig.SetConfigType("yaml")
		default:
			return cfg.ErrConfigParamError.NewF(cfg.ErrCfgParamConfigParamName, "format", cfg.ErrCfgParamConfigParamValue, format, common.ErrParamCause, "format not supported")
		}
		return nil
	}
}

func SetConfigHierarchy(ctx context.Context, contexts ...string) cfg.WithConfigParameter[*configImpl] {
	return SetConfigHierarchyWithDefaultOverride(ctx, false, contexts...)
}

func SetConfigHierarchyWithDefaultOverride(ctx context.Context, defaultOverridesAll bool, contexts ...string) cfg.WithConfigParameter[*configImpl] {
	return func(config *configImpl) error {
		containsDefault := false
		for _, cfgCtx := range contexts {
			if cfgCtx == DefaultContext {
				containsDefault = true
			}
		}
		var applicableContexts = make([]string, len(contexts))
		copiedValues := copy(applicableContexts, contexts)
		if copiedValues != len(contexts) {
			return cfg.ErrConfigOpsError.NewF(cfg.ErrCfgName, config.name, cfg.ErrCfgParamOps, cfg.ErrCfgParamOpsSetContexts, common.ErrParamCause, "complete copy of the context could not be created", errext.NewField("contexts", contexts), errext.NewField("copied items", copiedValues))
		}
		if !containsDefault {
			if !defaultOverridesAll {
				applicableContexts = append(applicableContexts, DefaultContext) //adding the default context to end as last resort
			} else {
				applicableContexts = append([]string{DefaultContext}, applicableContexts...) //adding the default context to end as last resort
			}
		}
		config.contexts = applicableContexts
		return nil
	}
}
