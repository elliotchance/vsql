#include "test.h"

/* 6.33 GetDiagField */

UTEST_F(db, 6_33_get_diag_field_number) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM bar"), SQL_ERROR);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_NUMBER), 1);

  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_NUMBER), 0);
}

UTEST_F(row, 6_33_get_diag_field_returncode) {
  SQLSMALLINT rc = 123;
  SQLCHAR buf[3];
  SQLINTEGER ind;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_CHAR, buf,
                       sizeof(buf), &ind),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 0,
                            SQL_DIAG_RETURNCODE, &rc, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(rc, SQL_SUCCESS_WITH_INFO);

  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_NO_DATA);
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 0,
                            SQL_DIAG_RETURNCODE, &rc, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(rc, SQL_NO_DATA);

  EXPECT_EQ(SQLFetch(utest_fixture->dbc), SQL_INVALID_HANDLE);
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 0,
                            SQL_DIAG_RETURNCODE, &rc, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(rc, SQL_SUCCESS);

  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_ERROR);
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 0,
                            SQL_DIAG_RETURNCODE, &rc, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(rc, SQL_ERROR);
}

UTEST_F(db, 6_33_get_diag_field_row_count) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (1), (2)"),
            SQL_SUCCESS);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_ROW_COUNT),
            2);
}

/* The ROW_COUNT is only for a routine that executes a statement. */
UTEST_F(db, 6_33_get_diag_field_row_count_not_executed) {
  SQLINTEGER rows;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 0,
                            SQL_DIAG_ROW_COUNT, &rows, 0, NULL),
            SQL_ERROR);
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_DBC, utest_fixture->dbc, 0,
                            SQL_DIAG_ROW_COUNT, &rows, 0, NULL),
            SQL_ERROR);
}

/* A failed statement has a ROW_COUNT of 0. */
UTEST_F(db, 6_33_get_diag_field_row_count_error) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "DELETE FROM bar"), SQL_ERROR);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_ROW_COUNT),
            0);
}

UTEST_F(db, 6_33_get_diag_field_dynamic_function) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, utest_fixture->stmt,
                           SQL_DIAG_DYNAMIC_FUNCTION),
               "CREATE TABLE");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt,
                     SQL_DIAG_DYNAMIC_FUNCTION_CODE),
            SQL_DIAG_CREATE_TABLE);

  ASSERT_EQ(run_sql(utest_fixture->stmt, "insert into t (x) values (1)"),
            SQL_SUCCESS);
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, utest_fixture->stmt,
                           SQL_DIAG_DYNAMIC_FUNCTION),
               "INSERT");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt,
                     SQL_DIAG_DYNAMIC_FUNCTION_CODE),
            SQL_DIAG_INSERT);

  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM t"), SQL_SUCCESS);
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, utest_fixture->stmt,
                           SQL_DIAG_DYNAMIC_FUNCTION),
               "SELECT CURSOR");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt,
                     SQL_DIAG_DYNAMIC_FUNCTION_CODE),
            SQL_DIAG_SELECT_CURSOR);
}

/* Spaces and bracketed comments (which can be nested) before the statement
 * are skipped. */
UTEST_F(db, 6_33_get_diag_field_dynamic_function_comments) {
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "  /* a /* nested */ comment */ UPDATE bar SET x = 1"),
            SQL_ERROR);
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, utest_fixture->stmt,
                           SQL_DIAG_DYNAMIC_FUNCTION),
               "UPDATE WHERE");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt,
                     SQL_DIAG_DYNAMIC_FUNCTION_CODE),
            SQL_DIAG_UPDATE_WHERE);
}

UTEST_F(db, 6_33_get_diag_field_dynamic_function_unknown) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "FOO BAR"), SQL_ERROR);
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, utest_fixture->stmt,
                           SQL_DIAG_DYNAMIC_FUNCTION),
               "");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt,
                     SQL_DIAG_DYNAMIC_FUNCTION_CODE),
            SQL_DIAG_UNKNOWN_STATEMENT);
}

/* The statement is identified once it's parsed, so a syntax error doesn't have
 * a DYNAMIC_FUNCTION. */
UTEST_F(db, 6_33_get_diag_field_dynamic_function_syntax_error) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO"), SQL_ERROR);
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, utest_fixture->stmt,
                           SQL_DIAG_DYNAMIC_FUNCTION),
               "");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt,
                     SQL_DIAG_DYNAMIC_FUNCTION_CODE),
            SQL_DIAG_UNKNOWN_STATEMENT);
}

