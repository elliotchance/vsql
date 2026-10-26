/*
 * test.c contains unit tests for the SQL/CLI routines in libvsql. Build and
 * run them with "make libvsql-test". It uses utest.h
 * (https://github.com/sheredom/utest.h).
 *
 * Each test checks one case, and is named after the Subclause of ISO/IEC
 * 9075-3 for the routine being tested (such as 6_30_get_data_... for 6.30,
 * GetData). A fixture gives each test its own handles:
 *
 *   env  An environment and a connection that isn't connected yet.
 *   db   An environment, a connection to a new in-memory database and a
 *        statement.
 *   row  The same as db, with the row from ROW_SQL fetched.
 */

#include <stdio.h>
#include <string.h>

#include "libvsql.h"

/* utest.h isn't pedantic C99 on Windows (it uses an unnamed struct). */
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpedantic"
#include "utest.h"
#pragma GCC diagnostic pop

/* EXPECT_STATE checks the SQLSTATE of the first diagnostic record. */
#define EXPECT_STATE(type, handle, expected)                                   \
  EXPECT_STREQ(sqlstate(type, handle), expected)

static const char *sqlstate(SQLSMALLINT type, SQLINTEGER handle) {
  static SQLCHAR state[6];

  if (SQLGetDiagRec(type, handle, 1, state, NULL, NULL, 0, NULL) !=
      SQL_SUCCESS) {
    return "";
  }

  return (const char *)state;
}

static SQLRETURN run_sql(SQLHSTMT stmt, const char *sql) {
  return SQLExecDirect(stmt, (SQLCHAR *)sql, SQL_NTS);
}

static SQLRETURN connect_memory(SQLHDBC dbc) {
  return SQLConnect(dbc, (SQLCHAR *)":memory:", SQL_NTS, NULL, 0, NULL, 0);
}

/* The handles are freed even if the test already freed some of them, so the
 * return values are ignored. */
static void free_handles(SQLHENV env, SQLHDBC dbc, SQLHSTMT stmt) {
  if (stmt != SQL_NULL_HANDLE) {
    SQLFreeHandle(SQL_HANDLE_STMT, stmt);
  }
  SQLDisconnect(dbc);
  SQLFreeHandle(SQL_HANDLE_DBC, dbc);
  SQLFreeHandle(SQL_HANDLE_ENV, env);
}

struct env {
  SQLHENV env;
  SQLHDBC dbc;
};

UTEST_F_SETUP(env) {
  ASSERT_EQ(
      SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &utest_fixture->env),
      SQL_SUCCESS);
  ASSERT_EQ(
      SQLAllocHandle(SQL_HANDLE_DBC, utest_fixture->env, &utest_fixture->dbc),
      SQL_SUCCESS);
}

UTEST_F_TEARDOWN(env) {
  (void)utest_result;
  free_handles(utest_fixture->env, utest_fixture->dbc, SQL_NULL_HANDLE);
}

struct db {
  SQLHENV env;
  SQLHDBC dbc;
  SQLHSTMT stmt;
};

UTEST_F_SETUP(db) {
  ASSERT_EQ(
      SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &utest_fixture->env),
      SQL_SUCCESS);
  ASSERT_EQ(
      SQLAllocHandle(SQL_HANDLE_DBC, utest_fixture->env, &utest_fixture->dbc),
      SQL_SUCCESS);
  ASSERT_EQ(connect_memory(utest_fixture->dbc), SQL_SUCCESS);
  ASSERT_EQ(
      SQLAllocHandle(SQL_HANDLE_STMT, utest_fixture->dbc, &utest_fixture->stmt),
      SQL_SUCCESS);
}

UTEST_F_TEARDOWN(db) {
  (void)utest_result;
  free_handles(utest_fixture->env, utest_fixture->dbc, utest_fixture->stmt);
}

/* The columns of ROW_SQL. */
#define COL_NULL 1    /* INT, NULL */
#define COL_VARCHAR 2 /* VARCHAR(20), 'hello world' */
#define COL_DOUBLE 3  /* DOUBLE PRECISION, 4.56 */
#define COL_DATE 4    /* DATE, 2026-10-25 */
#define COL_BIGINT 5  /* BIGINT, 100000 */
#define COL_NUMERIC 6 /* NUMERIC(5, 2), 12.5 */
#define ROW_SQL                                                                \
  "SELECT CAST(NULL AS INT), CAST('hello world' AS VARCHAR(20)), "             \
  "CAST(4.56 AS DOUBLE PRECISION), DATE '2026-10-25', CAST(100000 AS "         \
  "BIGINT), CAST(12.5 AS NUMERIC(5, 2)) FROM (VALUES 1) AS t (x)"

struct row {
  SQLHENV env;
  SQLHDBC dbc;
  SQLHSTMT stmt;
};

