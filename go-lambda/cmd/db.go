package main

import (
	"context"
	"errors"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	logger "github.com/grinps/go-utils/base-utils/logs"
	"github.com/grinps/go-utils/errext"
	"reflect"
)

var ErrDBConfigErr = errext.NewErrorCodeWithOptions(errext.WithTemplate("error encountered while configuring database", "[dbname]", "using parameter", "[param]", "was", "[error]"))
var ErrDBOpsError = errext.NewErrorCodeWithOptions(errext.WithTemplate("error encountered while performing", "[operation]", "on database", "[dbname]", "was", "[error]"))
var ErrDBItemError = errext.NewErrorCodeWithOptions(errext.WithTemplate("error encountered while performing", "[operation]", "on database", "[dbname]", "with record", "[record]", "was", "[error]"))

const (
	ErrDBParamName            = "dbname"
	ErrDBParamConfigParamName = "param"
	ErrDBParamOps             = "operation"
	ErrDBParamOpsConfigure    = "setup configuration"
	ErrDBParamOpsOpenDB       = "open database"
	ErrDBParamOpsMarshal      = "marshal"
	ErrDBParamOpsCreate       = "createItem"
	ErrDBParamRec             = "record"
	ErrParamCause             = "error"
)

type DatabaseType[V Database] func() V

type Database interface {
	Open(ctx context.Context) (Database, error)
	Create(ctx context.Context, entityName string, value interface{}) (int, error)
	//	Delete(ctx context.Context, key interface{}) (int, error)
	//	Update(ctx context.Context, value interface{})
	//	Get(ctx context.Context, key interface{})
}

type DynamoDB = DatabaseType[*dynamoDB]

var DynamoDBGen DynamoDB = func() *dynamoDB {
	return &dynamoDB{}
}

type WithConfiguration[T Database] func(database T) error

func NewDynamoDBE(ctx context.Context, configurations ...WithConfiguration[*dynamoDB]) (*dynamoDB, error) {
	return NewDatabaseE[DynamoDB](ctx, DynamoDBGen, configurations...)
}

func NewDatabaseE[T DatabaseType[V], V Database](ctx context.Context, dbType T, configurations ...WithConfiguration[V]) (V, error) {
	var returnDatabase V
	var nilDatabase V
	if dbType != nil {
		returnDatabase = dbType()
	}
	for _, configuration := range configurations {
		err := configuration(returnDatabase)
		if err != nil {
			return nilDatabase, err
		}
	}
	openedDB, openErr := returnDatabase.Open(ctx)
	if openErr != nil || openedDB == nil {
		return nilDatabase, openErr
	}
	returnDatabase = openedDB.(V)
	return returnDatabase, nil
}

func SetupWithConfig(ctx context.Context, configuration Config) WithConfiguration[*dynamoDB] {
	var loadOptions []func(options *config.LoadOptions) error
	var setupError []error
	var dbName = "ProtocolTypeUnknown"
	if cfgDBName := GetValue[string](ctx, configuration, "db.name"); cfgDBName != "" {
		dbName = cfgDBName
	} else {
		setupError = append(setupError, ErrDBConfigErr.NewF(ErrDBParamName, "not available", ErrDBParamConfigParamName, "db.name", ErrParamCause, "Missing database name"))
	}
	if dbType := GetValue[string](ctx, configuration, "db.type"); dbType == "dynamodb" {
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
		setupError = append(setupError, ErrDBConfigErr.NewF(ErrDBParamName, dbName, ErrDBParamConfigParamName, "db.type", ErrParamCause, "expected value dynamodb"))
	}
	return func(database *dynamoDB) error {
		if len(setupError) > 0 {
			return errors.Join(setupError...)
		}
		database.name = dbName
		database.dbConfig = configuration
		dbConfig, err := config.LoadDefaultConfig(ctx, loadOptions...)
		if err != nil {
			return ErrDBOpsError.NewWithErrorF(err, ErrDBParamName, dbName, ErrDBParamOps, ErrDBParamOpsConfigure, ErrParamCause, err)
		}
		database.config = &dbConfig
		return nil
	}
}

func addConfig(ctx context.Context, loadOptions []func(options *config.LoadOptions) error, configuration Config, key string, appFunction func(options *config.LoadOptions, value string) error) []func(options *config.LoadOptions) error {
	if cfgValue := GetValue[string](ctx, configuration, key); cfgValue != "" {
		loadOptions = append(loadOptions, func(options *config.LoadOptions) error {
			err := appFunction(options, cfgValue)
			return err
		})
	}
	return loadOptions
}

