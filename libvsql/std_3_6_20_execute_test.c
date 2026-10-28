#include "test.h"

/* 6.20 Execute */

UTEST_F(db, 6_20_execute_not_prepared) {
  EXPECT_EQ(SQLExecute(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");

  /* ExecDirect doesn't leave a prepared statement. */
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLExecute(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

UTEST_F(db, 6_20_execute_open_cursor) {
  ASSERT_EQ(SQLPrepare(utest_fixture->stmt, (SQLCHAR *)"VALUES 1", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLExecute(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLExecute(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLExecute(utest_fixture->stmt), SQL_SUCCESS);
}

/* The DYNAMIC_FUNCTION and ROW_COUNT are from the prepared statement. */
UTEST_F(db, 6_20_execute_diagnostics) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLPrepare(utest_fixture->stmt,
                       (SQLCHAR *)"INSERT INTO t (x) VALUES (1), (2)", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLExecute(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, utest_fixture->stmt,
                           SQL_DIAG_DYNAMIC_FUNCTION),
               "INSERT");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_ROW_COUNT),
            2);
}

/* An error that isn't a syntax error is returned by Execute. */
UTEST_F(db, 6_20_execute_error) {
  ASSERT_EQ(
      SQLPrepare(utest_fixture->stmt, (SQLCHAR *)"SELECT * FROM bar", SQL_NTS),
      SQL_SUCCESS);
  EXPECT_EQ(SQLExecute(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "42P01");
}
