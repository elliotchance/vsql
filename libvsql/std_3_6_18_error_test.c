#include "test.h"

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
