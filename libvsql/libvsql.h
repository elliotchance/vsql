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
 *
 *     SQLExecDirect(stmt, (SQLCHAR *)"SELECT * FROM foo", SQL_NTS);
 *     while (SQLFetch(stmt) == SQL_SUCCESS) {
 *       SQLGetData(stmt, 1, SQL_DOUBLE, &x, 0, NULL);
 *       printf("%g\n", x);
 *     }
 *     SQLCloseCursor(stmt);
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
 * BIGINT, REAL, DOUBLE PRECISION, CHARACTER and CHARACTER VARYING), otherwise
 * it's 07006.
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
#define SQL_NULL_DATA                    (-1)  /* the value is NULL */
#define SQL_NTS                          (-3)  /* a null terminated string */

/* Return codes. */
#define SQL_SUCCESS                      0     /* completed */
#define SQL_SUCCESS_WITH_INFO            1     /* completed with a warning */
#define SQL_NO_DATA                      100   /* no more rows or records */
#define SQL_ERROR                        (-1)  /* failed, see SQLGetDiagRec */
#define SQL_INVALID_HANDLE               (-2)  /* not an allocated handle */

/* Handle types. */
#define SQL_HANDLE_ENV                   1     /* an environment */
#define SQL_HANDLE_DBC                   2     /* a connection */
#define SQL_HANDLE_STMT                  3     /* a statement */
#define SQL_HANDLE_DESC                  4     /* a descriptor (unsupported) */
#define SQL_NULL_HANDLE                  0L    /* no handle */

/* Data type codes. */
#define SQL_CHAR                         1     /* CHARACTER, or a C string */
#define SQL_NUMERIC                      2     /* NUMERIC */
#define SQL_DECIMAL                      3     /* DECIMAL */
#define SQL_INTEGER                      4     /* INTEGER, or SQLINTEGER */
#define SQL_SMALLINT                     5     /* SMALLINT, or SQLSMALLINT */
#define SQL_FLOAT                        6     /* FLOAT, see SQL_DOUBLE */
#define SQL_REAL                         7     /* REAL, or SQLREAL */
#define SQL_DOUBLE                       8     /* DOUBLE PRECISION, SQLDOUBLE */
#define SQL_DATETIME                     9     /* any datetime type */
#define SQL_VARCHAR                      12    /* CHARACTER VARYING */
#define SQL_BOOLEAN                      16    /* BOOLEAN */
#define SQL_BIGINT                       25    /* BIGINT, or SQLBIGINT */

/* Concise codes for datetime data types. */
#define SQL_TYPE_DATE                    91    /* DATE */
#define SQL_TYPE_TIME                    92    /* TIME */
#define SQL_TYPE_TIMESTAMP               93    /* TIMESTAMP */
#define SQL_TYPE_TIME_WITH_TIMEZONE      94    /* TIME WITH TIME ZONE */
#define SQL_TYPE_TIMESTAMP_WITH_TIMEZONE 95    /* TIMESTAMP WITH TIME ZONE */

/* Special TargetType values for SQLGetData. */
#define SQL_ARD_TYPE                     (-99) /* same as SQL_DEFAULT */
#define SQL_DEFAULT                      99    /* the type of the column */

/* SQLFreeStmt options (and their ODBC names). */
#define SQL_CLOSE_CURSOR                 0     /* close the cursor */
#define SQL_FREE_HANDLE                  1     /* free the statement */
#define SQL_UNBIND_COLUMNS               2     /* unbind every column */
#define SQL_UNBIND_PARAMETERS            3     /* unbind every parameter */
#define SQL_REALLOCATE                   4     /* forget the statement */
#define SQL_CLOSE                        0     /* SQL_CLOSE_CURSOR */
#define SQL_DROP                         1     /* SQL_FREE_HANDLE */
#define SQL_UNBIND                       2     /* SQL_UNBIND_COLUMNS */
#define SQL_RESET_PARAMS                 3     /* SQL_UNBIND_PARAMETERS */

/* Nullability. */
#define SQL_NO_NULLS                     0     /* the column is never NULL */
#define SQL_NULLABLE                     1     /* the column may be NULL */

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
 * (SQL_HANDLE_DBC) for an environment, or a statement (SQL_HANDLE_STMT) for an
 * established connection. InputHandle is SQL_NULL_HANDLE for an environment,
 * otherwise it's the environment or connection to allocate it for. Each handle
 * must be freed with SQLFreeHandle.
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
 * SQLDescribeCol describes a column (starting at 1) of the cursor. The name is
 * null terminated and truncated (SQL_SUCCESS_WITH_INFO) if it's longer than
 * BufferLength - 1. NameLength may be a null pointer, otherwise it's set to the
 * length of the whole name. DataType is one of the data type codes (such as
 * SQL_DOUBLE, or SQL_TYPE_DATE for a DATE), ColumnSize is the length or
 * precision and DecimalDigits is the scale. Nullable is SQL_NO_NULLS or
 * SQL_NULLABLE.
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
 * connection. A transaction must be committed or rolled back first. The
 * connection can then be freed, or connected again.
 *
 *   SQLDisconnect(dbc);
 *   SQLFreeHandle(SQL_HANDLE_DBC, dbc);
 */
SQLRETURN SQLDisconnect(
    SQLHDBC ConnectionHandle
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
 * SQLFetch moves the cursor to the next row, which is read with SQLGetData. It
 * returns SQL_NO_DATA after the last row.
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

#ifdef __cplusplus
}
#endif

#endif
