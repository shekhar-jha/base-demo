package dynamodb

import (
	"context"
	"errors"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	logger "github.com/grinps/go-utils/base-utils/logs"
	"github.com/shekhar-jha/base-demo/go-lambda/cmd/cfg"
	"github.com/shekhar-jha/base-demo/go-lambda/cmd/common"
	"github.com/shekhar-jha/base-demo/go-lambda/cmd/db"
)

func SetupWithConfig(ctx context.Context, configuration cfg.Config) db.WithConfiguration[*dynamoDB] {
	var loadOptions []func(options *config.LoadOptions) error
	var setupError []error
	var dbName = "ProtocolTypeUnknown"
	if cfgDBName := cfg.GetValue[string](ctx, configuration, "db.name"); cfgDBName != "" {
		dbName = cfgDBName
	} else {
		setupError = append(setupError, db.ErrDBConfigErr.NewF(db.ErrDBParamName, "not available", db.ErrDBParamConfigParamName, "db.name", common.ErrParamCause, "Missing database name"))
	}
	if dbType := cfg.GetValue[string](ctx, configuration, "db.type"); dbType == "dynamodb" {
		loadOptions = addConfig(ctx, loadOptions, configuration, "db.aws-profile", func(options *config.LoadOptions, value string) error {
			logger.Log("Setting dynamodb SharedConfigProfile to ", value)
			options.SharedConfigProfile = value
			return nil
		})
		loadOptions = addConfig(ctx, loadOptions, configuration, "db.endpoint", func(options *config.LoadOptions, value string) error {
			options.EndpointResolverWithOptions = aws.EndpointResolverWithOptionsFunc(func(service, region string, options ...interface{}) (aws.Endpoint, error) {
				logger.Log("Setting dynamodb endpoint to ", value)
				return aws.Endpoint{
					URL: value,
				}, nil
			})
			return nil
		})
		loadOptions = addConfig(ctx, loadOptions, configuration, "db.region", func(options *config.LoadOptions, value string) error {
			logger.Log("Setting dynamodb region to ", value)
			options.Region = value
			return nil
		})
		loadOptions = addConfig(ctx, loadOptions, configuration, "db.credential", func(options *config.LoadOptions, value string) error {
			if value == "local-mode" {
				logger.Log("Setting dynamodb credentials to dummy since executing in local-mode ")
				options.Credentials = aws.CredentialsProviderFunc(func(ctx context.Context) (aws.Credentials, error) {
					return aws.Credentials{
						AccessKeyID: "dummy", SecretAccessKey: "dummy", SessionToken: "dummy",
						Source: "Hard-coded credentials; values are irrelevant for local DynamoDB",
					}, nil
				})
			}
			return nil
		})
	} else {
		logger.Warn("The configuration type is", dbType, "expected dynamodb")
		setupError = append(setupError, db.ErrDBConfigErr.NewF(db.ErrDBParamName, dbName, db.ErrDBParamConfigParamName, "db.type", common.ErrParamCause, "expected value dynamodb"))
	}
	return func(database *dynamoDB) error {
		if len(setupError) > 0 {
			return errors.Join(setupError...)
		}
		database.name = dbName
		database.dbConfig = configuration
		dbConfig, err := config.LoadDefaultConfig(ctx, loadOptions...)
		if err != nil {
			return db.ErrDBOpsError.NewWithErrorF(err, db.ErrDBParamName, dbName, db.ErrDBParamOps, db.ErrDBParamOpsConfigure, common.ErrParamCause, err)
		}
		database.config = &dbConfig
		return nil
	}
}

func addConfig(ctx context.Context, loadOptions []func(options *config.LoadOptions) error, configuration cfg.Config, key string, appFunction func(options *config.LoadOptions, value string) error) []func(options *config.LoadOptions) error {
	if cfgValue := cfg.GetValue[string](ctx, configuration, key); cfgValue != "" {
		loadOptions = append(loadOptions, func(options *config.LoadOptions) error {
			err := appFunction(options, cfgValue)
			return err
		})
	}
	return loadOptions
}
