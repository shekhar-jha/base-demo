package dynamodb

import (
	"context"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	logger "github.com/grinps/go-utils/base-utils/logs"
	"github.com/grinps/go-utils/errext"
	"github.com/shekhar-jha/base-demo/go-lambda/cmd/cfg"
	"github.com/shekhar-jha/base-demo/go-lambda/cmd/common"
	"github.com/shekhar-jha/base-demo/go-lambda/cmd/db"
	"reflect"
)

type DynamoDB = db.DatabaseType[*dynamoDB]

var DynamoDBGen DynamoDB = func() *dynamoDB {
	return &dynamoDB{}
}

func NewDynamoDBE(ctx context.Context, configurations ...db.WithConfiguration[*dynamoDB]) (*dynamoDB, error) {
	return db.NewDatabaseE[DynamoDB](ctx, DynamoDBGen, configurations...)
}

type dynamoDB struct {
	name       string
	dbConfig   cfg.Config
	config     *aws.Config
	client     *dynamodb.Client
	serializer func(value interface{}) (*dynamodb.PutItemInput, error)
}

func (database *dynamoDB) Open(ctx context.Context) (db.Database, error) {
	if database != nil {
		if database.config != nil && database.name != "" {
			database.client = dynamodb.NewFromConfig(*database.config)
			if database.serializer == nil {
				database.serializer = InputSerializer
			}
		} else {
			return nil, db.ErrDBOpsError.NewF(db.ErrDBParamName, database.name, db.ErrDBParamOps, db.ErrDBParamOpsOpenDB, common.ErrParamCause, "missing name or configuration (database instance not initialized)", errext.NewField("name", database.name), errext.NewField("config", database.config))
		}
	} else {
		return nil, db.ErrDBOpsError.NewF(db.ErrDBParamName, "nilDB", db.ErrDBParamOps, db.ErrDBParamOpsOpenDB, common.ErrParamCause, "database pointer is nil")
	}
	return database, nil
}

func (database *dynamoDB) Create(applicableContext context.Context, entityName string, value interface{}) (int, error) {
	if database != nil && database.client != nil {
		input, serializationErr := database.serializer(value)
		if serializationErr != nil {
			return 0, db.ErrDBItemError.NewWithErrorF(serializationErr, db.ErrDBParamName, database.name, db.ErrDBParamOps, db.ErrDBParamOpsCreate, db.ErrDBParamRec, value, common.ErrParamCause, serializationErr)
		}
		entityKeyName := "db.entities." + entityName
		var entityConfig = cfg.GetValue[map[string]any](applicableContext, database.dbConfig, entityKeyName)
		if entityConfig == nil {
			return 0, db.ErrDBItemError.NewF(db.ErrDBParamName, database.name, db.ErrDBParamOps, db.ErrDBParamOpsCreate, db.ErrDBParamRec, value, common.ErrParamCause, "Missing entity configuration", errext.NewField("entityConfigKey", entityKeyName))
		}
		var tableName string
		var tableKeyName = "tablename"
		if cfgTableName, hasTableName := entityConfig[tableKeyName]; !hasTableName {
			return 0, db.ErrDBItemError.NewF(db.ErrDBParamName, database.name, db.ErrDBParamOps, db.ErrDBParamOpsCreate, db.ErrDBParamRec, value, common.ErrParamCause, "Missing entity configuration parameter", errext.NewField("entityConfig", entityConfig), errext.NewField("entityConfigKey", tableKeyName))
		} else if nameAsString, isString := cfgTableName.(string); isString && nameAsString != "" {
			tableName = nameAsString
		} else {
			return 0, db.ErrDBItemError.NewF(db.ErrDBParamName, database.name, db.ErrDBParamOps, db.ErrDBParamOpsCreate, db.ErrDBParamRec, value, common.ErrParamCause, "Expected entity configuration parameter as string", errext.NewField("entityConfigKey", entityKeyName), errext.NewField("entityConfigValue", cfgTableName), errext.NewField("entityConfigValueType", reflect.TypeOf(cfgTableName)))
		}
		logger.Log("Setting table name", tableName)
		input.TableName = &tableName
		responseItem, err := database.client.PutItem(applicableContext, input)
		logger.Log("Put Item returned", responseItem, "error", err)
		if err != nil {
			return 0, db.ErrDBItemError.NewWithErrorF(err, db.ErrDBParamName, database.name, db.ErrDBParamOps, db.ErrDBParamOpsCreate, db.ErrDBParamRec, value, common.ErrParamCause, err)
		}
	} else {
		return 0, db.ErrDBItemError.NewF(db.ErrDBParamName, "nilDB", db.ErrDBParamOps, db.ErrDBParamOpsCreate, db.ErrDBParamRec, value, common.ErrParamCause, "Database pointer or dynamodb client is nil", "database", database)
	}
	return 0, nil
}

func InputSerializer(value interface{}) (putItemInput *dynamodb.PutItemInput, dbErr error) {
	putItemInput = &dynamodb.PutItemInput{}
	item, err := attributevalue.MarshalMap(value)
	if err != nil {
		dbErr = db.ErrDBItemError.NewWithErrorF(err, db.ErrDBParamOps, db.ErrDBParamOpsMarshal, db.ErrDBParamRec, value, common.ErrParamCause, err)
		return
	}
	logger.Log("Generated item as", item)
	putItemInput.Item = item
	return putItemInput, nil
}
