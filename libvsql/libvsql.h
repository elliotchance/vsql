/*
 * libvsql.h declares the SQL/CLI (ISO/IEC 9075-3) routines implemented by
 * libvsql, the shared library for using vsql from C (and any language that can
 * call C functions). The types and codes are the ones from Annex A, "Typical
 * header files". The routines that aren't implemented yet are listed in
 * https://vsql.readthedocs.io/en/latest/sql-compliance.html#cli-routines
 *
 * This header is C99, and also works with C++11.
 *
 *   Project:   https://github.com/elliotchance/vsql
 *   Releases:  https://github.com/elliotchance/vsql/releases
 *   Docs:      https://vsql.readthedocs.io/en/latest/language-c.html
 *   Issues:    https://github.com/elliotchance/vsql/issues
 *
 * A complete program (error handling is left out, see SQLGetDiagRec):
 *
 *   #include <stdio.h>
 *
 *   #include "libvsql.h"
 *
 *   int main(void) {
 *     SQLHENV env;
 *     SQLHDBC dbc;
 *     SQLHSTMT stmt;
 *     SQLDOUBLE x;
 *
 *     SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &env);
 *     SQLAllocHandle(SQL_HANDLE_DBC, env, &dbc);
 *     SQLConnect(dbc, (SQLCHAR *)":memory:", SQL_NTS, NULL, 0, NULL, 0);
 *     SQLAllocHandle(SQL_HANDLE_STMT, dbc, &stmt);
 *
 *     SQLExecDirect(stmt, (SQLCHAR *)"CREATE TABLE foo (x DOUBLE PRECISION)",
 *                   SQL_NTS);
 *     SQLExecDirect(stmt, (SQLCHAR *)"INSERT INTO foo (x) VALUES (1.23)",
 *                   SQL_NTS);
 *     SQLEndTran(SQL_HANDLE_DBC, dbc, SQL_COMMIT);
 *
 *     SQLExecDirect(stmt, (SQLCHAR *)"SELECT * FROM foo", SQL_NTS);
 *     while (SQLFetch(stmt) == SQL_SUCCESS) {
 *       SQLGetData(stmt, 1, SQL_DOUBLE, &x, 0, NULL);
 *       printf("%g\n", x);
 *     }
 *     SQLCloseCursor(stmt);
 *     SQLEndTran(SQL_HANDLE_DBC, dbc, SQL_COMMIT);
 *
 *     SQLFreeHandle(SQL_HANDLE_STMT, stmt);
 *     SQLDisconnect(dbc);
 *     SQLFreeHandle(SQL_HANDLE_DBC, dbc);
 *     SQLFreeHandle(SQL_HANDLE_ENV, env);
 *
 *     return 0;
 *   }
 *
 * From the folder of a release, build it with (on Windows, use gcc from MinGW,
 * -Lbin instead of -Llib and leave out the -rpath):
 *
 *   cc example.c -Iinclude -Llib -lvsql -Wl,-rpath,"$PWD/lib" -o example
 *
 * Data types
 *
 * Each vsql data type, the DataType from SQLDescribeCol, and the TargetTypes
 * that SQLGetData can retrieve it as:
 *
 *   SMALLINT                 SQL_SMALLINT                     numbers, SQL_CHAR
 *   INTEGER                  SQL_INTEGER                      numbers, SQL_CHAR
 *   BIGINT                   SQL_BIGINT                       numbers, SQL_CHAR
 *   REAL                     SQL_REAL                         numbers, SQL_CHAR
 *   DOUBLE PRECISION, FLOAT  SQL_DOUBLE                       numbers, SQL_CHAR
 *   DECIMAL                  SQL_DECIMAL                      numbers, SQL_CHAR
 *   NUMERIC                  SQL_NUMERIC                      numbers, SQL_CHAR
 *   CHARACTER                SQL_CHAR                         SQL_CHAR
 *   CHARACTER VARYING        SQL_VARCHAR                      SQL_CHAR
 *   BOOLEAN                  SQL_BOOLEAN                      SQL_CHAR
 *   DATE                     SQL_TYPE_DATE                    SQL_CHAR
 *   TIME                     SQL_TYPE_TIME                    SQL_CHAR
 *   TIME WITH TIME ZONE      SQL_TYPE_TIME_WITH_TIMEZONE      SQL_CHAR
 *   TIMESTAMP                SQL_TYPE_TIMESTAMP               SQL_CHAR
 *   TIMESTAMP WITH TIME ZONE SQL_TYPE_TIMESTAMP_WITH_TIMEZONE SQL_CHAR
 *
 * "numbers" is SQL_SMALLINT, SQL_INTEGER, SQL_BIGINT, SQL_REAL or SQL_DOUBLE
 * (a value out of range is 22003). SQL_DEFAULT retrieves a column as its own
 * type, so it only works for the types that have a C type (SMALLINT, INTEGER,
 * BIGINT, REAL, DOUBLE PRECISION and CHARACTER), otherwise it's 07002.
 */

#ifndef LIBVSQL_H
#define LIBVSQL_H

