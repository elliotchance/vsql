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

/* A table is found again when the statement is executed, so one that's been
 * dropped since it was prepared is an error from Execute. */
UTEST_F(db, 6_20_execute_error) {
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE bar (x INT)"), SQL_SUCCESS);
  ASSERT_EQ(
      SQLPrepare(utest_fixture->stmt, (SQLCHAR *)"SELECT * FROM bar", SQL_NTS),
      SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "DROP TABLE bar"), SQL_SUCCESS);
  EXPECT_EQ(SQLExecute(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "42P01");
}

/* A failed execution doesn't replace the executed statement, so there's still
   a row count (of the failed statement, which has no rows). */
UTEST_F(db, 6_20_execute_failed_keeps_executed) {
  SQLINTEGER rows = 123;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT PRIMARY KEY)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLPrepare(utest_fixture->stmt,
                       (SQLCHAR *)"INSERT INTO t (x) VALUES (1)", SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(SQLExecute(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_SUCCESS);
  EXPECT_EQ(rows, 1);

  EXPECT_EQ(SQLExecute(utest_fixture->stmt), SQL_ERROR);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_SUCCESS);
  EXPECT_EQ(rows, 0);
}

/* Nothing was executed before the failed execution, so there's no row count. */
UTEST_F(db, 6_20_execute_failed_first) {
  SQLINTEGER rows;

  ASSERT_EQ(SQLPrepare(utest_fixture->stmt, (SQLCHAR *)"VALUES 1 / 0", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLExecute(utest_fixture->stmt), SQL_ERROR);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}