type dynamoDB struct {
	name       string
	dbConfig   Config
	config     *aws.Config
	client     *dynamodb.Client
	serializer func(value interface{}) (*dynamodb.PutItemInput, error)
}

func (db *dynamoDB) Open(ctx context.Context) (Database, error) {
	if db != nil {
		if db.config != nil && db.name != "" {
			db.client = dynamodb.NewFromConfig(*db.config)
			if db.serializer == nil {
				db.serializer = InputSerializer
			}
		} else {
			return nil, ErrDBOpsError.NewF(ErrDBParamName, db.name, ErrDBParamOps, ErrDBParamOpsOpenDB, ErrParamCause, "Missing name or configuration (database instance not initialized)", errext.NewField("name", db.name), errext.NewField("config", db.config))
		}
	} else {
		return nil, ErrDBOpsError.NewF(ErrDBParamName, "nilDB", ErrDBParamOps, ErrDBParamOpsOpenDB, ErrParamCause, "Database pointer is nil")
	}
	return db, nil
}

func (db *dynamoDB) Create(applicableContext context.Context, entityName string, value interface{}) (int, error) {
	if db != nil && db.client != nil {
		input, serializationErr := db.serializer(value)
		if serializationErr != nil {
			return 0, ErrDBItemError.NewWithErrorF(serializationErr, ErrDBParamName, db.name, ErrDBParamOps, ErrDBParamOpsCreate, ErrDBParamRec, value, ErrParamCause, serializationErr)
		}
		entityKeyName := "db.entities." + entityName
		var entityConfig = GetValue[map[string]any](applicableContext, db.dbConfig, entityKeyName)
		if entityConfig == nil {
			return 0, ErrDBItemError.NewF(ErrDBParamName, db.name, ErrDBParamOps, ErrDBParamOpsCreate, ErrDBParamRec, value, ErrParamCause, "Missing entity configuration", errext.NewField("entityConfigKey", entityKeyName))
		}
		var tableName string
		var tableKeyName = "tablename"
		if cfgTableName, hasTableName := entityConfig[tableKeyName]; !hasTableName {
			return 0, ErrDBItemError.NewF(ErrDBParamName, db.name, ErrDBParamOps, ErrDBParamOpsCreate, ErrDBParamRec, value, ErrParamCause, "Missing entity configuration parameter", errext.NewField("entityConfig", entityConfig), errext.NewField("entityConfigKey", tableKeyName))
		} else if nameAsString, isString := cfgTableName.(string); isString && nameAsString != "" {
			tableName = nameAsString
		} else {
			return 0, ErrDBItemError.NewF(ErrDBParamName, db.name, ErrDBParamOps, ErrDBParamOpsCreate, ErrDBParamRec, value, ErrParamCause, "Expected entity configuration parameter as string", errext.NewField("entityConfigKey", entityKeyName), errext.NewField("entityConfigValue", cfgTableName), errext.NewField("entityConfigValueType", reflect.TypeOf(cfgTableName)))
		}
		logger.Log("Setting table name", tableName)
		input.TableName = &tableName
		responseItem, err := db.client.PutItem(applicableContext, input)
		logger.Log("Put Item returned", responseItem, "error", err)
		if err != nil {
			return 0, ErrDBItemError.NewWithErrorF(err, ErrDBParamName, db.name, ErrDBParamOps, ErrDBParamOpsCreate, ErrDBParamRec, value, ErrParamCause, err)
		}
	} else {
		return 0, ErrDBItemError.NewF(ErrDBParamName, "nilDB", ErrDBParamOps, ErrDBParamOpsCreate, ErrDBParamRec, value, ErrParamCause, "Database pointer or dynamodb client is nil", "db", db)
	}
	return 0, nil
}

func InputSerializer(value interface{}) (putItemInput *dynamodb.PutItemInput, dbErr error) {
	putItemInput = &dynamodb.PutItemInput{}
	item, err := attributevalue.MarshalMap(value)
	if err != nil {
		dbErr = ErrDBItemError.NewWithErrorF(err, ErrDBParamOps, ErrDBParamOpsMarshal, ErrDBParamRec, value, ErrParamCause, err)
		return
	}
	logger.Log("Generated item as", item)
	putItemInput.Item = item
	return putItemInput, nil
}