UTEST_F_SETUP(row) {
  ASSERT_EQ(
      SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &utest_fixture->env),
      SQL_SUCCESS);
  ASSERT_EQ(
      SQLAllocHandle(SQL_HANDLE_DBC, utest_fixture->env, &utest_fixture->dbc),
      SQL_SUCCESS);
  ASSERT_EQ(connect_memory(utest_fixture->dbc), SQL_SUCCESS);
  ASSERT_EQ(
      SQLAllocHandle(SQL_HANDLE_STMT, utest_fixture->dbc, &utest_fixture->stmt),
      SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, ROW_SQL), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
}

UTEST_F_TEARDOWN(row) {
  (void)utest_result;
  free_handles(utest_fixture->env, utest_fixture->dbc, utest_fixture->stmt);
}

/* 6.1 AllocConnect */

UTEST_F(env, 6_1_alloc_connect) {
  SQLHDBC dbc;

  EXPECT_EQ(SQLAllocConnect(utest_fixture->env, &dbc), SQL_SUCCESS);
  EXPECT_NE(dbc, utest_fixture->dbc);
  EXPECT_EQ(connect_memory(dbc), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(dbc), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeConnect(dbc), SQL_SUCCESS);
}

UTEST_F(env, 6_1_alloc_connect_invalid_handle) {
  SQLHDBC dbc = 123;

  EXPECT_EQ(SQLAllocConnect(utest_fixture->dbc, &dbc), SQL_INVALID_HANDLE);
  EXPECT_EQ(dbc, 0);
}

/* 6.2 AllocEnv */

UTEST(libvsql, 6_2_alloc_env) {
  SQLHENV env;

  EXPECT_EQ(SQLAllocEnv(&env), SQL_SUCCESS);
  EXPECT_NE(env, SQL_NULL_HANDLE);
  EXPECT_EQ(SQLFreeEnv(env), SQL_SUCCESS);
}

UTEST(libvsql, 6_2_alloc_env_null_output_handle) {
  EXPECT_EQ(SQLAllocEnv(NULL), SQL_ERROR);
}

/* 6.3 AllocHandle */

UTEST(libvsql, 6_3_alloc_handle_env) {
  SQLHENV env;

  EXPECT_EQ(SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &env), SQL_SUCCESS);
  EXPECT_NE(env, SQL_NULL_HANDLE);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_ENV, env), SQL_SUCCESS);
}

UTEST_F(env, 6_3_alloc_handle_dbc) {
  SQLHDBC dbc;

  EXPECT_EQ(SQLAllocHandle(SQL_HANDLE_DBC, utest_fixture->env, &dbc),
            SQL_SUCCESS);
  EXPECT_NE(dbc, utest_fixture->env);
  EXPECT_NE(dbc, utest_fixture->dbc);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_DBC, dbc), SQL_SUCCESS);
}

UTEST_F(env, 6_3_alloc_handle_unknown_type) {
  SQLINTEGER h = 123;

  EXPECT_EQ(SQLAllocHandle(7, utest_fixture->env, &h), SQL_INVALID_HANDLE);
  EXPECT_EQ(h, 0);
}

UTEST_F(env, 6_3_alloc_handle_invalid_input_handle) {
  SQLINTEGER h = 123;

  EXPECT_EQ(SQLAllocHandle(SQL_HANDLE_DBC, utest_fixture->env + 1000, &h),
            SQL_INVALID_HANDLE);
  EXPECT_EQ(h, 0);
}

UTEST_F(env, 6_3_alloc_handle_stmt_for_env) {
  SQLINTEGER h = 123;

  EXPECT_EQ(SQLAllocHandle(SQL_HANDLE_STMT, utest_fixture->env, &h),
            SQL_INVALID_HANDLE);
}

UTEST_F(env, 6_3_alloc_handle_null_output_handle) {
  EXPECT_EQ(SQLAllocHandle(SQL_HANDLE_DBC, utest_fixture->env, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_ENV, utest_fixture->env, "HY009");
}

/* A statement needs an established connection. */
UTEST_F(env, 6_3_alloc_handle_stmt_not_connected) {
  SQLINTEGER h = 123;

  EXPECT_EQ(SQLAllocHandle(SQL_HANDLE_STMT, utest_fixture->dbc, &h), SQL_ERROR);
  EXPECT_EQ(h, 0);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "08003");
}

UTEST_F(db, 6_3_alloc_handle_stmt) {
  SQLHSTMT stmt;

  EXPECT_EQ(SQLAllocHandle(SQL_HANDLE_STMT, utest_fixture->dbc, &stmt),
            SQL_SUCCESS);
  EXPECT_NE(stmt, utest_fixture->stmt);
}

/* CLI descriptor areas are not supported yet. */
UTEST_F(db, 6_3_alloc_handle_desc) {
  SQLINTEGER h;

  EXPECT_EQ(SQLAllocHandle(SQL_HANDLE_DESC, utest_fixture->dbc, &h), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HYC00");
}

/* 6.4 AllocStmt */

UTEST_F(db, 6_4_alloc_stmt) {
  SQLHSTMT stmt;

  EXPECT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt), SQL_SUCCESS);
  EXPECT_NE(stmt, utest_fixture->stmt);
  EXPECT_EQ(run_sql(stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeStmt(stmt, SQL_DROP), SQL_SUCCESS);
}

