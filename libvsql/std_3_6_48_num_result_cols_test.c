#include "test.h"

/* 6.48 NumResultCols */

UTEST_F(db, 6_48_num_result_cols) {
  SQLSMALLINT columns = 123;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT, y INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM t"), SQL_SUCCESS);
  EXPECT_EQ(SQLNumResultCols(utest_fixture->stmt, &columns), SQL_SUCCESS);
  EXPECT_EQ(columns, 2);
}

UTEST_F(db, 6_48_num_result_cols_no_statement) {
  SQLSMALLINT columns = 123;

  EXPECT_EQ(SQLNumResultCols(utest_fixture->stmt, &columns), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

UTEST_F(db, 6_48_num_result_cols_not_a_query) {
  SQLSMALLINT columns = 123;

  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT, y INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLNumResultCols(utest_fixture->stmt, &columns), SQL_SUCCESS);
  EXPECT_EQ(columns, 0);
}

UTEST_F(db, 6_48_num_result_cols_null_column_count) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT, y INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM t"), SQL_SUCCESS);
  EXPECT_EQ(SQLNumResultCols(utest_fixture->stmt, NULL), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
}

/* The IRD still describes the columns after the cursor is closed. */
UTEST_F(row, 6_48_num_result_cols_closed_cursor) {
  SQLSMALLINT columns = 0;

  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLNumResultCols(utest_fixture->stmt, &columns), SQL_SUCCESS);
  EXPECT_EQ(columns, 6);
}
