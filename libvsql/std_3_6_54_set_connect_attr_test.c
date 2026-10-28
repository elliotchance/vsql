#include "test.h"

/* 6.54 SetConnectAttr */

UTEST_F(env, 6_54_set_connect_attr_savepoint_name) {
  SQLCHAR name[10];
  SQLINTEGER len;

  EXPECT_EQ(SQLSetConnectAttr(utest_fixture->dbc, SQL_ATTR_SAVEPOINT_NAME,
                              (SQLPOINTER) "sp1", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetConnectAttr(utest_fixture->dbc, SQL_ATTR_SAVEPOINT_NAME, name,
                              sizeof(name), &len),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)name, "sp1");
  EXPECT_EQ(len, 3);

  EXPECT_EQ(SQLSetConnectAttr(utest_fixture->dbc, SQL_ATTR_SAVEPOINT_NAME,
                              (SQLPOINTER) "abcdef", 2),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetConnectAttr(utest_fixture->dbc, SQL_ATTR_SAVEPOINT_NAME, name,
                              sizeof(name), &len),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)name, "ab");
}

/* A name that doesn't fit is truncated with a warning. */
UTEST_F(env, 6_54_set_connect_attr_savepoint_name_truncated) {
  SQLCHAR name[3];
  SQLINTEGER len;

  EXPECT_EQ(SQLSetConnectAttr(utest_fixture->dbc, SQL_ATTR_SAVEPOINT_NAME,
                              (SQLPOINTER) "sp1", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetConnectAttr(utest_fixture->dbc, SQL_ATTR_SAVEPOINT_NAME, name,
                              sizeof(name), &len),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "01004");
  EXPECT_STREQ((char *)name, "sp");
  EXPECT_EQ(len, 3);
}

UTEST_F(env, 6_54_set_connect_attr_negative_length) {
  EXPECT_EQ(SQLSetConnectAttr(utest_fixture->dbc, SQL_ATTR_SAVEPOINT_NAME,
                              (SQLPOINTER) "sp1", -5),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY090");
}

/* POPULATE IPD can't be set. */
UTEST_F(db, 6_54_set_connect_attr_auto_ipd) {
  EXPECT_EQ(SQLSetConnectAttr(utest_fixture->dbc, SQL_ATTR_AUTO_IPD,
                              (SQLPOINTER)SQL_TRUE, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY092");
}

UTEST_F(env, 6_54_set_connect_attr_invalid_handle) {
  EXPECT_EQ(SQLSetConnectAttr(utest_fixture->env, SQL_ATTR_SAVEPOINT_NAME,
                              (SQLPOINTER) "sp1", SQL_NTS),
            SQL_INVALID_HANDLE);
}
