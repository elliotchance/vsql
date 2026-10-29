#include "test.h"

/* 6.42 GetSessionInfo */

UTEST_F(db, 6_42_get_session_info) {
  SQLCHAR value[32];
  SQLSMALLINT length;

  /* vsql doesn't support CURRENT_USER yet, so selecting it is a syntax error,
   * which is returned on the connection handle. */
  EXPECT_EQ(SQLGetSessionInfo(utest_fixture->dbc, SQL_CURRENT_USER, value,
                              sizeof(value), &length),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "42601");
}

UTEST_F(db, 6_42_get_session_info_invalid) {
  SQLCHAR value[32];

  EXPECT_EQ(SQLGetSessionInfo(utest_fixture->dbc, 123, value, sizeof(value),
                              NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY096");
  EXPECT_EQ(SQLGetSessionInfo(-1, SQL_CURRENT_USER, value, sizeof(value), NULL),
            SQL_INVALID_HANDLE);
}

UTEST_F(env, 6_42_get_session_info_not_connected) {
  SQLCHAR value[32];

  EXPECT_EQ(SQLGetSessionInfo(utest_fixture->dbc, SQL_CURRENT_USER, value,
                              sizeof(value), NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "08003");
}