UTEST_F(env, 6_4_alloc_stmt_not_connected) {
  SQLHSTMT stmt = 123;

  EXPECT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt), SQL_ERROR);
  EXPECT_EQ(stmt, 0);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "08003");
}

/* 6.7 Cancel */

/* With nothing to cancel, Cancel only empties the diagnostics area. */
UTEST_F(db, 6_7_cancel) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM bar"), SQL_ERROR);
  EXPECT_EQ(SQLCancel(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_STREQ(sqlstate(SQL_HANDLE_STMT, utest_fixture->stmt), "");
}

/* The cursor stays open. */
UTEST_F(db, 6_7_cancel_open_cursor) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLCancel(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
}

UTEST_F(db, 6_7_cancel_invalid_handle) {
  EXPECT_EQ(SQLCancel(utest_fixture->dbc), SQL_INVALID_HANDLE);
}

/* 6.8 CloseCursor */

UTEST_F(db, 6_8_close_cursor) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
}

UTEST_F(db, 6_8_close_cursor_no_statement) {
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

UTEST_F(db, 6_8_close_cursor_not_a_query) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

UTEST_F(db, 6_8_close_cursor_already_closed) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

UTEST_F(db, 6_8_close_cursor_then_fetch) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

UTEST_F(db, 6_8_close_cursor_invalid_handle) {
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt + 1000), SQL_INVALID_HANDLE);
}

/* 6.12 Connect */

UTEST_F(env, 6_12_connect_invalid_handle) {
  EXPECT_EQ(SQLConnect(utest_fixture->env, NULL, 0, NULL, 0, NULL, 0),
            SQL_INVALID_HANDLE);
}

UTEST_F(env, 6_12_connect_negative_length) {
  EXPECT_EQ(SQLConnect(utest_fixture->dbc, (SQLCHAR *)":memory:", -5, NULL, 0,
                       NULL, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY090");
}

UTEST_F(env, 6_12_connect_name_too_long) {
  char long_name[200];

  memset(long_name, 'a', sizeof(long_name));
  EXPECT_EQ(SQLConnect(utest_fixture->dbc, (SQLCHAR *)long_name,
                       sizeof(long_name), NULL, 0, NULL, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY090");
}

/* The DEFAULT server can't have a user name. */
UTEST_F(env, 6_12_connect_default_with_user_name) {
  EXPECT_EQ(SQLConnect(utest_fixture->dbc, NULL, 0, (SQLCHAR *)"bob", SQL_NTS,
                       NULL, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY090");
}

/* A length is used instead of the null terminator. */
UTEST_F(env, 6_12_connect_length) {
  EXPECT_EQ(SQLConnect(utest_fixture->dbc, (SQLCHAR *)":memory:xyz", 8, NULL, 0,
                       NULL, 0),
            SQL_SUCCESS);
}

UTEST_F(env, 6_12_connect_already_connected) {
  EXPECT_EQ(connect_memory(utest_fixture->dbc), SQL_SUCCESS);
  EXPECT_EQ(connect_memory(utest_fixture->dbc), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "08002");
}

/* There can only be one DEFAULT connection in an environment. */
UTEST_F(env, 6_12_connect_second_default) {
  SQLHDBC dbc2;

  EXPECT_EQ(SQLAllocHandle(SQL_HANDLE_DBC, utest_fixture->env, &dbc2),
            SQL_SUCCESS);
  EXPECT_EQ(SQLConnect(utest_fixture->dbc, NULL, 0, NULL, 0, NULL, 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLConnect(dbc2, (SQLCHAR *)"", SQL_NTS, NULL, 0, NULL, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, dbc2, "08002");
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_DBC, dbc2), SQL_SUCCESS);
}

/* 6.15 DescribeCol */

#define DESCRIBE_SQL                                                           \
  "CREATE TABLE t (a INT NOT NULL, bb VARCHAR(20), c NUMERIC(10, 2), d DATE, " \
  "e DOUBLE PRECISION)"

struct column {
  SQLCHAR name[32];
  SQLSMALLINT name_length, type, digits, nullable;
  SQLINTEGER size;
};

static SQLRETURN describe(SQLHSTMT stmt, SQLSMALLINT n, struct column *col) {
  return SQLDescribeCol(stmt, n, col->name, sizeof(col->name),
                        &col->name_length, &col->type, &col->size, &col->digits,
                        &col->nullable);
}

static SQLRETURN select_describe_table(SQLHSTMT stmt) {
  SQLRETURN rc = run_sql(stmt, DESCRIBE_SQL);

  return rc == SQL_SUCCESS ? run_sql(stmt, "SELECT * FROM t") : rc;
}

UTEST_F(db, 6_15_describe_col_no_statement) {
  struct column col;

  EXPECT_EQ(describe(utest_fixture->stmt, 1, &col), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

UTEST_F(db, 6_15_describe_col_not_a_query) {
  struct column col;

  ASSERT_EQ(run_sql(utest_fixture->stmt, DESCRIBE_SQL), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 1, &col), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07005");
}

UTEST_F(db, 6_15_describe_col_integer) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 1, &col), SQL_SUCCESS);
  EXPECT_STREQ((char *)col.name, "A");
  EXPECT_EQ(col.name_length, 1);
  EXPECT_EQ(col.type, SQL_INTEGER);
  EXPECT_EQ(col.size, 10);
  EXPECT_EQ(col.digits, 0);
  EXPECT_EQ(col.nullable, SQL_NO_NULLS);
}

UTEST_F(db, 6_15_describe_col_varchar) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 2, &col), SQL_SUCCESS);
  EXPECT_STREQ((char *)col.name, "BB");
  EXPECT_EQ(col.type, SQL_VARCHAR);
  EXPECT_EQ(col.size, 20);
  EXPECT_EQ(col.nullable, SQL_NULLABLE);
}

UTEST_F(db, 6_15_describe_col_numeric) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 3, &col), SQL_SUCCESS);
  EXPECT_EQ(col.type, SQL_NUMERIC);
  EXPECT_EQ(col.size, 10);
  EXPECT_EQ(col.digits, 2);
}

