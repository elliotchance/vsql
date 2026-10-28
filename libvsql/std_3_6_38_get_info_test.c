#include "test.h"

/* 6.38 GetInfo */

UTEST_F(db, 6_38_get_info_string) {
  SQLCHAR value[100];
  SQLSMALLINT length;

  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_DBMS_NAME, value, sizeof(value),
                       &length),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)value, "vsql");
  EXPECT_EQ(length, 4);
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_SERVER_NAME, value,
                       sizeof(value), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)value, ":memory:");
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_SEARCH_PATTERN_ESCAPE, value,
                       sizeof(value), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)value, "\\");

  /* The version is "00.00.0000" until set_version.sh sets it, so only the
   * format is checked. */
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_DBMS_VERSION, value,
                       sizeof(value), NULL),
            SQL_SUCCESS);
  EXPECT_GE(strlen((char *)value), (size_t)10);
  EXPECT_EQ(value[2], '.');
  EXPECT_EQ(value[5], '.');
}

UTEST_F(db, 6_38_get_info_truncated) {
  SQLCHAR value[3];
  SQLSMALLINT length;

  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_DBMS_NAME, value, sizeof(value),
                       &length),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_STREQ((char *)value, "vs");
  EXPECT_EQ(length, 4);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "01004");
}

UTEST_F(db, 6_38_get_info_smallint) {
  SQLSMALLINT value = -1;

  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_MAXIMUM_TABLE_NAME_LENGTH,
                       &value, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(value, 128);
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_MAXIMUM_COLUMNS_IN_TABLE, &value,
                       0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(value, 1600);
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_MAXIMUM_COLUMNS_IN_SELECT,
                       &value, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(value, 0);
  EXPECT_EQ(
      SQLGetInfo(utest_fixture->dbc, SQL_IDENTIFIER_CASE, &value, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(value, SQL_IC_UPPER);
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_NULL_COLLATION, &value, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(value, SQL_NC_LOW);
  EXPECT_EQ(
      SQLGetInfo(utest_fixture->dbc, SQL_TRANSACTION_CAPABLE, &value, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(value, SQL_TC_ALL);
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_CURSOR_COMMIT_BEHAVIOR, &value,
                       0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(value, SQL_CB_PRESERVE);
}

UTEST_F(db, 6_38_get_info_integer) {
  SQLINTEGER value = -1;

  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_DEFAULT_TRANSACTION_ISOLATION,
                       &value, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(value, SQL_TRANSACTION_READ_COMMITTED);
  EXPECT_EQ(
      SQLGetInfo(utest_fixture->dbc, SQL_FETCH_DIRECTION, &value, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(value, SQL_FD_FETCH_NEXT | SQL_FD_FETCH_FIRST | SQL_FD_FETCH_LAST |
                       SQL_FD_FETCH_PRIOR | SQL_FD_FETCH_ABSOLUTE |
                       SQL_FD_FETCH_RELATIVE);
  EXPECT_EQ(
      SQLGetInfo(utest_fixture->dbc, SQL_CURSOR_SENSITIVITY, &value, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(value, SQL_INSENSITIVE);
}

UTEST_F(db, 6_38_get_info_invalid) {
  SQLINTEGER value;

  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, 9999, &value, 0, NULL), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY096");
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_DBMS_NAME, NULL, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY009");
}

UTEST_F(env, 6_38_get_info_not_connected) {
  SQLCHAR value[100];

  EXPECT_EQ(
      SQLGetInfo(utest_fixture->dbc, SQL_DBMS_NAME, value, sizeof(value), NULL),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "08003");
}