/* Every statement has a code, even if it's not in the header. */
UTEST_F(db, 6_33_get_diag_field_dynamic_function_set_constraints) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SET CONSTRAINTS ALL DEFERRED"),
            SQL_SUCCESS);
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, utest_fixture->stmt,
                           SQL_DIAG_DYNAMIC_FUNCTION),
               "SET CONSTRAINT");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt,
                     SQL_DIAG_DYNAMIC_FUNCTION_CODE),
            68);
}

/* A routine that doesn't execute a statement has no DYNAMIC_FUNCTION. */
UTEST_F(db, 6_33_get_diag_field_dynamic_function_fetch) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, utest_fixture->stmt,
                           SQL_DIAG_DYNAMIC_FUNCTION),
               "");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt,
                     SQL_DIAG_DYNAMIC_FUNCTION_CODE),
            0);
}

UTEST_F(db, 6_33_get_diag_field_transactions) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt,
                     SQL_DIAG_TRANSACTION_ACTIVE),
            1);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_TRANSACTION_ACTIVE),
      1);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_ENV, utest_fixture->env, SQL_DIAG_TRANSACTION_ACTIVE),
      1);

  ASSERT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);
  EXPECT_EQ(diag_int(SQL_HANDLE_DBC, utest_fixture->dbc,
                     SQL_DIAG_TRANSACTIONS_COMMITTED),
            1);
  EXPECT_EQ(diag_int(SQL_HANDLE_DBC, utest_fixture->dbc,
                     SQL_DIAG_TRANSACTIONS_ROLLED_BACK),
            0);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_TRANSACTION_ACTIVE),
      0);

  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  ASSERT_EQ(SQLEndTran(SQL_HANDLE_ENV, utest_fixture->env, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(diag_int(SQL_HANDLE_ENV, utest_fixture->env,
                     SQL_DIAG_TRANSACTIONS_COMMITTED),
            0);
  EXPECT_EQ(diag_int(SQL_HANDLE_ENV, utest_fixture->env,
                     SQL_DIAG_TRANSACTIONS_ROLLED_BACK),
            1);
}

UTEST_F(db, 6_33_get_diag_field_more) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM bar"), SQL_ERROR);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_MORE), 0);
}

UTEST_F(db, 6_33_get_diag_field_record) {
  SQLINTEGER i = -1;

  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM bar"), SQL_ERROR);
  EXPECT_STREQ(
      diag_string(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_SQLSTATE),
      "42P01");
  EXPECT_STREQ(
      diag_string(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_MESSAGE_TEXT),
      "no such table: \":memory:\".PUBLIC.BAR");
  EXPECT_STREQ(
      diag_string(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_CLASS_ORIGIN),
      "ISO 9075");
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, utest_fixture->stmt,
                           SQL_DIAG_SUBCLASS_ORIGIN),
               "vsql");
  EXPECT_STREQ(
      diag_string(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_SERVER_NAME),
      ":memory:");
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, utest_fixture->stmt,
                           SQL_DIAG_CONNECTION_NAME),
               ":memory:");
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, utest_fixture->stmt,
                           SQL_DIAG_CONSTRAINT_NAME),
               "");
  EXPECT_STREQ(
      diag_string(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_CURSOR_NAME),
      "");

  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 1,
                            SQL_DIAG_CONDITION_NUMBER, &i, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(i, 1);
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 1,
                            SQL_DIAG_NATIVE_CODE, &i, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(i, 0);
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 1,
                            SQL_DIAG_ROW_NUMBER, &i, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(i, 0);
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 1,
                            SQL_DIAG_COLUMN_NUMBER, &i, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(i, 0);
}

UTEST_F(db, 6_33_get_diag_field_constraint) {
  EXPECT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE baz (x INT CONSTRAINT positive CHECK (x > 0))"),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO baz (x) VALUES (-1)"),
            SQL_ERROR);
  EXPECT_STREQ(
      diag_string(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_SQLSTATE),
      "23514");
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, utest_fixture->stmt,
                           SQL_DIAG_CONSTRAINT_CATALOG),
               ":memory:");
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, utest_fixture->stmt,
                           SQL_DIAG_CONSTRAINT_SCHEMA),
               "PUBLIC");
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, utest_fixture->stmt,
                           SQL_DIAG_CONSTRAINT_NAME),
               "POSITIVE");
}

/* The CLI-specific SQLSTATEs are from the standard. */
UTEST_F(db, 6_33_get_diag_field_origin) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, ""), SQL_ERROR);
  EXPECT_STREQ(
      diag_string(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_CLASS_ORIGIN),
      "ISO 9075");
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, utest_fixture->stmt,
                           SQL_DIAG_SUBCLASS_ORIGIN),
               "ISO 9075");
}