UTEST_F(db, 6_15_describe_col_date) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 4, &col), SQL_SUCCESS);
  EXPECT_EQ(col.type, SQL_TYPE_DATE);
  EXPECT_EQ(col.size, 10);
}

UTEST_F(db, 6_15_describe_col_double) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 5, &col), SQL_SUCCESS);
  EXPECT_EQ(col.type, SQL_DOUBLE);
}

UTEST_F(db, 6_15_describe_col_null_name_length) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLDescribeCol(utest_fixture->stmt, 2, col.name, sizeof(col.name),
                           NULL, &col.type, &col.size, &col.digits,
                           &col.nullable),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)col.name, "BB");
}

/* A name that doesn't fit is truncated with a warning. */
UTEST_F(db, 6_15_describe_col_truncated_name) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLDescribeCol(utest_fixture->stmt, 2, col.name, 2,
                           &col.name_length, &col.type, &col.size, &col.digits,
                           &col.nullable),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_STREQ((char *)col.name, "B");
  EXPECT_EQ(col.name_length, 2);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "01004");
}

UTEST_F(db, 6_15_describe_col_zero_buffer_length) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLDescribeCol(utest_fixture->stmt, 1, col.name, 0,
                           &col.name_length, &col.type, &col.size, &col.digits,
                           &col.nullable),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY090");
}

UTEST_F(db, 6_15_describe_col_column_zero) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 0, &col), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07009");
}

UTEST_F(db, 6_15_describe_col_column_after_last) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 6, &col), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07009");
}

/* Only the NameLength may be a null pointer. */
UTEST_F(db, 6_15_describe_col_null_data_type) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLDescribeCol(utest_fixture->stmt, 1, col.name, sizeof(col.name),
                           NULL, NULL, &col.size, &col.digits, &col.nullable),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
}

/* 6.16 Disconnect */

/* An active transaction must be finished first. */
UTEST_F(db, 6_16_disconnect_active_transaction) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "START TRANSACTION"), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "25001");
  EXPECT_EQ(run_sql(utest_fixture->stmt, "ROLLBACK"), SQL_SUCCESS);
}

UTEST_F(db, 6_16_disconnect_frees_statements) {
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_INVALID_HANDLE);
}

UTEST_F(db, 6_16_disconnect_not_connected) {
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "08003");
}

/* A file database can be opened again after it's disconnected. */
UTEST_F(env, 6_16_disconnect_reopen_file) {
  SQLHSTMT stmt;
  SQLDOUBLE x;

  remove("libvsql_test.vsql");
  ASSERT_EQ(SQLConnect(utest_fixture->dbc, (SQLCHAR *)"libvsql_test.vsql",
                       SQL_NTS, NULL, 0, NULL, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_STMT, utest_fixture->dbc, &stmt),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt, "CREATE TABLE t (x DOUBLE PRECISION)"), SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt, "INSERT INTO t (x) VALUES (1.5)"), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);

  ASSERT_EQ(SQLConnect(utest_fixture->dbc, (SQLCHAR *)"libvsql_test.vsql",
                       SQL_NTS, NULL, 0, NULL, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_STMT, utest_fixture->dbc, &stmt),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt, "SELECT * FROM t"), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(stmt, 1, SQL_DOUBLE, &x, 0, NULL), SQL_SUCCESS);
  EXPECT_EQ(x, 1.5);
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);

  remove("libvsql_test.vsql");
}

/* 6.18 Error */

