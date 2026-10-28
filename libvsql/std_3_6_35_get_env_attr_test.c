#include "test.h"

/* 6.35 GetEnvAttr */

UTEST_F(env, 6_35_get_env_attr) {
  SQLINTEGER value = 123;

  EXPECT_EQ(
      SQLGetEnvAttr(utest_fixture->env, SQL_ATTR_OUTPUT_NTS, &value, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(value, SQL_TRUE);
}

UTEST_F(env, 6_35_get_env_attr_unknown) {
  SQLINTEGER value;

  EXPECT_EQ(SQLGetEnvAttr(utest_fixture->env, 123, &value, 0, NULL), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_ENV, utest_fixture->env, "HY092");
}

UTEST_F(env, 6_35_get_env_attr_null_value) {
  EXPECT_EQ(
      SQLGetEnvAttr(utest_fixture->env, SQL_ATTR_OUTPUT_NTS, NULL, 0, NULL),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_ENV, utest_fixture->env, "HY009");
}

UTEST_F(env, 6_35_get_env_attr_invalid_handle) {
  SQLINTEGER value;

  EXPECT_EQ(
      SQLGetEnvAttr(utest_fixture->dbc, SQL_ATTR_OUTPUT_NTS, &value, 0, NULL),
      SQL_INVALID_HANDLE);
}
