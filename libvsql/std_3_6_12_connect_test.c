#include "test.h"

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