UTEST_F(db, 6_18_error_statement) {
  SQLCHAR state[6], msg[100];
  SQLINTEGER native = 123;
  SQLSMALLINT len;

  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM bar"), SQL_ERROR);
  EXPECT_EQ(SQLError(SQL_NULL_HANDLE, SQL_NULL_HANDLE, utest_fixture->stmt,
                     state, &native, msg, sizeof(msg), &len),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)state, "42P01");
  EXPECT_EQ(native, 0);
  EXPECT_EQ(len, (SQLSMALLINT)strlen((char *)msg));
}

/* Each record is only returned once. */
UTEST_F(db, 6_18_error_no_more_records) {
  SQLCHAR state[6];

  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM bar"), SQL_ERROR);
  EXPECT_EQ(SQLError(SQL_NULL_HANDLE, SQL_NULL_HANDLE, utest_fixture->stmt,
                     state, NULL, NULL, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(SQLError(SQL_NULL_HANDLE, SQL_NULL_HANDLE, utest_fixture->stmt,
                     state, NULL, NULL, 0, NULL),
            SQL_NO_DATA);
  EXPECT_STREQ((char *)state, "00000");
}

/* Error doesn't change the diagnostics area, so GetDiagRec can still read the
 * records. */
UTEST_F(db, 6_18_error_then_get_diag_rec) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM bar"), SQL_ERROR);
  EXPECT_EQ(SQLError(SQL_NULL_HANDLE, SQL_NULL_HANDLE, utest_fixture->stmt,
                     NULL, NULL, NULL, 0, NULL),
            SQL_SUCCESS);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "42P01");
}

/* The records of the next routine can be read again. */
UTEST_F(db, 6_18_error_next_routine) {
  SQLCHAR state[6];

  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM bar"), SQL_ERROR);
  EXPECT_EQ(SQLError(SQL_NULL_HANDLE, SQL_NULL_HANDLE, utest_fixture->stmt,
                     state, NULL, NULL, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, ""), SQL_ERROR);
  EXPECT_EQ(SQLError(SQL_NULL_HANDLE, SQL_NULL_HANDLE, utest_fixture->stmt,
                     state, NULL, NULL, 0, NULL),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)state, "HY090");
}

UTEST_F(db, 6_18_error_no_records) {
  SQLCHAR state[6];

  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLError(SQL_NULL_HANDLE, SQL_NULL_HANDLE, utest_fixture->stmt,
                     state, NULL, NULL, 0, NULL),
            SQL_NO_DATA);
  EXPECT_STREQ((char *)state, "00000");
}

/* The connection is used when there's no statement. */
UTEST_F(db, 6_18_error_connection) {
  SQLCHAR state[6];

  EXPECT_EQ(connect_memory(utest_fixture->dbc), SQL_ERROR);
  EXPECT_EQ(SQLError(utest_fixture->env, utest_fixture->dbc, SQL_NULL_HANDLE,
                     state, NULL, NULL, 0, NULL),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)state, "08002");
}

/* The environment is used when there's no connection. */
UTEST_F(db, 6_18_error_environment) {
  SQLCHAR state[6];

  EXPECT_EQ(SQLFreeEnv(utest_fixture->env), SQL_ERROR);
  EXPECT_EQ(SQLError(utest_fixture->env, SQL_NULL_HANDLE, SQL_NULL_HANDLE,
                     state, NULL, NULL, 0, NULL),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)state, "HY010");
}

UTEST_F(db, 6_18_error_invalid_handle) {
  EXPECT_EQ(SQLError(SQL_NULL_HANDLE, SQL_NULL_HANDLE, utest_fixture->dbc, NULL,
                     NULL, NULL, 0, NULL),
            SQL_INVALID_HANDLE);
  EXPECT_EQ(SQLError(SQL_NULL_HANDLE, SQL_NULL_HANDLE, SQL_NULL_HANDLE, NULL,
                     NULL, NULL, 0, NULL),
            SQL_INVALID_HANDLE);
}

/* A record that can't be read isn't marked as read. */
UTEST_F(db, 6_18_error_zero_buffer_length) {
  SQLCHAR state[6], msg[100];

  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM bar"), SQL_ERROR);
  EXPECT_EQ(SQLError(SQL_NULL_HANDLE, SQL_NULL_HANDLE, utest_fixture->stmt,
                     state, NULL, msg, 0, NULL),
            SQL_ERROR);
  EXPECT_EQ(SQLError(SQL_NULL_HANDLE, SQL_NULL_HANDLE, utest_fixture->stmt,
                     state, NULL, msg, sizeof(msg), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)state, "42P01");
}

/* 6.19 ExecDirect */

UTEST_F(db, 6_19_exec_direct_error) {
  SQLCHAR msg[64];
  SQLSMALLINT msg_length;

  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM missing"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "42P01");
  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_STMT, utest_fixture->stmt, 1, NULL, NULL,
                          msg, sizeof(msg), &msg_length),
            SQL_SUCCESS);
  EXPECT_TRUE(strstr((char *)msg, "MISSING") != NULL);
}