/* The message length is in characters, and the octet length is in octets. */
UTEST_F(db, 6_33_get_diag_field_message_length) {
  SQLINTEGER chars, octets;

  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM \"h\xc3\xa9llo\""),
            SQL_ERROR);
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 1,
                            SQL_DIAG_MESSAGE_LENGTH, &chars, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 1,
                            SQL_DIAG_MESSAGE_OCTET_LENGTH, &octets, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(octets, chars + 1);
}

/* A string is truncated without a warning, and StringLength is the length of
 * the whole string. */
UTEST_F(db, 6_33_get_diag_field_truncated) {
  SQLCHAR state[4];
  SQLSMALLINT len;

  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM bar"), SQL_ERROR);
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 1,
                            SQL_DIAG_SQLSTATE, state, sizeof(state), &len),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)state, "42P");
  EXPECT_EQ(len, 5);
}

UTEST_F(db, 6_33_get_diag_field_zero_buffer_length) {
  SQLCHAR state[6];

  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM bar"), SQL_ERROR);
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 1,
                            SQL_DIAG_SQLSTATE, state, 0, NULL),
            SQL_ERROR);
}

/* The column number is the column that GetData was retrieving. */
UTEST_F(row, 6_33_get_diag_field_column_number) {
  SQLCHAR buf[3];
  SQLINTEGER ind, column;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_CHAR, buf,
                       sizeof(buf), &ind),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 1,
                            SQL_DIAG_COLUMN_NUMBER, &column, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(column, COL_VARCHAR);
}

UTEST_F(db, 6_33_get_diag_field_record_number) {
  SQLCHAR state[6];

  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM bar"), SQL_ERROR);
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 0,
                            SQL_DIAG_SQLSTATE, state, sizeof(state), NULL),
            SQL_ERROR);
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 2,
                            SQL_DIAG_SQLSTATE, state, sizeof(state), NULL),
            SQL_NO_DATA);
}

UTEST_F(db, 6_33_get_diag_field_unknown_field) {
  SQLINTEGER i;

  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 0, 999, &i, 0,
                            NULL),
            SQL_ERROR);
  EXPECT_EQ(
      SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 1, 0, &i, 0, NULL),
      SQL_ERROR);
}

UTEST_F(db, 6_33_get_diag_field_invalid_handle) {
  SQLINTEGER i;

  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->dbc, 0,
                            SQL_DIAG_NUMBER, &i, 0, NULL),
            SQL_INVALID_HANDLE);
  EXPECT_EQ(
      SQLGetDiagField(7, utest_fixture->dbc, 0, SQL_DIAG_NUMBER, &i, 0, NULL),
      SQL_INVALID_HANDLE);
}

/* The server name of a connection is its ServerName, or "DEFAULT". */
UTEST_F(env, 6_33_get_diag_field_server_name) {
  EXPECT_EQ(SQLConnect(utest_fixture->dbc, NULL, 0, (SQLCHAR *)"user", SQL_NTS,
                       NULL, 0),
            SQL_ERROR);
  EXPECT_STREQ(
      diag_string(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_SERVER_NAME),
      "DEFAULT");
}

/* GetDiagField doesn't change the diagnostics area. */
UTEST_F(db, 6_33_get_diag_field_unchanged) {
  SQLINTEGER i;

  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM bar"), SQL_ERROR);
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 3, 999, &i, 0,
                            NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "42P01");
}

/* The CURSOR_NAME of an invalid cursor state. */
UTEST_F(db, 6_33_get_diag_field_cursor_name) {
  ASSERT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"c1", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_ERROR);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 2"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
  EXPECT_STREQ(
      diag_string(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_CURSOR_NAME),
      "c1");
}

/* The SERVER_NAME of a statement is of its own connection, even when that's
 * the dormant connection. */
UTEST_F(db, 6_33_get_diag_field_server_name_dormant) {
  SQLHDBC dbc2;
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocConnect(utest_fixture->env, &dbc2), SQL_SUCCESS);
  ASSERT_EQ(connect_default(dbc2), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocStmt(dbc2, &stmt2), SQL_SUCCESS);

  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM bar"), SQL_ERROR);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt2, "SELECT * FROM bar"), SQL_ERROR);
  EXPECT_STREQ(
      diag_string(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_SERVER_NAME),
      ":memory:");
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, stmt2, SQL_DIAG_SERVER_NAME),
               "DEFAULT");

  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, dbc2, SQL_ROLLBACK), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(dbc2), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeConnect(dbc2), SQL_SUCCESS);
}
