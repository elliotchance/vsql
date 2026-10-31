#include "test.h"

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

/* A descriptor that was allocated with a statement is freed with it. */
UTEST_F(db, 6_26_free_handle_automatic_descriptor) {
  SQLHDESC ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);

  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_DESC, ird), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ird, "HY017");
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_STMT, utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_DESC, ird), SQL_INVALID_HANDLE);
}

/* A statement that used a freed descriptor goes back to its own. */
UTEST_F(db, 6_26_free_handle_descriptor_in_use) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLHDESC desc;

  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_DESC, utest_fixture->dbc, &desc),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC,
                           HANDLE_VALUE(desc), 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_APP_PARAM_DESC,
                           HANDLE_VALUE(desc), 0),
            SQL_SUCCESS);
  EXPECT_EQ(stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC), desc);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_DESC, desc), SQL_SUCCESS);
  EXPECT_EQ(stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC), ard);
  EXPECT_NE(stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_PARAM_DESC), desc);
}

/* A descriptor can't be freed while it's the application parameter descriptor
 * of a statement that's waiting for a deferred parameter. */
UTEST_F(db, 6_26_free_handle_desc_deferred_parameter) {
  SQLINTEGER at_exec = SQL_DATA_AT_EXEC, x = 1;
  SQLHDESC desc;

  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_DESC, utest_fixture->dbc, &desc),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_APP_PARAM_DESC,
                           INTEGER_VALUE(desc), 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_INTEGER, 0, 0, &x, sizeof(x),
                             &at_exec),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES ?"), SQL_NEED_DATA);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_DESC, desc), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, desc, "HY010");
  EXPECT_EQ(SQLCancel(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_DESC, desc), SQL_SUCCESS);
}