UTEST_F(db, 6_19_exec_direct_empty) {
  EXPECT_EQ(SQLExecDirect(utest_fixture->stmt, (SQLCHAR *)"", SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY090");
}

UTEST_F(db, 6_19_exec_direct_negative_length) {
  EXPECT_EQ(SQLExecDirect(utest_fixture->stmt, (SQLCHAR *)"VALUES 1", -10),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY090");
}

UTEST_F(db, 6_19_exec_direct_null_text) {
  EXPECT_EQ(SQLExecDirect(utest_fixture->stmt, NULL, SQL_NTS), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
}

/* A length is used instead of the null terminator. */
UTEST_F(db, 6_19_exec_direct_length) {
  EXPECT_EQ(SQLExecDirect(utest_fixture->stmt,
                          (SQLCHAR *)"CREATE TABLE t (x INT)garbage", 22),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM t"), SQL_SUCCESS);
}

UTEST_F(db, 6_19_exec_direct_open_cursor) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

/* 6.21 Fetch */

UTEST_F(db, 6_21_fetch) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1, 2"), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_NO_DATA);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_NO_DATA);
}

UTEST_F(db, 6_21_fetch_no_statement) {
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

UTEST_F(db, 6_21_fetch_not_a_query) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

/* 6.24 FreeConnect */

UTEST(libvsql, 6_24_free_connect) {
  SQLHENV env;
  SQLHDBC dbc;

  ASSERT_EQ(SQLAllocEnv(&env), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocConnect(env, &dbc), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeConnect(dbc), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeConnect(dbc), SQL_INVALID_HANDLE);
  EXPECT_EQ(SQLFreeEnv(env), SQL_SUCCESS);
}

UTEST_F(db, 6_24_free_connect_connected) {
  EXPECT_EQ(SQLFreeConnect(utest_fixture->dbc), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY010");
}

/* 6.25 FreeEnv */

UTEST(libvsql, 6_25_free_env) {
  SQLHENV env;

  ASSERT_EQ(SQLAllocEnv(&env), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeEnv(env), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeEnv(env), SQL_INVALID_HANDLE);
}

UTEST_F(env, 6_25_free_env_with_connections) {
  EXPECT_EQ(SQLFreeEnv(utest_fixture->env), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_ENV, utest_fixture->env, "HY010");
}

/* 6.26 FreeHandle */

UTEST_F(db, 6_26_free_handle_unknown_type) {
  EXPECT_EQ(SQLFreeHandle(7, utest_fixture->env), SQL_INVALID_HANDLE);
}

UTEST_F(db, 6_26_free_handle_wrong_type) {
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_DBC, utest_fixture->env),
            SQL_INVALID_HANDLE);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_DESC, utest_fixture->stmt),
            SQL_INVALID_HANDLE);
}

/* An environment with connections can't be freed. */
UTEST_F(db, 6_26_free_handle_env_with_connections) {
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_ENV, utest_fixture->env), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_ENV, utest_fixture->env, "HY010");
}

/* An established connection can't be freed. */
UTEST_F(db, 6_26_free_handle_connected) {
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_DBC, utest_fixture->dbc), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY010");
}

/* A statement with an open cursor can be freed. */
UTEST_F(db, 6_26_free_handle_open_cursor) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_STMT, utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_STMT, utest_fixture->stmt),
            SQL_INVALID_HANDLE);
}

UTEST(libvsql, 6_26_free_handle_env_twice) {
  SQLHENV env;

  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &env), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_ENV, env), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_ENV, env), SQL_INVALID_HANDLE);
}

/* 6.27 FreeStmt */

UTEST_F(db, 6_27_free_stmt_close_cursor) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_CLOSE_CURSOR), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 2"), SQL_SUCCESS);
}

/* Unlike CloseCursor, there doesn't need to be an open cursor. */
UTEST_F(db, 6_27_free_stmt_close_no_cursor) {
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_CLOSE), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_CLOSE), SQL_SUCCESS);
}

UTEST_F(db, 6_27_free_stmt_free_handle) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_FREE_HANDLE), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_CLOSE), SQL_INVALID_HANDLE);
}

UTEST_F(db, 6_27_free_stmt_unbind) {
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_UNBIND_COLUMNS), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_UNBIND_PARAMETERS),
            SQL_SUCCESS);
}

/* REALLOCATE forgets the executed statement. */
UTEST_F(db, 6_27_free_stmt_reallocate) {
  SQLINTEGER rows;

  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_REALLOCATE), SQL_SUCCESS);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 2"), SQL_SUCCESS);
}

UTEST_F(db, 6_27_free_stmt_invalid_option) {
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, 5), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY092");
}

UTEST_F(db, 6_27_free_stmt_invalid_handle) {
  EXPECT_EQ(SQLFreeStmt(utest_fixture->dbc, SQL_CLOSE), SQL_INVALID_HANDLE);
}

/* 6.30 GetData */

