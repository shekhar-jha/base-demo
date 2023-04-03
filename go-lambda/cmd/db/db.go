package db

import (
	"context"
	"github.com/grinps/go-utils/errext"
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
)

type DatabaseType[V Database] func() V

type Database interface {
	Open(ctx context.Context) (Database, error)
	Create(ctx context.Context, entityName string, value interface{}) (int, error)
	//	Delete(ctx context.Context, key interface{}) (int, error)
	//	Update(ctx context.Context, value interface{})
	//	Get(ctx context.Context, key interface{})
}

type WithConfiguration[T Database] func(database T) error

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
