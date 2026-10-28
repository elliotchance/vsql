#include "test.h"

/* 6.50 Prepare */

/* A prepared query is described before it's executed. */
UTEST_F(db, 6_50_prepare_describe) {
  SQLSMALLINT n = 0;
  struct column col;

  ASSERT_EQ(SQLPrepare(utest_fixture->stmt, (SQLCHAR *)"VALUES ROW(1, 'abc')",
                       SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLNumResultCols(utest_fixture->stmt, &n), SQL_SUCCESS);
  EXPECT_EQ(n, 2);
  EXPECT_EQ(describe(utest_fixture->stmt, 2, &col), SQL_SUCCESS);
  EXPECT_EQ(col.type, SQL_CHAR);

  /* But it can't be fetched yet. */
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

/* A parameter's type is from the IPD. */
UTEST_F(db, 6_50_prepare_describe_parameter) {
  struct column col;
  SQLINTEGER x;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_BIGINT, 0, 0, &x, sizeof(x),
                             NULL),
            SQL_SUCCESS);
  ASSERT_EQ(SQLPrepare(utest_fixture->stmt, (SQLCHAR *)"VALUES ?", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 1, &col), SQL_SUCCESS);
  EXPECT_EQ(col.type, SQL_BIGINT);
}

UTEST_F(db, 6_50_prepare_syntax_error) {
  EXPECT_EQ(SQLPrepare(utest_fixture->stmt, (SQLCHAR *)"SELEC 1", SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "42601");
  EXPECT_EQ(SQLPrepare(utest_fixture->stmt, (SQLCHAR *)"COMMIT", SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "42000");
  EXPECT_EQ(SQLPrepare(utest_fixture->stmt, (SQLCHAR *)"", SQL_NTS), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY090");
}

UTEST_F(db, 6_50_prepare_open_cursor) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLPrepare(utest_fixture->stmt, (SQLCHAR *)"VALUES 2", SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}