UTEST_F(db, 6_30_get_data_not_fetched) {
  SQLINTEGER i, ind;

  ASSERT_EQ(run_sql(utest_fixture->stmt, ROW_SQL), SQL_SUCCESS);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_BIGINT, SQL_INTEGER, &i, 0, &ind),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

UTEST_F(row, 6_30_get_data_null) {
  SQLINTEGER i, ind;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_NULL, SQL_INTEGER, &i, 0, &ind),
            SQL_SUCCESS);
  EXPECT_EQ(ind, SQL_NULL_DATA);
}

UTEST_F(row, 6_30_get_data_null_needs_indicator) {
  SQLINTEGER i;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_NULL, SQL_INTEGER, &i, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "22002");
}

/* A character value that doesn't fit is retrieved in pieces. */
UTEST_F(row, 6_30_get_data_pieces) {
  char buf[6];
  SQLINTEGER ind;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_CHAR, buf,
                       sizeof(buf), &ind),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "01004");
  EXPECT_STREQ(buf, "hello");
  EXPECT_EQ(ind, 11);

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_CHAR, buf,
                       sizeof(buf), &ind),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_STREQ(buf, " worl");
  EXPECT_EQ(ind, 6);

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_CHAR, buf,
                       sizeof(buf), &ind),
            SQL_SUCCESS);
  EXPECT_STREQ(buf, "d");
  EXPECT_EQ(ind, 1);
}

/* After the last piece, it starts again. */
UTEST_F(row, 6_30_get_data_pieces_again) {
  char buf[16];
  SQLINTEGER ind;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_CHAR, buf,
                       sizeof(buf), &ind),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_CHAR, buf,
                       sizeof(buf), &ind),
            SQL_SUCCESS);
  EXPECT_STREQ(buf, "hello world");
}

/* Only a character value can be retrieved in pieces. */
UTEST_F(row, 6_30_get_data_pieces_as_integer) {
  char buf[6];
  SQLINTEGER i, ind;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_CHAR, buf,
                       sizeof(buf), &ind),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_INTEGER, &i, 0, &ind),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07009");
}

UTEST_F(row, 6_30_get_data_zero_buffer_length) {
  char buf[6];
  SQLINTEGER ind;

  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_CHAR, buf, 0, &ind),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY090");
}

UTEST_F(row, 6_30_get_data_double) {
  SQLDOUBLE d;
  SQLINTEGER ind;

  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_DOUBLE, SQL_DOUBLE, &d, 0, &ind),
      SQL_SUCCESS);
  EXPECT_EQ(d, 4.56);
  EXPECT_EQ(ind, 0);
}

UTEST_F(row, 6_30_get_data_default) {
  SQLDOUBLE d;

  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_DOUBLE, SQL_DEFAULT, &d, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(d, 4.56);
}

UTEST_F(row, 6_30_get_data_real) {
  SQLREAL r;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_DOUBLE, SQL_REAL, &r, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(r, (SQLREAL)4.56);
}

UTEST_F(row, 6_30_get_data_double_as_char) {
  char big[32];

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_DOUBLE, SQL_CHAR, big,
                       sizeof(big), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ(big, "4.56e0");
}

UTEST_F(row, 6_30_get_data_bigint_as_integer) {
  SQLINTEGER i;

  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_BIGINT, SQL_INTEGER, &i, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(i, 100000);
}

UTEST_F(row, 6_30_get_data_out_of_range) {
  SQLSMALLINT s;

  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_BIGINT, SQL_SMALLINT, &s, 0, NULL),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "22003");
}

UTEST_F(row, 6_30_get_data_numeric_as_double) {
  SQLDOUBLE d;

  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_NUMERIC, SQL_DOUBLE, &d, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(d, 12.5);
}

/* A DATE can only be retrieved as a string. */
UTEST_F(row, 6_30_get_data_date) {
  char big[32];
  SQLINTEGER ind;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_DATE, SQL_CHAR, big,
                       sizeof(big), &ind),
            SQL_SUCCESS);
  EXPECT_STREQ(big, "2026-10-25");
  EXPECT_EQ(ind, 10);
}

UTEST_F(row, 6_30_get_data_date_as_integer) {
  SQLINTEGER i;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_DATE, SQL_INTEGER, &i, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07006");
}

UTEST_F(row, 6_30_get_data_date_as_default) {
  SQLINTEGER i;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_DATE, SQL_DEFAULT, &i, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07006");
}

/* NUMERIC has no C data type. */
UTEST_F(row, 6_30_get_data_as_numeric) {
  SQLDOUBLE d;

  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_NUMERIC, SQL_NUMERIC, &d, 0, NULL),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY003");
}

UTEST_F(row, 6_30_get_data_column_after_last) {
  SQLINTEGER i;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 7, SQL_INTEGER, &i, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07009");
}

UTEST_F(row, 6_30_get_data_null_target) {
  SQLINTEGER ind;

  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_BIGINT, SQL_INTEGER, NULL, 0, &ind),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
}

