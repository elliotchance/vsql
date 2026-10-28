#include "test.h"

/* 6.37 GetFunctions */

UTEST_F(db, 6_37_get_functions) {
  SQLSMALLINT supported = -1;

  EXPECT_EQ(
      SQLGetFunctions(utest_fixture->dbc, SQL_API_SQLFETCHSCROLL, &supported),
      SQL_SUCCESS);
  EXPECT_EQ(supported, 1);
  EXPECT_EQ(
      SQLGetFunctions(utest_fixture->dbc, SQL_API_SQLGETFUNCTIONS, &supported),
      SQL_SUCCESS);
  EXPECT_EQ(supported, 1);
  EXPECT_EQ(
      SQLGetFunctions(utest_fixture->dbc, SQL_API_SQLGETSUBSTRING, &supported),
      SQL_SUCCESS);
  EXPECT_EQ(supported, 0);
}

UTEST_F(db, 6_37_get_functions_invalid) {
  SQLSMALLINT supported;

  EXPECT_EQ(SQLGetFunctions(utest_fixture->dbc, 9999, &supported), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY095");
}

UTEST_F(env, 6_37_get_functions_not_connected) {
  SQLSMALLINT supported;

  EXPECT_EQ(SQLGetFunctions(utest_fixture->dbc, SQL_API_SQLFETCH, &supported),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "08003");
}
