#include "test.h"

/* 6.53 RowCount */

UTEST_F(db, 6_53_row_count) {
  SQLINTEGER rows = 123;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_SUCCESS);
  EXPECT_EQ(rows, 0);

  ASSERT_EQ(
      run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (1), (2), (3)"),
      SQL_SUCCESS);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_SUCCESS);
  EXPECT_EQ(rows, 3);

  ASSERT_EQ(run_sql(utest_fixture->stmt, "UPDATE t SET x = 4 WHERE x > 1"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_SUCCESS);
  EXPECT_EQ(rows, 2);

  ASSERT_EQ(run_sql(utest_fixture->stmt, "DELETE FROM t"), SQL_SUCCESS);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_SUCCESS);
  EXPECT_EQ(rows, 3);
}

/* The row count of a query is 0, no matter how many rows it has. */
UTEST_F(db, 6_53_row_count_query) {
  SQLINTEGER rows = 123;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1, 2"), SQL_SUCCESS);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_SUCCESS);
  EXPECT_EQ(rows, 0);
}

UTEST_F(db, 6_53_row_count_no_statement) {
  SQLINTEGER rows;

  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

UTEST_F(db, 6_53_row_count_null_row_count) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, NULL), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
}

UTEST_F(db, 6_53_row_count_invalid_handle) {
  SQLINTEGER rows;

  EXPECT_EQ(SQLRowCount(utest_fixture->dbc, &rows), SQL_INVALID_HANDLE);
}
