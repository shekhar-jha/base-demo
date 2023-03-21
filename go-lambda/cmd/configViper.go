package main

import (
	"context"
	"errors"
	logger "github.com/grinps/go-utils/base-utils/logs"
	"github.com/grinps/go-utils/errext"
	"github.com/spf13/viper"
	"reflect"
)

type ViperConfig = ConfigType[*configImpl]

var ViperGen ViperConfig = func() *configImpl {
	return &configImpl{
		name:         "Invalid Configuration",
		loadedConfig: viper.New(),
		format:       FormatInvalid,
	}
}

func NewViperConfig(ctx context.Context, fileName string, paths []string, additionalConfigs ...WithConfigParameter[*configImpl]) Config {
	newConfig, _ := NewViperConfigE(ctx, fileName, paths, additionalConfigs...)
	return newConfig
}

func NewViperConfigP(ctx context.Context, fileName string, paths []string, additionalConfigs ...WithConfigParameter[*configImpl]) Config {
	newConfig, err := NewViperConfigE(ctx, fileName, paths, additionalConfigs...)
	if err != nil {
		panic(err)
	}
	return newConfig
}

func NewViperConfigE(ctx context.Context, fileName string, paths []string, additionalConfigs ...WithConfigParameter[*configImpl]) (Config, error) {
	var configs []WithConfigParameter[*configImpl]
	configs = append(configs, SetConfigFileName(ctx, fileName), AddConfigPaths(ctx, paths...))
	configs = append(configs, SetConfigFormat(ctx, FormatYAML))
	configs = append(configs, additionalConfigs...)
	return NewConfig[ViperConfig, *configImpl](ctx, ViperGen, configs...)
}

type configImpl struct {
	name         string
	fileName     string
	paths        []string
	format       ConfigFormat
	loadedConfig *viper.Viper
}

func (config *configImpl) String() string {
	if config != nil && config.name != "" {
		return config.name
	}
	return "Uninitialized Config"
}

func (config *configImpl) Load(ctx context.Context) (Config, error) {
	if config == nil {
		return config, ErrConfigOpsError.NewF(ErrCfgName, config, ErrCfgParamOps, ErrCfgParamOpsLoad, ErrParamCause, "Nil config passed")
	}
	if config.loadedConfig == nil {
		return config, ErrConfigOpsError.NewF(ErrCfgName, config, ErrCfgParamOps, ErrCfgParamOpsLoad, ErrParamCause, "nil viper config (not initialized)")
	}
	cfgReadErr := config.loadedConfig.ReadInConfig()
	if cfgReadErr != nil {
		return config, ErrConfigOpsError.NewWithErrorF(cfgReadErr, ErrCfgName, config, ErrCfgParamOps, ErrCfgParamOpsLoad, ErrParamCause, cfgReadErr, errext.NewField("configFileName", config.fileName), errext.NewField("paths", config.paths))
	}
	logger.Log("Loaded keys:", config.loadedConfig.AllKeys())
	return config, nil
}

func (config *configImpl) GetValue(ctx context.Context, key string) interface{} {
	return config.GetValueIfAvailable(ctx, key, nil)
}

func (config *configImpl) GetValueIfAvailable(ctx context.Context, key string, defaultValue any) any {
	if config != nil && config.loadedConfig != nil {
		returnValue := config.loadedConfig.Get(key)
		logger.Log("Got value of key", key, "as", returnValue, "(", reflect.TypeOf(returnValue), ")")
		return returnValue
	}
	return defaultValue
}

func SetConfigFileName(ctx context.Context, fileName string) WithConfigParameter[*configImpl] {
	var validateErr error
	if fileName == "" {
		validateErr = ErrConfigParamError.NewF(ErrCfgParamConfigParamName, "file name", ErrCfgParamConfigParamValue, "", ErrParamCause, "file name can not empty string")
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

func AddConfigPaths(ctx context.Context, paths ...string) WithConfigParameter[*configImpl] {
	var validateErr []error
	if len(paths) == 0 {
		validateErr = append(validateErr, ErrConfigParamError.NewF(ErrCfgParamConfigParamName, "search paths", ErrCfgParamConfigParamValue, paths, ErrParamCause, "at least one path must be provided"))
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

func SetConfigFormat(ctx context.Context, format ConfigFormat) WithConfigParameter[*configImpl] {
	return func(config *configImpl) error {
		switch format {
		case FormatYAML:
			config.format = FormatYAML
			config.loadedConfig.SetConfigType("yaml")
		default:
			return ErrConfigParamError.NewF(ErrCfgParamConfigParamName, "format", ErrCfgParamConfigParamValue, format, ErrParamCause, "format not supported")
		}
		return nil
	}
}
