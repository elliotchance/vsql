#include "test.h"

/* 6.28 GetConnectAttr */

UTEST_F(db, 6_28_get_connect_attr_auto_ipd) {
  SQLINTEGER value = 123;

  EXPECT_EQ(
      SQLGetConnectAttr(utest_fixture->dbc, SQL_ATTR_AUTO_IPD, &value, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(value, SQL_FALSE);
}

UTEST_F(env, 6_28_get_connect_attr_auto_ipd_not_connected) {
  SQLINTEGER value;

  EXPECT_EQ(
      SQLGetConnectAttr(utest_fixture->dbc, SQL_ATTR_AUTO_IPD, &value, 0, NULL),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "08003");
}

UTEST_F(env, 6_28_get_connect_attr_savepoint_name) {
  SQLCHAR name[10] = "x";
  SQLINTEGER len = 123;

  EXPECT_EQ(SQLGetConnectAttr(utest_fixture->dbc, SQL_ATTR_SAVEPOINT_NAME, name,
                              sizeof(name), &len),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)name, "");
  EXPECT_EQ(len, 0);
}

UTEST_F(env, 6_28_get_connect_attr_unknown) {
  SQLINTEGER value;

  EXPECT_EQ(SQLGetConnectAttr(utest_fixture->dbc, 123, &value, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY092");
}

UTEST_F(env, 6_28_get_connect_attr_null_value) {
  EXPECT_EQ(SQLGetConnectAttr(utest_fixture->dbc, SQL_ATTR_SAVEPOINT_NAME, NULL,
                              10, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY009");
}

UTEST_F(env, 6_28_get_connect_attr_invalid_handle) {
  SQLINTEGER value;

  EXPECT_EQ(
      SQLGetConnectAttr(utest_fixture->env, SQL_ATTR_AUTO_IPD, &value, 0, NULL),
      SQL_INVALID_HANDLE);
}