/* There's no row after the last row. */
UTEST_F(row, 6_30_get_data_after_last_row) {
  SQLINTEGER i, ind;

  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_NO_DATA);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_BIGINT, SQL_INTEGER, &i, 0, &ind),
      SQL_NO_DATA);
}

/* 6.34 GetDiagRec */

/* There are no diagnostics after a success. */
UTEST_F(db, 6_34_get_diag_rec_no_diagnostics) {
  SQLCHAR state[6];

  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_STMT, utest_fixture->stmt, 1, state, NULL,
                          NULL, 0, NULL),
            SQL_NO_DATA);
}

UTEST_F(db, 6_34_get_diag_rec_invalid_handle) {
  SQLCHAR state[6];

  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_STMT, utest_fixture->stmt + 1000, 1, state,
                          NULL, NULL, 0, NULL),
            SQL_INVALID_HANDLE);
  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_DBC, utest_fixture->stmt, 1, state, NULL,
                          NULL, 0, NULL),
            SQL_INVALID_HANDLE);
  EXPECT_EQ(
      SQLGetDiagRec(7, utest_fixture->stmt, 1, state, NULL, NULL, 0, NULL),
      SQL_INVALID_HANDLE);
}

UTEST_F(db, 6_34_get_diag_rec) {
  SQLCHAR state[6], msg[8];
  SQLINTEGER native = 123;
  SQLSMALLINT msg_length;

  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_ERROR);
  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_STMT, utest_fixture->stmt, 1, state,
                          &native, msg, sizeof(msg), &msg_length),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)state, "24000");
  EXPECT_EQ(native, 0);
  EXPECT_STREQ((char *)msg, "invalid");
  EXPECT_EQ(msg_length, 20);
}

/* GetDiagRec doesn't change the diagnostics, even when it fails. */
UTEST_F(db, 6_34_get_diag_rec_errors) {
  SQLCHAR state[6], msg[8];

  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_ERROR);
  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_STMT, utest_fixture->stmt, 2, state, NULL,
                          NULL, 0, NULL),
            SQL_NO_DATA);
  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_STMT, utest_fixture->stmt, 0, state, NULL,
                          NULL, 0, NULL),
            SQL_ERROR);
  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_STMT, utest_fixture->stmt, 1, state, NULL,
                          msg, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

UTEST_F(db, 6_34_get_diag_rec_null_pointers) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_ERROR);
  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_STMT, utest_fixture->stmt, 1, NULL, NULL,
                          NULL, 0, NULL),
            SQL_SUCCESS);
}

/* 6.48 NumResultCols */

UTEST_F(db, 6_48_num_result_cols) {
  SQLSMALLINT columns = 123;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT, y INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM t"), SQL_SUCCESS);
  EXPECT_EQ(SQLNumResultCols(utest_fixture->stmt, &columns), SQL_SUCCESS);
  EXPECT_EQ(columns, 2);
}

UTEST_F(db, 6_48_num_result_cols_no_statement) {
  SQLSMALLINT columns = 123;

  EXPECT_EQ(SQLNumResultCols(utest_fixture->stmt, &columns), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

UTEST_F(db, 6_48_num_result_cols_not_a_query) {
  SQLSMALLINT columns = 123;

  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT, y INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLNumResultCols(utest_fixture->stmt, &columns), SQL_SUCCESS);
  EXPECT_EQ(columns, 0);
}

UTEST_F(db, 6_48_num_result_cols_null_column_count) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT, y INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM t"), SQL_SUCCESS);
  EXPECT_EQ(SQLNumResultCols(utest_fixture->stmt, NULL), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
}

/* 6.53 RowCount */

UTEST_F(db, 6_53_row_count) {
  SQLINTEGER rows = 123;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_SUCCESS);
  EXPECT_EQ(rows, 0);

  ASSERT_EQ(
      run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (1), (2), (3)"),
      SQL_SUCCESS);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_SUCCESS);
  EXPECT_EQ(rows, 3);

  ASSERT_EQ(run_sql(utest_fixture->stmt, "UPDATE t SET x = 4 WHERE x > 1"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_SUCCESS);
  EXPECT_EQ(rows, 2);

  ASSERT_EQ(run_sql(utest_fixture->stmt, "DELETE FROM t"), SQL_SUCCESS);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_SUCCESS);
  EXPECT_EQ(rows, 3);
}

/* The row count of a query is 0, no matter how many rows it has. */
UTEST_F(db, 6_53_row_count_query) {
  SQLINTEGER rows = 123;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1, 2"), SQL_SUCCESS);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_SUCCESS);
  EXPECT_EQ(rows, 0);
}

UTEST_F(db, 6_53_row_count_no_statement) {
  SQLINTEGER rows;

  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

UTEST_F(db, 6_53_row_count_null_row_count) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, NULL), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
}

UTEST_F(db, 6_53_row_count_invalid_handle) {
  SQLINTEGER rows;

  EXPECT_EQ(SQLRowCount(utest_fixture->dbc, &rows), SQL_INVALID_HANDLE);
}

UTEST_MAIN()
