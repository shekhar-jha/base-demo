package main

import (
	"context"
	logger "github.com/grinps/go-utils/base-utils/logs"
	"github.com/grinps/go-utils/errext"
	"reflect"
)

const (
	ErrCfgName                  = "cfgName"
	ErrCfgParamConfigParamName  = "param"
	ErrCfgParamConfigParamValue = "value"
	ErrCfgParamOps              = "operation"
	ErrCfgParamOpsLoad          = "load"
)

type ConfigFormat string

const (
	FormatUnknown ConfigFormat = ""
	FormatInvalid ConfigFormat = "FormatInvalid"
	FormatYAML    ConfigFormat = "yaml"
)

var ErrConfigParamError = errext.NewErrorCodeWithOptions(errext.WithTemplate("error encountered while setting parameter", "[param]", "with value", "[value]", "was", "[error]"))
var ErrConfigOpsError = errext.NewErrorCodeWithOptions(errext.WithTemplate("error encountered while performing", "[operation]", "on configuration", "[cfgName]", "was", "[error]"))

type ConfigType[V Config] func() V
type Config interface {
	Load(ctx context.Context) (Config, error)
	GetValue(ctx context.Context, key string) any
	GetValueIfAvailable(ctx context.Context, key string, defaultValue any) any
}

func GetValue[T any](ctx context.Context, config Config, key string) T {
	var nilVal T
	return GetValueIfAvailable[T](ctx, config, key, nilVal)
}

func GetValueIfAvailable[T any](ctx context.Context, config Config, key string, defaultValue T) T {
	if config != nil {
		availableValue := config.GetValueIfAvailable(ctx, key, defaultValue)
		logger.Log("Retrieved config value for key", key, "as", availableValue, "(", reflect.TypeOf(availableValue), ")")
		if asT, isT := availableValue.(T); isT {
			return asT
		}
	}
	return defaultValue
}

type WithConfigParameter[T Config] func(config T) error

func NewConfig[T ConfigType[V], V Config](ctx context.Context, cfgType T, configurations ...WithConfigParameter[V]) (V, error) {
	var returnConfig V
	var nilConfig V
	if cfgType != nil {
		returnConfig = cfgType()
	}
	for _, configuration := range configurations {
		err := configuration(returnConfig)
		if err != nil {
			return nilConfig, err
		}
	}
	loadedConfig, loadErr := returnConfig.Load(ctx)
	if loadErr != nil || loadedConfig == nil {
		return nilConfig, loadErr
	}
	returnConfig = loadedConfig.(V)
	return returnConfig, nil
}
