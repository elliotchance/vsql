#include "test.h"

/* A SELECT without a FROM clause (V008-01) can be prepared and described before
 * it's executed. */
UTEST_F(db, select_without_from_prepare) {
  struct column col;
  SQLSMALLINT columns = 0;

  ASSERT_EQ(SQLPrepare(utest_fixture->stmt,
                       (SQLCHAR *)"SELECT 1 + 2 AS x, 'a'", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLNumResultCols(utest_fixture->stmt, &columns), SQL_SUCCESS);
  EXPECT_EQ(columns, 2);
  EXPECT_EQ(describe(utest_fixture->stmt, 1, &col), SQL_SUCCESS);
  EXPECT_STREQ((char *)col.name, "X");
  EXPECT_EQ(describe(utest_fixture->stmt, 2, &col), SQL_SUCCESS);
  EXPECT_STREQ((char *)col.name, "COL2");

  EXPECT_EQ(SQLExecute(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 2), "a");
}

UTEST_F(db, select_without_from_parameter) {
  SQLINTEGER x = 7, y = 0;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_INTEGER, 0, 0, &x, sizeof(x),
                             NULL),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT ? + 1"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_INTEGER, &y, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(y, 8);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_NO_DATA);
}
