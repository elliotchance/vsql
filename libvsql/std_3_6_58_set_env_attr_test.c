#include "test.h"

/* 6.58 SetEnvAttr */

UTEST(libvsql, 6_58_set_env_attr) {
  SQLHENV env;
  SQLINTEGER value;

  ASSERT_EQ(SQLAllocEnv(&env), SQL_SUCCESS);
  EXPECT_EQ(
      SQLSetEnvAttr(env, SQL_ATTR_OUTPUT_NTS, INTEGER_VALUE(SQL_FALSE), 0),
      SQL_SUCCESS);
  EXPECT_EQ(SQLGetEnvAttr(env, SQL_ATTR_OUTPUT_NTS, &value, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(value, SQL_FALSE);
  EXPECT_EQ(SQLSetEnvAttr(env, SQL_ATTR_OUTPUT_NTS, INTEGER_VALUE(SQL_TRUE), 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetEnvAttr(env, SQL_ATTR_OUTPUT_NTS, &value, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(value, SQL_TRUE);
  EXPECT_EQ(SQLFreeEnv(env), SQL_SUCCESS);
}

/* The attributes can only be set before allocating a connection. */
UTEST_F(env, 6_58_set_env_attr_with_connection) {
  EXPECT_EQ(SQLSetEnvAttr(utest_fixture->env, SQL_ATTR_OUTPUT_NTS,
                          INTEGER_VALUE(SQL_FALSE), 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_ENV, utest_fixture->env, "HY011");
}

UTEST(libvsql, 6_58_set_env_attr_invalid) {
  SQLHENV env;

  ASSERT_EQ(SQLAllocEnv(&env), SQL_SUCCESS);
  EXPECT_EQ(SQLSetEnvAttr(env, 123, INTEGER_VALUE(SQL_FALSE), 0), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_ENV, env, "HY092");
  EXPECT_EQ(SQLSetEnvAttr(env, SQL_ATTR_OUTPUT_NTS, INTEGER_VALUE(2), 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_ENV, env, "HY024");
  EXPECT_EQ(SQLSetEnvAttr(env + 1000, SQL_ATTR_OUTPUT_NTS,
                          INTEGER_VALUE(SQL_FALSE), 0),
            SQL_INVALID_HANDLE);
  EXPECT_EQ(SQLFreeEnv(env), SQL_SUCCESS);
}

/* Without null termination, strings are returned without a null terminator,
 * and a value that fills the buffer isn't truncated. */
UTEST(libvsql, 6_58_set_env_attr_no_null_termination) {
  SQLHENV env;
  SQLHDBC dbc;
  SQLHSTMT stmt;
  SQLCHAR buf[6];
  SQLINTEGER ind;

  ASSERT_EQ(SQLAllocEnv(&env), SQL_SUCCESS);
  ASSERT_EQ(
      SQLSetEnvAttr(env, SQL_ATTR_OUTPUT_NTS, INTEGER_VALUE(SQL_FALSE), 0),
      SQL_SUCCESS);
  ASSERT_EQ(SQLAllocConnect(env, &dbc), SQL_SUCCESS);
  ASSERT_EQ(connect_memory(dbc), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocStmt(dbc, &stmt), SQL_SUCCESS);

  ASSERT_EQ(run_sql(stmt, "VALUES 'abc'"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(stmt), SQL_SUCCESS);
  memset(buf, 'x', sizeof(buf));
  EXPECT_EQ(SQLGetData(stmt, 1, SQL_CHAR, buf, 3, &ind), SQL_SUCCESS);
  EXPECT_EQ(memcmp(buf, "abcxxx", 6), 0);
  EXPECT_EQ(ind, 3);

  /* Retrieving it in pieces uses the whole buffer each time. */
  ASSERT_EQ(SQLCloseCursor(stmt), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt, "VALUES 'hello world'"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(stmt), SQL_SUCCESS);
  memset(buf, 'x', sizeof(buf));
  EXPECT_EQ(SQLGetData(stmt, 1, SQL_CHAR, buf, 5, &ind), SQL_SUCCESS_WITH_INFO);
  EXPECT_EQ(memcmp(buf, "hellox", 6), 0);
  EXPECT_EQ(ind, 11);
  EXPECT_EQ(SQLGetData(stmt, 1, SQL_CHAR, buf, 5, &ind), SQL_SUCCESS_WITH_INFO);
  EXPECT_EQ(memcmp(buf, " worlx", 6), 0);
  EXPECT_EQ(SQLGetData(stmt, 1, SQL_CHAR, buf, 5, &ind), SQL_SUCCESS);
  EXPECT_EQ(memcmp(buf, "dworlx", 6), 0);
  EXPECT_EQ(ind, 1);

  /* The SQLSTATE is 5 octets. */
  ASSERT_EQ(SQLCloseCursor(stmt), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt, "SELECT * FROM bar"), SQL_ERROR);
  memset(buf, 'x', sizeof(buf));
  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_STMT, stmt, 1, buf, NULL, NULL, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(memcmp(buf, "42P01x", 6), 0);

  /* A zero BufferLength is the same as a null pointer. */
  memset(buf, 'x', sizeof(buf));
  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_STMT, stmt, 1, NULL, NULL, buf, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(buf[0], 'x');

  free_handles(env, dbc, stmt);
}

UTEST(libvsql, 6_58_set_env_attr_null_value) {
  SQLHENV env2;

  ASSERT_EQ(SQLAllocEnv(&env2), SQL_SUCCESS);
  EXPECT_EQ(SQLSetEnvAttr(env2, SQL_ATTR_OUTPUT_NTS, NULL, 0), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_ENV, env2, "HY009");
  EXPECT_EQ(SQLFreeEnv(env2), SQL_SUCCESS);
}
