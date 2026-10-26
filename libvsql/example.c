/*
 * example.c is examples/simple.v written against the SQL/CLI routines in
 * libvsql. From the folder of a release (which has example.c, libvsql.h in
 * include/ and libvsql.so, or libvsql.dylib on macOS, in lib/), build and run
 * it with:
 *
 *   cc -std=c99 example.c -Iinclude -Llib -lvsql -Wl,-rpath,"$PWD/lib" -o example && ./example
 *
 * It's also valid C++ (compile it with "c++ -x c++" instead). See
 * https://vsql.readthedocs.io/en/latest/language-c.html for Windows.
 *
 * Or, from the root of the repository, run "make libvsql-example".
 */

#include <stdio.h>
#include <stdlib.h>

#include "libvsql.h"

static void check(SQLRETURN rc, SQLSMALLINT type, SQLINTEGER handle) {
  SQLCHAR sqlstate[6];
  SQLCHAR msg[256];

  if (rc == SQL_SUCCESS || rc == SQL_SUCCESS_WITH_INFO) {
    return;
  }

  sqlstate[0] = '\0';
  msg[0] = '\0';
  SQLGetDiagRec(type, handle, 1, sqlstate, NULL, msg, sizeof(msg), NULL);
  fprintf(stderr, "%s: %s\n", (char *)sqlstate, (char *)msg);
  exit(1);
}

int main(void) {
  SQLHENV env;
  SQLHDBC dbc;
  SQLHSTMT stmt;
  SQLDOUBLE x;
  SQLRETURN rc;

  remove("test.vsql");

  check(SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &env), SQL_HANDLE_ENV,
        env);
  check(SQLAllocHandle(SQL_HANDLE_DBC, env, &dbc), SQL_HANDLE_ENV, env);
  check(SQLConnect(dbc, (SQLCHAR *)"test.vsql", SQL_NTS, NULL, 0, NULL, 0),
        SQL_HANDLE_DBC, dbc);
  check(SQLAllocHandle(SQL_HANDLE_STMT, dbc, &stmt), SQL_HANDLE_DBC, dbc);

  /* All SQL commands use SQLExecDirect(): */
  check(SQLExecDirect(stmt, (SQLCHAR *)"CREATE TABLE foo (x DOUBLE PRECISION)",
                      SQL_NTS),
        SQL_HANDLE_STMT, stmt);
  check(SQLExecDirect(stmt, (SQLCHAR *)"INSERT INTO foo (x) VALUES (1.23)",
                      SQL_NTS),
        SQL_HANDLE_STMT, stmt);
  check(SQLExecDirect(stmt, (SQLCHAR *)"INSERT INTO foo (x) VALUES (4.56)",
                      SQL_NTS),
        SQL_HANDLE_STMT, stmt);

  /* Iterate through a result: */
  check(SQLExecDirect(stmt, (SQLCHAR *)"SELECT * FROM foo", SQL_NTS),
        SQL_HANDLE_STMT, stmt);

  while ((rc = SQLFetch(stmt)) == SQL_SUCCESS) {
    check(SQLGetData(stmt, 1, SQL_DOUBLE, &x, 0, NULL), SQL_HANDLE_STMT, stmt);
    printf("%g\n", x);
  }
  if (rc != SQL_NO_DATA) {
    check(rc, SQL_HANDLE_STMT, stmt);
  }

  check(SQLCloseCursor(stmt), SQL_HANDLE_STMT, stmt);
  check(SQLFreeHandle(SQL_HANDLE_STMT, stmt), SQL_HANDLE_STMT, stmt);
  check(SQLDisconnect(dbc), SQL_HANDLE_DBC, dbc);
  check(SQLFreeHandle(SQL_HANDLE_DBC, dbc), SQL_HANDLE_DBC, dbc);
  check(SQLFreeHandle(SQL_HANDLE_ENV, env), SQL_HANDLE_ENV, env);

  return 0;
}
