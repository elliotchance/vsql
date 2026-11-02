#include "test.h"

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

/* A descriptor allocated by the application has an ALLOC_TYPE of USER. */
UTEST_F(db, 6_3_alloc_handle_desc) {
  SQLHDESC desc;
  SQLSMALLINT alloc_type = 0;

  EXPECT_EQ(SQLAllocHandle(SQL_HANDLE_DESC, utest_fixture->dbc, &desc),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetDescField(desc, 0, SQL_DESC_ALLOC_TYPE, &alloc_type, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(alloc_type, SQL_DESC_ALLOC_USER);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_DESC, desc), SQL_SUCCESS);
}

UTEST_F(env, 6_3_alloc_handle_desc_not_connected) {
  SQLINTEGER h = 123;

  EXPECT_EQ(SQLAllocHandle(SQL_HANDLE_DESC, utest_fixture->dbc, &h), SQL_ERROR);
  EXPECT_EQ(h, 0);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "08003");
}

/* A descriptor needs an allocated connection, otherwise the output handle is
 * zero. */
UTEST(libvsql, 6_3_alloc_handle_desc_unallocated_connection) {
  SQLHDESC desc = 1;

  EXPECT_EQ(SQLAllocHandle(SQL_HANDLE_DESC, 999999, &desc), SQL_INVALID_HANDLE);
  EXPECT_EQ(desc, 0);
}