#ifdef __cplusplus
extern "C" {
#endif

typedef unsigned char SQLCHAR;
typedef short SQLSMALLINT;
typedef long SQLINTEGER;
typedef float SQLREAL;
typedef double SQLDOUBLE;
typedef void *SQLPOINTER;

typedef long long SQLBIGINT;

typedef SQLSMALLINT SQLRETURN;

/* Handles are integers that identify an allocated resource. */
typedef SQLINTEGER SQLHENV;
typedef SQLINTEGER SQLHDBC;
typedef SQLINTEGER SQLHSTMT;
typedef SQLINTEGER SQLHDESC;

/* Special length/indicator values. */
#define SQL_NULL_DATA (-1) /* the value is NULL */
#define SQL_NTS       (-3) /* a null terminated string */

/* Return codes. */
#define SQL_SUCCESS           0    /* completed */
#define SQL_SUCCESS_WITH_INFO 1    /* completed with a warning */
#define SQL_NO_DATA           100  /* no more rows or records */
#define SQL_ERROR             (-1) /* failed, see SQLGetDiagRec */
#define SQL_INVALID_HANDLE    (-2) /* not an allocated handle */

/* Handle types. */
#define SQL_HANDLE_ENV  1  /* an environment */
#define SQL_HANDLE_DBC  2  /* a connection */
#define SQL_HANDLE_STMT 3  /* a statement */
#define SQL_HANDLE_DESC 4  /* a descriptor */
#define SQL_NULL_HANDLE 0L /* no handle */

/* Data type codes. */
#define SQL_CHAR     1  /* CHARACTER, or a C string */
#define SQL_NUMERIC  2  /* NUMERIC */
#define SQL_DECIMAL  3  /* DECIMAL */
#define SQL_INTEGER  4  /* INTEGER, or SQLINTEGER */
#define SQL_SMALLINT 5  /* SMALLINT, or SQLSMALLINT */
#define SQL_FLOAT    6  /* FLOAT, see SQL_DOUBLE */
#define SQL_REAL     7  /* REAL, or SQLREAL */
#define SQL_DOUBLE   8  /* DOUBLE PRECISION, SQLDOUBLE */
#define SQL_DATETIME 9  /* any datetime type */
#define SQL_VARCHAR  12 /* CHARACTER VARYING */
#define SQL_BOOLEAN  16 /* BOOLEAN */
#define SQL_BIGINT   25 /* BIGINT, or SQLBIGINT */

/* SQL_DESC_DATETIME_INTERVAL_CODEs of SQL_DATETIME. */
#define SQL_CODE_DATE           1 /* DATE */
#define SQL_CODE_TIME           2 /* TIME */
#define SQL_CODE_TIMESTAMP      3 /* TIMESTAMP */
#define SQL_CODE_TIME_ZONE      4 /* TIME WITH TIME ZONE */
#define SQL_CODE_TIMESTAMP_ZONE 5 /* TIMESTAMP WITH TIME ZONE */

/* Concise codes for datetime data types. */
#define SQL_TYPE_DATE                    91 /* DATE */
#define SQL_TYPE_TIME                    92 /* TIME */
#define SQL_TYPE_TIMESTAMP               93 /* TIMESTAMP */
#define SQL_TYPE_TIME_WITH_TIMEZONE      94 /* TIME WITH TIME ZONE */
#define SQL_TYPE_TIMESTAMP_WITH_TIMEZONE 95 /* TIMESTAMP WITH TIME ZONE */

/* Special TargetType values for SQLGetData. */
#define SQL_ARD_TYPE (-99) /* the type in the ARD */
#define SQL_DEFAULT  99    /* the type of the column */

/* Header fields for SQLGetDiagField. */
#define SQL_DIAG_RETURNCODE               1  /* the return code */
#define SQL_DIAG_NUMBER                   2  /* the number of records */
#define SQL_DIAG_ROW_COUNT                3  /* see SQLRowCount */
#define SQL_DIAG_DYNAMIC_FUNCTION         7  /* the statement executed */
#define SQL_DIAG_DYNAMIC_FUNCTION_CODE    12 /* the code of the statement */
#define SQL_DIAG_MORE                     13 /* always 0 */
#define SQL_DIAG_TRANSACTIONS_COMMITTED   34 /* transactions committed */
#define SQL_DIAG_TRANSACTIONS_ROLLED_BACK 35 /* transactions rolled back */
#define SQL_DIAG_TRANSACTION_ACTIVE       36 /* 1 if one is active */

/* Record fields for SQLGetDiagField. */
#define SQL_DIAG_SQLSTATE                   4       /* the SQLSTATE */
#define SQL_DIAG_NATIVE_CODE                5       /* always 0 */
#define SQL_DIAG_MESSAGE_TEXT               6       /* the message */
#define SQL_DIAG_CLASS_ORIGIN               8       /* who defined the class */
#define SQL_DIAG_SUBCLASS_ORIGIN            9       /* and the subclass */
#define SQL_DIAG_CONNECTION_NAME            10      /* the ServerName */
#define SQL_DIAG_SERVER_NAME                11      /* the ServerName */
#define SQL_DIAG_CONDITION_NUMBER           14      /* the record number */
#define SQL_DIAG_CONSTRAINT_CATALOG         15      /* always "" */
#define SQL_DIAG_CONSTRAINT_SCHEMA          16      /* always "" */
#define SQL_DIAG_CONSTRAINT_NAME            17      /* always "" */
#define SQL_DIAG_CATALOG_NAME               18      /* always "" */
#define SQL_DIAG_SCHEMA_NAME                19      /* always "" */
#define SQL_DIAG_TABLE_NAME                 20      /* always "" */
#define SQL_DIAG_COLUMN_NAME                21      /* always "" */
#define SQL_DIAG_CURSOR_NAME                22      /* always "" */
#define SQL_DIAG_MESSAGE_LENGTH             23      /* in characters */
#define SQL_DIAG_MESSAGE_OCTET_LENGTH       24      /* in octets */
#define SQL_DIAG_CONDITION_IDENTIFIER       25      /* always "" */
#define SQL_DIAG_PARAMETER_NAME             26      /* always "" */
#define SQL_DIAG_ROUTINE_CATALOG            27      /* always "" */
#define SQL_DIAG_ROUTINE_SCHEMA             28      /* always "" */
#define SQL_DIAG_ROUTINE_NAME               29      /* always "" */
#define SQL_DIAG_SPECIFIC_NAME              30      /* always "" */
#define SQL_DIAG_TRIGGER_CATALOG            31      /* always "" */
#define SQL_DIAG_TRIGGER_SCHEMA             32      /* always "" */
#define SQL_DIAG_TRIGGER_NAME               33      /* always "" */
#define SQL_DIAG_PARAMETER_MODE             37      /* always "" */
#define SQL_DIAG_PARAMETER_ORDINAL_POSITION 38      /* always 0 */
#define SQL_DIAG_ROW_NUMBER                 (-1248) /* the row, or 0 */
#define SQL_DIAG_COLUMN_NUMBER              (-1247) /* the column, or 0 */

/* SQL_DIAG_DYNAMIC_FUNCTION_CODEs. The other statements have the codes from
 * ISO/IEC 9075-2: ALTER SEQUENCE (134), COMMIT WORK (11), CREATE SEQUENCE
 * (133), DROP SEQUENCE (135), ROLLBACK WORK (62) and START TRANSACTION (111).
 * EXPLAIN is -1. */
#define SQL_DIAG_UNKNOWN_STATEMENT 0  /* no statement */
#define SQL_DIAG_ALTER_TABLE       4  /* ALTER TABLE */
#define SQL_DIAG_DELETE_WHERE      19 /* DELETE */
#define SQL_DIAG_DROP_SCHEMA       31 /* DROP SCHEMA */
#define SQL_DIAG_DROP_TABLE        32 /* DROP TABLE */
#define SQL_DIAG_INSERT            50 /* INSERT */
#define SQL_DIAG_CREATE_SCHEMA     64 /* CREATE SCHEMA */
#define SQL_DIAG_SET_CATALOG       66 /* SET CATALOG */
#define SQL_DIAG_SET_SCHEMA        74 /* SET SCHEMA */
#define SQL_DIAG_CREATE_TABLE      77 /* CREATE TABLE */
#define SQL_DIAG_UPDATE_WHERE      82 /* UPDATE */
#define SQL_DIAG_SELECT_CURSOR     85 /* a query */

/* Boolean values. */
#define SQL_FALSE 0 /* false */
#define SQL_TRUE  1 /* true */

/* Environment attributes. */
#define SQL_ATTR_OUTPUT_NTS 10001 /* null terminate strings */

/* Connection attributes. */
#define SQL_ATTR_AUTO_IPD       10001 /* always SQL_FALSE */
#define SQL_ATTR_SAVEPOINT_NAME 10027 /* a savepoint for SQLEndTran */

/* SQLEndTran CompletionTypes. */
#define SQL_COMMIT                  0 /* commit */
#define SQL_ROLLBACK                1 /* roll back */
#define SQL_SAVEPOINT_NAME_ROLLBACK 2 /* not supported */
#define SQL_SAVEPOINT_NAME_RELEASE  4 /* not supported */
#define SQL_COMMIT_AND_CHAIN        6 /* commit and start another */
#define SQL_ROLLBACK_AND_CHAIN      7 /* roll back and start another */

/* SQLStartTran AccessModes. */
#define SQL_TRANSACTION_READ_ONLY  0x00000001L /* not supported */
#define SQL_TRANSACTION_READ_WRITE 0x00000002L /* read and write */

/* SQLStartTran IsolationLevels. */
#define SQL_TRANSACTION_READ_UNCOMMITTED 0x00000001L /* READ COMMITTED */
#define SQL_TRANSACTION_READ_COMMITTED   0x00000002L /* READ COMMITTED */
#define SQL_TRANSACTION_REPEATABLE_READ  0x00000004L /* not supported */
#define SQL_TRANSACTION_SERIALIZABLE     0x00000008L /* not supported */

/* SQLFetchScroll FetchOrientations. */
#define SQL_FETCH_NEXT     1 /* the next rowset */
#define SQL_FETCH_FIRST    2 /* the first rowset */
#define SQL_FETCH_LAST     3 /* the last rowset */
#define SQL_FETCH_PRIOR    4 /* the rowset before */
#define SQL_FETCH_ABSOLUTE 5 /* from the first (or last) row */
#define SQL_FETCH_RELATIVE 6 /* from the first row of the rowset */

/* The status of each row of a rowset (SQL_DESC_ARRAY_STATUS_POINTER). */
#define SQL_ROW_SUCCESS           0 /* fetched */
#define SQL_ROW_NO_ROW            3 /* there isn't a row */
#define SQL_ROW_ERROR             5 /* couldn't be fetched */
#define SQL_ROW_SUCCESS_WITH_INFO 6 /* fetched with a warning */

/* Statement attributes. */
#define SQL_ATTR_CURSOR_HOLDABLE     (-3)  /* SQL_HOLDABLE (the default) */
#define SQL_ATTR_CURSOR_SENSITIVITY  (-2)  /* SQL_ASENSITIVE (the default) */
#define SQL_ATTR_CURSOR_SCROLLABLE   (-1)  /* SQL_NONSCROLLABLE (the default) */
#define SQL_ATTR_APP_ROW_DESC        10010 /* the current ARD */
#define SQL_ATTR_APP_PARAM_DESC      10011 /* the current APD */
#define SQL_ATTR_IMP_ROW_DESC        10012 /* the IRD (read only) */
#define SQL_ATTR_IMP_PARAM_DESC      10013 /* the IPD (read only) */
#define SQL_ATTR_METADATA_ID         10014 /* SQL_FALSE (the default) */
#define SQL_ATTR_CURRENT_OF_POSITION 10027 /* the row of the rowset */
#define SQL_ATTR_NEST_DESCRIPTOR     10029 /* SQL_FALSE (the default) */

/* Values of the cursor statement attributes. */
#define SQL_NONSCROLLABLE 0 /* only SQL_FETCH_NEXT */
#define SQL_SCROLLABLE    1 /* any fetch orientation */
#define SQL_ASENSITIVE    0 /* may see changes (but doesn't) */
#define SQL_INSENSITIVE   1 /* doesn't see changes */
#define SQL_SENSITIVE     2 /* not supported */
#define SQL_NONHOLDABLE   0 /* closed by a commit */
#define SQL_HOLDABLE      1 /* stays open after a commit */

/* Descriptor header fields. */
#define SQL_DESC_ARRAY_SIZE             20   /* the number of rows */
#define SQL_DESC_ARRAY_STATUS_POINTER   21   /* SQLINTEGER[] row statuses */
#define SQL_DESC_ROWS_PROCESSED_POINTER 34   /* SQLINTEGER * rows fetched */
#define SQL_DESC_COUNT                  1001 /* the number of records */
#define SQL_DESC_KEY_TYPE               1029 /* always 0 */
#define SQL_DESC_DYNAMIC_FUNCTION       1031 /* the statement */
#define SQL_DESC_DYNAMIC_FUNCTION_CODE  1032 /* the code of the statement */
#define SQL_DESC_TOP_LEVEL_COUNT        1044 /* the number of columns */
#define SQL_DESC_ALLOC_TYPE             1099 /* SQL_DESC_ALLOC_AUTO or USER */

/* Descriptor record fields. */
#define SQL_DESC_DATETIME_INTERVAL_PRECISION  26   /* not used */
#define SQL_DESC_TYPE                         1002 /* the data type */
#define SQL_DESC_LENGTH                       1003 /* in characters */
#define SQL_DESC_OCTET_LENGTH_POINTER         1004 /* SQLINTEGER *length */
#define SQL_DESC_PRECISION                    1005 /* the precision */
#define SQL_DESC_SCALE                        1006 /* the scale */
#define SQL_DESC_DATETIME_INTERVAL_CODE       1007 /* such as SQL_CODE_DATE */
#define SQL_DESC_NULLABLE                     1008 /* SQL_NULLABLE */
#define SQL_DESC_INDICATOR_POINTER            1009 /* SQLINTEGER * indicator */
#define SQL_DESC_DATA_POINTER                 1010 /* the value */
#define SQL_DESC_NAME                         1011 /* the name of the column */
#define SQL_DESC_UNNAMED                      1012 /* always SQL_NAMED */
#define SQL_DESC_OCTET_LENGTH                 1013 /* the length in octets */
#define SQL_DESC_COLLATION_CATALOG            1015 /* always "" */
#define SQL_DESC_COLLATION_SCHEMA             1016 /* always "" */
#define SQL_DESC_COLLATION_NAME               1017 /* always "" */
#define SQL_DESC_CHARACTER_SET_CATALOG        1018 /* the current catalog */
#define SQL_DESC_CHARACTER_SET_SCHEMA         1019 /* "INFORMATION_SCHEMA" */
#define SQL_DESC_CHARACTER_SET_NAME           1020 /* "UTF8" */
#define SQL_DESC_PARAMETER_MODE               1021 /* SQL_PARAM_MODE_IN */
#define SQL_DESC_PARAMETER_ORDINAL_POSITION   1022 /* not used */
#define SQL_DESC_PARAMETER_SPECIFIC_CATALOG   1023 /* not used */
#define SQL_DESC_PARAMETER_SPECIFIC_SCHEMA    1024 /* not used */
#define SQL_DESC_PARAMETER_SPECIFIC_NAME      1025 /* not used */
#define SQL_DESC_UDT_CATALOG                  1026 /* not used */
#define SQL_DESC_UDT_SCHEMA                   1027 /* not used */
#define SQL_DESC_UDT_NAME                     1028 /* not used */
#define SQL_DESC_KEY_MEMBER                   1030 /* always 0 */
#define SQL_DESC_SCOPE_CATALOG                1033 /* not used */
#define SQL_DESC_SCOPE_SCHEMA                 1034 /* not used */
#define SQL_DESC_SCOPE_NAME                   1035 /* not used */
#define SQL_DESC_SPECIFIC_TYPE_CATALOG        1036 /* not used */
#define SQL_DESC_SPECIFIC_TYPE_SCHEMA         1037 /* not used */
#define SQL_DESC_SPECIFIC_TYPE_NAME           1038 /* not used */
#define SQL_DESC_CURRENT_TRANSFORM_GROUP      1039 /* not used */
#define SQL_DESC_CARDINALITY                  1040 /* not used */
#define SQL_DESC_DEGREE                       1041 /* not used */
#define SQL_DESC_LEVEL                        1042 /* always 0 */
#define SQL_DESC_RETURNED_CARDINALITY_POINTER 1043 /* not used */
#define SQL_DESC_USER_DEFINED_TYPE_CODE       1045 /* not used */

/* Other descriptor values. */
#define SQL_DESC_ALLOC_AUTO 1 /* allocated with a statement */
#define SQL_DESC_ALLOC_USER 2 /* allocated with SQLAllocHandle */
#define SQL_NAMED           0 /* the column has a name */
#define SQL_UNNAMED         1 /* the column doesn't have a name */

/* SQLFreeStmt options (and their ODBC names). */
#define SQL_CLOSE_CURSOR      0 /* close the cursor */
#define SQL_FREE_HANDLE       1 /* free the statement */
#define SQL_UNBIND_COLUMNS    2 /* unbind every column */
#define SQL_UNBIND_PARAMETERS 3 /* unbind every parameter */
#define SQL_REALLOCATE        4 /* forget the statement */
#define SQL_CLOSE             0 /* SQL_CLOSE_CURSOR */
#define SQL_DROP              1 /* SQL_FREE_HANDLE */
#define SQL_UNBIND            2 /* SQL_UNBIND_COLUMNS */
#define SQL_RESET_PARAMS      3 /* SQL_UNBIND_PARAMETERS */

/* Nullability. */
#define SQL_NO_NULLS 0 /* the column is never NULL */
#define SQL_NULLABLE 1 /* the column may be NULL */

/*
 * SQLAllocConnect is the same as SQLAllocHandle(SQL_HANDLE_DBC,
 * EnvironmentHandle, ConnectionHandle).
 */
SQLRETURN SQLAllocConnect(
    SQLHENV  EnvironmentHandle,
    SQLHDBC *ConnectionHandle
);

/*
 * SQLAllocEnv is the same as SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE,
 * EnvironmentHandle).
 */
SQLRETURN SQLAllocEnv(
    SQLHENV *EnvironmentHandle
);

/*
 * SQLAllocHandle allocates an environment (SQL_HANDLE_ENV), a connection
 * (SQL_HANDLE_DBC) for an environment, or a statement (SQL_HANDLE_STMT) or
 * descriptor (SQL_HANDLE_DESC, see SQLGetDescField) for an established
 * connection. InputHandle is SQL_NULL_HANDLE for an environment, otherwise
 * it's the environment or connection to allocate it for. Each handle must be
 * freed with SQLFreeHandle.
 *
 *   SQLHENV env;
 *   SQLHDBC dbc;
 *   SQLHSTMT stmt;
 *
 *   SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &env);
 *   SQLAllocHandle(SQL_HANDLE_DBC, env, &dbc);
 *   SQLConnect(dbc, (SQLCHAR *)"test.vsql", SQL_NTS, NULL, 0, NULL, 0);
 *   SQLAllocHandle(SQL_HANDLE_STMT, dbc, &stmt);
 */
SQLRETURN SQLAllocHandle(
    SQLSMALLINT  HandleType,
    SQLINTEGER   InputHandle,
    SQLINTEGER  *OutputHandle
);

/*
 * SQLAllocStmt is the same as SQLAllocHandle(SQL_HANDLE_STMT,
 * ConnectionHandle, StatementHandle).
 */
SQLRETURN SQLAllocStmt(
    SQLHDBC   ConnectionHandle,
    SQLHSTMT *StatementHandle
);

/*
 * SQLBindCol binds a column (starting at 1) so that SQLFetch and
 * SQLFetchScroll set TargetValue (of TargetType, see SQLGetData) and
 * StrLen_or_Ind. With a SQL_DESC_ARRAY_SIZE (in the ARD) greater than 1, they
 * are arrays with an element for each row of the rowset. A null TargetValue
 * unbinds the column. BufferLength must be greater than 0.
 */
SQLRETURN SQLBindCol(
    SQLHSTMT     StatementHandle,
    SQLSMALLINT  ColumnNumber,
    SQLSMALLINT  TargetType,
    SQLPOINTER   TargetValue,
    SQLINTEGER   BufferLength,
    SQLINTEGER  *StrLen_or_Ind
);

/*
 * SQLCancel cancels a routine that's running on the statement. libvsql isn't
 * thread safe, so there's never one running and SQLCancel only clears the
 * diagnostics of the statement.
 */
SQLRETURN SQLCancel(
    SQLHSTMT StatementHandle
);

/*
 * SQLCloseCursor closes the cursor opened by SQLExecDirect so that the
 * statement can be used to execute another statement.
 *
 *   SQLExecDirect(stmt, (SQLCHAR *)"SELECT * FROM foo", SQL_NTS);
 *   SQLFetch(stmt);
 *   SQLCloseCursor(stmt);
 *   SQLExecDirect(stmt, (SQLCHAR *)"DROP TABLE foo", SQL_NTS);
 */
SQLRETURN SQLCloseCursor(
    SQLHSTMT StatementHandle
);

/*
 * SQLColAttribute reads a field of the IRD (see SQLGetDescField) for a column
 * (starting at 1) of the executed statement. A string field (such as
 * SQL_DESC_NAME) is returned in CharacterAttribute (see SQLGetData for
 * SQL_CHAR), and any other field in NumericAttribute. SQL_DESC_TYPE is the
 * same as the DataType of SQLDescribeCol (such as SQL_TYPE_DATE). It returns
 * SQL_NO_DATA for a column after the last one.
 *
 *   SQLINTEGER nullable;
 *
 *   SQLExecDirect(stmt, (SQLCHAR *)"SELECT * FROM foo", SQL_NTS);
 *   SQLColAttribute(stmt, 1, SQL_DESC_NULLABLE, NULL, 0, NULL, &nullable);
 */
SQLRETURN SQLColAttribute(
    SQLHSTMT     StatementHandle,
    SQLSMALLINT  ColumnNumber,
    SQLSMALLINT  FieldIdentifier,
    SQLCHAR     *CharacterAttribute,
    SQLSMALLINT  BufferLength,
    SQLSMALLINT *StringLength,
    SQLINTEGER  *NumericAttribute
);

/*
 * SQLConnect opens a database. ServerName is the path to the database file, or
 * ":memory:" for an in-memory database. An empty ServerName (or a null pointer)
 * connects to a new in-memory database. UserName and Authentication are not
 * used. Each length is in octets, or SQL_NTS for a null terminated string.
 *
 *   SQLConnect(dbc, (SQLCHAR *)"test.vsql", SQL_NTS, NULL, 0, NULL, 0);
 */
SQLRETURN SQLConnect(
    SQLHDBC      ConnectionHandle,
    SQLCHAR     *ServerName,
    SQLSMALLINT  NameLength1,
    SQLCHAR     *UserName,
    SQLSMALLINT  NameLength2,
    SQLCHAR     *Authentication,
    SQLSMALLINT  NameLength3
);

/*
 * SQLCopyDesc replaces the fields and records of TargetDescHandle with those of
 * SourceDescHandle (except for SQL_DESC_ALLOC_TYPE). The target can't be an
 * IRD (HY016, see SQLSetDescRec).
 */
SQLRETURN SQLCopyDesc(
    SQLHDESC SourceDescHandle,
    SQLHDESC TargetDescHandle
);

/*
 * SQLDescribeCol describes a column (starting at 1) of the cursor. The name is
 * null terminated and truncated (SQL_SUCCESS_WITH_INFO) if it's longer than
 * BufferLength - 1. NameLength may be a null pointer, otherwise it's set to the
 * length of the whole name. DataType is one of the data type codes (such as
 * SQL_DOUBLE, or SQL_TYPE_DATE for a DATE). ColumnSize is the maximum length in
 * octets of a string (4 for each character), the number of decimal digits of a
 * number, or the length of a datetime. DecimalDigits is the scale of a DECIMAL
 * or NUMERIC, or the fractional seconds of a datetime. Nullable is SQL_NO_NULLS
 * or SQL_NULLABLE. These are from the IRD, see SQLGetDescField.
 *
 *   SQLCHAR name[128];
 *   SQLSMALLINT type, digits, nullable;
 *   SQLINTEGER size;
 *
 *   SQLExecDirect(stmt, (SQLCHAR *)"SELECT * FROM foo", SQL_NTS);
 *   SQLDescribeCol(stmt, 1, name, sizeof(name), NULL, &type, &size, &digits,
 *                  &nullable);
 */
SQLRETURN SQLDescribeCol(
    SQLHSTMT     StatementHandle,
    SQLSMALLINT  ColumnNumber,
    SQLCHAR     *ColumnName,
    SQLSMALLINT  BufferLength,
    SQLSMALLINT *NameLength,
    SQLSMALLINT *DataType,
    SQLINTEGER  *ColumnSize,
    SQLSMALLINT *DecimalDigits,
    SQLSMALLINT *Nullable
);

/*
 * SQLDisconnect closes the database and frees the statements of the
 * connection. A transaction must be committed or rolled back with SQLEndTran
 * first. The connection can then be freed, or connected again.
 *
 *   SQLDisconnect(dbc);
 *   SQLFreeHandle(SQL_HANDLE_DBC, dbc);
 */
SQLRETURN SQLDisconnect(
    SQLHDBC ConnectionHandle
);

/*
 * SQLEndTran commits (SQL_COMMIT) or rolls back (SQL_ROLLBACK) the
 * transaction of a connection (SQL_HANDLE_DBC), or of every connection of an
 * environment (SQL_HANDLE_ENV). SQL_COMMIT_AND_CHAIN and
 * SQL_ROLLBACK_AND_CHAIN also start a new transaction. A rollback closes every
 * cursor of the connection, but a commit doesn't. There are no savepoints, so
 * SQL_SAVEPOINT_NAME_ROLLBACK and SQL_SAVEPOINT_NAME_RELEASE are 3B001.
 *
 *   SQLExecDirect(stmt, (SQLCHAR *)"INSERT INTO foo (x) VALUES (1.23)",
 *                 SQL_NTS);
 *   SQLEndTran(SQL_HANDLE_DBC, dbc, SQL_COMMIT);
 */
SQLRETURN SQLEndTran(
    SQLSMALLINT HandleType,
    SQLINTEGER  Handle,
    SQLSMALLINT CompletionType
);

/*
 * SQLError reads the next diagnostic record that it hasn't already read for the
 * last routine called with a handle. It uses StatementHandle if it's a
 * statement, otherwise ConnectionHandle if StatementHandle is SQL_NULL_HANDLE,
 * otherwise EnvironmentHandle if ConnectionHandle is SQL_NULL_HANDLE. It
 * returns SQL_NO_DATA (and Sqlstate is "00000") after the last record. The
 * other arguments are the same as SQLGetDiagRec.
 *
 *   SQLCHAR sqlstate[6], msg[256];
 *
 *   while (SQLError(SQL_NULL_HANDLE, SQL_NULL_HANDLE, stmt, sqlstate, NULL,
 *                   msg, sizeof(msg), NULL) == SQL_SUCCESS) {
 *     printf("%s %s\n", sqlstate, msg);
 *   }
 */
SQLRETURN SQLError(
    SQLHENV      EnvironmentHandle,
    SQLHDBC      ConnectionHandle,
    SQLHSTMT     StatementHandle,
    SQLCHAR     *Sqlstate,
    SQLINTEGER  *NativeError,
    SQLCHAR     *MessageText,
    SQLSMALLINT  BufferLength,
    SQLSMALLINT *TextLength
);

/*
 * SQLExecDirect executes an SQL statement. TextLength is the length in octets,
 * or SQL_NTS for a null terminated string. A query opens a cursor that's read
 * with SQLFetch and must be closed with SQLCloseCursor before executing
 * another statement.
 *
 * A transaction is started if there isn't one, and it must be ended with
 * SQLEndTran, so START TRANSACTION, COMMIT and ROLLBACK can't be executed
 * (42000). A "--" comment isn't allowed either (42000).
 *
 *   SQLExecDirect(stmt, (SQLCHAR *)"CREATE TABLE foo (x DOUBLE PRECISION)",
 *                 SQL_NTS);
 *   SQLExecDirect(stmt, (SQLCHAR *)"INSERT INTO foo (x) VALUES (1.23)",
 *                 SQL_NTS);
 */
SQLRETURN SQLExecDirect(
    SQLHSTMT    StatementHandle,
    SQLCHAR    *StatementText,
    SQLINTEGER  TextLength
);

/*
 * SQLFetch moves the cursor to the next row, which is read with SQLGetData (or
 * set in the columns bound with SQLBindCol). It returns SQL_NO_DATA after the
 * last row.
 *
 * With an SQL_DESC_ARRAY_SIZE greater than 1 in the ARD, it fetches a rowset of
 * that many rows into the bound arrays. The SQL_DESC_ROWS_PROCESSED_POINTER of
 * the IRD is set to the number of rows fetched, and its
 * SQL_DESC_ARRAY_STATUS_POINTER (an SQLINTEGER array) to the status of each
 * row, such as SQL_ROW_SUCCESS or SQL_ROW_NO_ROW. A row that can't be fetched
 * (such as a number that's out of range) is SQL_ROW_ERROR and returns
 * SQL_SUCCESS_WITH_INFO (or SQL_ERROR if no rows could be fetched), and its
 * diagnostics have the SQL_DIAG_ROW_NUMBER and SQL_DIAG_COLUMN_NUMBER.
 *
 *   SQLRETURN rc;
 *   SQLDOUBLE x;
 *
 *   SQLExecDirect(stmt, (SQLCHAR *)"SELECT * FROM foo", SQL_NTS);
 *   while ((rc = SQLFetch(stmt)) == SQL_SUCCESS) {
 *     SQLGetData(stmt, 1, SQL_DOUBLE, &x, 0, NULL);
 *   }
 */
SQLRETURN SQLFetch(
    SQLHSTMT StatementHandle
);

/*
 * SQLFetchScroll moves the cursor to a rowset (see SQL_FETCH_NEXT and the
 * others). Anything other than SQL_FETCH_NEXT needs SQL_ATTR_CURSOR_SCROLLABLE
 * to be SQL_SCROLLABLE. It returns SQL_NO_DATA when there's no rowset there.
 */
SQLRETURN SQLFetchScroll(
    SQLHSTMT    StatementHandle,
    SQLSMALLINT FetchOrientation,
    SQLINTEGER  FetchOffset
);

/*
 * SQLFreeConnect is the same as SQLFreeHandle(SQL_HANDLE_DBC,
 * ConnectionHandle).
 */
SQLRETURN SQLFreeConnect(
    SQLHDBC ConnectionHandle
);

/*
 * SQLFreeEnv is the same as SQLFreeHandle(SQL_HANDLE_ENV, EnvironmentHandle).
 */
SQLRETURN SQLFreeEnv(
    SQLHENV EnvironmentHandle
);

/*
 * SQLFreeHandle frees a handle from SQLAllocHandle. A connection must be
 * disconnected first, and an environment can only be freed after its
 * connections. Freeing a statement closes its cursor.
 *
 *   SQLFreeHandle(SQL_HANDLE_STMT, stmt);
 *   SQLDisconnect(dbc);
 *   SQLFreeHandle(SQL_HANDLE_DBC, dbc);
 *   SQLFreeHandle(SQL_HANDLE_ENV, env);
 */
SQLRETURN SQLFreeHandle(
    SQLSMALLINT HandleType,
    SQLINTEGER  Handle
);

/*
 * SQLFreeStmt does one of the following, depending on Option:
 *
 *   SQL_CLOSE_CURSOR       closes the cursor, if there is one
 *   SQL_FREE_HANDLE        the same as SQLFreeHandle(SQL_HANDLE_STMT, ...)
 *   SQL_UNBIND_COLUMNS     unbinds every column
 *   SQL_UNBIND_PARAMETERS  unbinds every parameter
 *   SQL_REALLOCATE         closes the cursor and forgets the statement
 *
 *   SQLFreeStmt(stmt, SQL_CLOSE_CURSOR);
 */
SQLRETURN SQLFreeStmt(
    SQLHSTMT    StatementHandle,
    SQLSMALLINT Option
);

/*
 * SQLGetConnectAttr reads an attribute of a connection:
 *
 *   SQL_ATTR_AUTO_IPD        SQLINTEGER, always SQL_FALSE
 *   SQL_ATTR_SAVEPOINT_NAME  string, see SQLGetData for SQL_CHAR
 *
 * BufferLength and StringLength are only used for a string.
 */
SQLRETURN SQLGetConnectAttr(
    SQLHDBC     ConnectionHandle,
    SQLINTEGER  Attribute,
    SQLPOINTER  Value,
    SQLINTEGER  BufferLength,
    SQLINTEGER *StringLength
);

/*
 * SQLGetData reads a column (starting at 1) of the fetched row, converted to
 * TargetType:
 *
 *   SQL_CHAR      char[BufferLength], null terminated
 *   SQL_SMALLINT  SQLSMALLINT
 *   SQL_INTEGER   SQLINTEGER
 *   SQL_BIGINT    SQLBIGINT
 *   SQL_REAL      SQLREAL
 *   SQL_DOUBLE    SQLDOUBLE
 *   SQL_DEFAULT   the type of the column
 *   SQL_ARD_TYPE  the SQL_DESC_TYPE of the column in the ARD
 *
 * The SQL_DESC_TYPE of the column in the ARD (if it has a record for the
 * column) is set to TargetType. A column that's bound in the ARD can't be read
 * with SQLGetData (07009).
 *
 * BufferLength is only used for SQL_CHAR. StrLen_or_Ind is set to SQL_NULL_DATA
 * for a NULL value (so it can only be a null pointer when the value isn't
 * NULL), otherwise it's set to the length of the string still to be read (or
 * 0 for a number). A string that doesn't fit returns SQL_SUCCESS_WITH_INFO,
 * and calling SQLGetData again for the same column reads the next piece.
 *
 *   char buf[6];
 *   SQLINTEGER ind;
 *
 *   SQLExecDirect(stmt, (SQLCHAR *)"VALUES 'hello world'", SQL_NTS);
 *   SQLFetch(stmt);
 *   SQLGetData(stmt, 1, SQL_CHAR, buf, sizeof(buf), &ind);
 *   SQLGetData(stmt, 1, SQL_CHAR, buf, sizeof(buf), &ind);
 *   SQLGetData(stmt, 1, SQL_CHAR, buf, sizeof(buf), &ind);
 *
 * The first call returns SQL_SUCCESS_WITH_INFO with "hello" (ind is 11), the
 * second returns SQL_SUCCESS_WITH_INFO with " worl" (ind is 6), and the third
 * returns SQL_SUCCESS with "d" (ind is 1).
 */
SQLRETURN SQLGetData(
    SQLHSTMT     StatementHandle,
    SQLSMALLINT  ColumnNumber,
    SQLSMALLINT  TargetType,
    SQLPOINTER   TargetValue,
    SQLINTEGER   BufferLength,
    SQLINTEGER  *StrLen_or_Ind
);

/*
 * SQLGetDescField reads a field of a descriptor. A header field (such as
 * SQL_DESC_COUNT) ignores RecordNumber, and a record field (such as
 * SQL_DESC_TYPE) reads the record numbered from 1. It returns SQL_NO_DATA if
 * there isn't a record with that number.
 *
 * Value is an SQLSMALLINT, an SQLINTEGER, a pointer or a string (see
 * SQLGetData for SQL_CHAR), depending on the field. A field that was never set
 * is HY091, and so is a field that can't be read from that type of descriptor.
 * An IRD can only be read after a statement is executed.
 *
 * Each statement has four descriptors, which are its attributes:
 *
 *   SQL_ATTR_APP_ROW_DESC    the ARD, which binds the columns
 *   SQL_ATTR_APP_PARAM_DESC  the APD, which binds the parameters
 *   SQL_ATTR_IMP_ROW_DESC    the IRD, which describes the columns
 *   SQL_ATTR_IMP_PARAM_DESC  the IPD, which describes the parameters
 *
 *   SQLHDESC ird;
 *   SQLSMALLINT type;
 *
 *   SQLExecDirect(stmt, (SQLCHAR *)"SELECT * FROM foo", SQL_NTS);
 *   SQLGetStmtAttr(stmt, SQL_ATTR_IMP_ROW_DESC, &ird, 0, NULL);
 *   SQLGetDescField(ird, 1, SQL_DESC_TYPE, &type, 0, NULL);
 */
SQLRETURN SQLGetDescField(
    SQLHDESC     DescriptorHandle,
    SQLSMALLINT  RecordNumber,
    SQLSMALLINT  FieldIdentifier,
    SQLPOINTER   Value,
    SQLINTEGER   BufferLength,
    SQLINTEGER  *StringLength
);

/*
 * SQLGetDescRec reads the SQL_DESC_NAME, SQL_DESC_TYPE,
 * SQL_DESC_DATETIME_INTERVAL_CODE (SubType), SQL_DESC_OCTET_LENGTH (Length),
 * SQL_DESC_PRECISION, SQL_DESC_SCALE and SQL_DESC_NULLABLE fields of a record
 * (starting at 1) of a descriptor. Any of them may be a null pointer. It
 * returns SQL_NO_DATA if there isn't a record with that number.
 */
SQLRETURN SQLGetDescRec(
    SQLHDESC     DescriptorHandle,
    SQLSMALLINT  RecordNumber,
    SQLCHAR     *Name,
    SQLSMALLINT  BufferLength,
    SQLSMALLINT *NameLength,
    SQLSMALLINT *Type,
    SQLSMALLINT *SubType,
    SQLINTEGER  *Length,
    SQLSMALLINT *Precision,
    SQLSMALLINT *Scale,
    SQLSMALLINT *Nullable
);

/*
 * SQLGetDiagField reads one field of the diagnostics for the last routine that
 * was called with a handle (other than SQLError, SQLGetDiagField and
 * SQLGetDiagRec). A header field (such as SQL_DIAG_NUMBER, the number of
 * records) ignores RecordNumber, and a record field (such as
 * SQL_DIAG_SQLSTATE) reads the record numbered from 1. It returns SQL_NO_DATA
 * if there isn't a record with that number.
 *
 * DiagInfo is an SQLSMALLINT for SQL_DIAG_RETURNCODE, an SQLINTEGER for the
 * other numbers, or a null terminated string that's truncated to fit in
 * BufferLength. StringLength may be a null pointer, otherwise it's set to the
 * length of the whole string. The fields are:
 *
 *   SQL_DIAG_NUMBER                    the number of records
 *   SQL_DIAG_RETURNCODE                what the routine returned
 *   SQL_DIAG_ROW_COUNT                 see SQLRowCount (only for statements)
 *   SQL_DIAG_DYNAMIC_FUNCTION          such as "INSERT", or "" if the routine
 *                                      didn't execute a statement
 *   SQL_DIAG_DYNAMIC_FUNCTION_CODE     such as SQL_DIAG_INSERT, or 0
 *   SQL_DIAG_TRANSACTIONS_COMMITTED    transactions committed by the routine
 *   SQL_DIAG_TRANSACTIONS_ROLLED_BACK  transactions rolled back by the routine
 *   SQL_DIAG_TRANSACTION_ACTIVE        1 if a transaction is active, or 0
 *   SQL_DIAG_MORE                      always 0
 *
 *   SQL_DIAG_SQLSTATE                  the SQLSTATE
 *   SQL_DIAG_MESSAGE_TEXT              the message
 *   SQL_DIAG_MESSAGE_LENGTH            the length of the message in characters
 *   SQL_DIAG_MESSAGE_OCTET_LENGTH      the length of the message in octets
 *   SQL_DIAG_CLASS_ORIGIN              "ISO 9075" if the class of the SQLSTATE
 *                                      is from the standard, otherwise "vsql"
 *   SQL_DIAG_SUBCLASS_ORIGIN           the same, for the subclass
 *   SQL_DIAG_SERVER_NAME               the ServerName of the connection
 *   SQL_DIAG_CONNECTION_NAME           the same as SQL_DIAG_SERVER_NAME
 *   SQL_DIAG_CONDITION_NUMBER          the record number
 *   SQL_DIAG_COLUMN_NUMBER             the column, or 0
 *   SQL_DIAG_ROW_NUMBER                the row, or 0
 *   SQL_DIAG_NATIVE_CODE               always 0
 *
 * Every other record field is "" (or 0 for
 * SQL_DIAG_PARAMETER_ORDINAL_POSITION).
 *
 *   SQLINTEGER rows;
 *
 *   SQLExecDirect(stmt, (SQLCHAR *)"DELETE FROM foo", SQL_NTS);
 *   SQLGetDiagField(SQL_HANDLE_STMT, stmt, 0, SQL_DIAG_ROW_COUNT, &rows, 0,
 *                   NULL);
 */
SQLRETURN SQLGetDiagField(
    SQLSMALLINT  HandleType,
    SQLINTEGER   Handle,
    SQLSMALLINT  RecordNumber,
    SQLSMALLINT  DiagIdentifier,
    SQLPOINTER   DiagInfo,
    SQLSMALLINT  BufferLength,
    SQLSMALLINT *StringLength
);

/*
 * SQLGetDiagRec reads a diagnostic record (starting at 1) for the last routine
 * that was called with the handle. It returns SQL_NO_DATA when there are no
 * more records. Sqlstate needs room for 6 octets. The message is null
 * terminated and truncated to fit in BufferLength. Sqlstate, NativeError,
 * MessageText and TextLength may each be a null pointer.
 *
 *   SQLCHAR sqlstate[6], msg[256];
 *
 *   if (SQLExecDirect(stmt, (SQLCHAR *)"SELECT * FROM bar", SQL_NTS) ==
 *       SQL_ERROR) {
 *     SQLGetDiagRec(SQL_HANDLE_STMT, stmt, 1, sqlstate, NULL, msg,
 *                   sizeof(msg), NULL);
 *   }
 *
 * sqlstate is "42P01" and msg is "no such table: ...".
 */
SQLRETURN SQLGetDiagRec(
    SQLSMALLINT  HandleType,
    SQLINTEGER   Handle,
    SQLSMALLINT  RecordNumber,
    SQLCHAR     *Sqlstate,
    SQLINTEGER  *NativeError,
    SQLCHAR     *MessageText,
    SQLSMALLINT  BufferLength,
    SQLSMALLINT *TextLength
);

/*
 * SQLGetEnvAttr reads an attribute of an environment. The only one is
 * SQL_ATTR_OUTPUT_NTS (an SQLINTEGER), see SQLSetEnvAttr. BufferLength and
 * StringLength are not used.
 *
 *   SQLINTEGER nts;
 *
 *   SQLGetEnvAttr(env, SQL_ATTR_OUTPUT_NTS, &nts, 0, NULL);
 */
SQLRETURN SQLGetEnvAttr(
    SQLHENV     EnvironmentHandle,
    SQLINTEGER  Attribute,
    SQLPOINTER  Value,
    SQLINTEGER  BufferLength,
    SQLINTEGER *StringLength
);

/*
 * SQLGetStmtAttr reads an attribute of a statement (an SQLINTEGER), such as
 * SQL_ATTR_IMP_ROW_DESC (see SQLGetDescField) or SQL_ATTR_CURSOR_SCROLLABLE.
 * BufferLength and StringLength are not used.
 */
SQLRETURN SQLGetStmtAttr(
    SQLHSTMT    StatementHandle,
    SQLINTEGER  Attribute,
    SQLPOINTER  Value,
    SQLINTEGER  BufferLength,
    SQLINTEGER *StringLength
);

/*
 * SQLNumResultCols sets ColumnCount to the number of columns of the cursor, or
 * 0 for a statement that isn't a query.
 *
 *   SQLSMALLINT columns;
 *
 *   SQLExecDirect(stmt, (SQLCHAR *)"SELECT * FROM foo", SQL_NTS);
 *   SQLNumResultCols(stmt, &columns);
 */
SQLRETURN SQLNumResultCols(
    SQLHSTMT     StatementHandle,
    SQLSMALLINT *ColumnCount
);

/*
 * SQLRowCount sets RowCount to the number of rows inserted, updated or deleted
 * by the last statement that was executed, or 0 for any other statement.
 *
 *   SQLINTEGER rows;
 *
 *   SQLExecDirect(stmt, (SQLCHAR *)"DELETE FROM foo", SQL_NTS);
 *   SQLRowCount(stmt, &rows);
 */
SQLRETURN SQLRowCount(
    SQLHSTMT    StatementHandle,
    SQLINTEGER *RowCount
);

/*
 * SQLSetConnectAttr sets the SQL_ATTR_SAVEPOINT_NAME of a connection (a string
 * of StringLength octets, or SQL_NTS).
 */
SQLRETURN SQLSetConnectAttr(
    SQLHDBC    ConnectionHandle,
    SQLINTEGER Attribute,
    SQLPOINTER Value,
    SQLINTEGER StringLength
);

/*
 * SQLSetDescField sets a field of a descriptor (see SQLGetDescField). A record
 * field adds records up to RecordNumber. An SQLSMALLINT or SQLINTEGER is the
 * Value itself (not a pointer to it), a pointer field is the pointer, and a
 * string is BufferLength octets (or SQL_NTS). Setting SQL_DESC_TYPE resets the
 * length, precision and scale for the type, and SQL_DESC_DATA_POINTER (which
 * must have a C type, otherwise it's HY021). The fields of an IRD can't be set
 * (HY091).
 *
 *   SQLHDESC ard;
 *   SQLDOUBLE x;
 *
 *   SQLGetStmtAttr(stmt, SQL_ATTR_APP_ROW_DESC, &ard, 0, NULL);
 *   SQLSetDescField(ard, 1, SQL_DESC_TYPE, (SQLPOINTER)SQL_DOUBLE, 0);
 *   SQLSetDescField(ard, 1, SQL_DESC_DATA_POINTER, &x, 0);
 */
SQLRETURN SQLSetDescField(
    SQLHDESC    DescriptorHandle,
    SQLSMALLINT RecordNumber,
    SQLSMALLINT FieldIdentifier,
    SQLPOINTER  Value,
    SQLINTEGER  BufferLength
);

/*
 * SQLSetDescRec sets the SQL_DESC_TYPE, SQL_DESC_DATETIME_INTERVAL_CODE
 * (SubType), SQL_DESC_PRECISION, SQL_DESC_SCALE, SQL_DESC_DATA_POINTER (Data),
 * SQL_DESC_OCTET_LENGTH_POINTER (StringLength) and SQL_DESC_INDICATOR_POINTER
 * (Indicator) fields of a record (starting at 1). Length is the
 * SQL_DESC_LENGTH of an IPD, and the SQL_DESC_OCTET_LENGTH of the other
 * descriptors. StringLength and Indicator are only set if they are not null
 * pointers.
 *
 * An IRD can't be changed. The standard names this condition ("cannot modify
 * an implementation row descriptor") but doesn't give it a SQLSTATE, so it's
 * HY016, the same as ODBC.
 */
SQLRETURN SQLSetDescRec(
    SQLHDESC     DescriptorHandle,
    SQLSMALLINT  RecordNumber,
    SQLSMALLINT  Type,
    SQLSMALLINT  SubType,
    SQLINTEGER   Length,
    SQLSMALLINT  Precision,
    SQLSMALLINT  Scale,
    SQLPOINTER   Data,
    SQLINTEGER  *StringLength,
    SQLINTEGER  *Indicator
);

/*
 * SQLSetEnvAttr sets an attribute of an environment, before it has any
 * connections. The only one is SQL_ATTR_OUTPUT_NTS: SQL_TRUE (the default)
 * null terminates every string that's returned, and SQL_FALSE doesn't. Value
 * is the value itself (not a pointer to it), and StringLength isn't used.
 *
 *   SQLSetEnvAttr(env, SQL_ATTR_OUTPUT_NTS, (SQLPOINTER)SQL_FALSE, 0);
 */
SQLRETURN SQLSetEnvAttr(
    SQLHENV    EnvironmentHandle,
    SQLINTEGER Attribute,
    SQLPOINTER Value,
    SQLINTEGER StringLength
);

/*
 * SQLSetStmtAttr sets an attribute of a statement. Value is the value itself
 * (not a pointer to it), and StringLength isn't used. The attributes are:
 *
 *   SQL_ATTR_APP_ROW_DESC         a descriptor from SQLAllocHandle, or the
 *   SQL_ATTR_APP_PARAM_DESC       statement's own one
 *   SQL_ATTR_CURSOR_SCROLLABLE    SQL_NONSCROLLABLE or SQL_SCROLLABLE
 *   SQL_ATTR_CURSOR_SENSITIVITY   SQL_ASENSITIVE or SQL_INSENSITIVE
 *   SQL_ATTR_CURSOR_HOLDABLE      SQL_NONHOLDABLE or SQL_HOLDABLE
 *   SQL_ATTR_METADATA_ID          SQL_FALSE or SQL_TRUE
 *   SQL_ATTR_NEST_DESCRIPTOR      SQL_FALSE or SQL_TRUE
 *   SQL_ATTR_CURRENT_OF_POSITION  the row of the rowset
 *
 * The cursor attributes can't be changed while a cursor is open. Every cursor
 * is a copy of the result, so a SQL_SENSITIVE cursor can't be opened (36001).
 *
 *   SQLSetStmtAttr(stmt, SQL_ATTR_CURSOR_HOLDABLE,
 *                  (SQLPOINTER)SQL_NONHOLDABLE, 0);
 */
SQLRETURN SQLSetStmtAttr(
    SQLHSTMT   StatementHandle,
    SQLINTEGER Attribute,
    SQLPOINTER Value,
    SQLINTEGER StringLength
);

/*
 * SQLStartTran starts a transaction for a connection (SQL_HANDLE_DBC), or each
 * connection of an environment (SQL_HANDLE_ENV). A transaction is also started
 * by SQLExecDirect when there isn't one. vsql transactions are always
 * SQL_TRANSACTION_READ_WRITE (AccessMode) and SQL_TRANSACTION_READ_COMMITTED,
 * so SQL_TRANSACTION_READ_ONLY, SQL_TRANSACTION_REPEATABLE_READ and
 * SQL_TRANSACTION_SERIALIZABLE are HYC00.
 *
 *   SQLStartTran(SQL_HANDLE_DBC, dbc, SQL_TRANSACTION_READ_WRITE,
 *                SQL_TRANSACTION_READ_COMMITTED);
 */
SQLRETURN SQLStartTran(
    SQLSMALLINT HandleType,
    SQLINTEGER  Handle,
    SQLINTEGER  AccessMode,
    SQLINTEGER  IsolationLevel
);

#ifdef __cplusplus
}
#endif

#endif
