#include "test.h"

/* A warning: cursor operation conflict has the name of the cursor that caused
 * it, whether it's raised by the positioned statement or by a searched
 * statement. */
UTEST_F(db, cursor_operation_conflict) {
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER, y INTEGER)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "INSERT INTO t (x, y) VALUES (1, 10), (2, 20)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"c1", SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM t"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);

  /* There's no conflict the first time. */
  EXPECT_EQ(run_sql(stmt2, "UPDATE t SET y = 11 WHERE CURRENT OF c1"),
            SQL_SUCCESS);

  /* A searched statement changes a row changed by the positioned statement. */
  EXPECT_EQ(run_sql(stmt2, "UPDATE t SET y = 12 WHERE x = 1"),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "01001");
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, stmt2, SQL_DIAG_CURSOR_NAME), "C1");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, stmt2, SQL_DIAG_ROW_COUNT), 1);

  /* The positioned statement changes a row that was changed. */
  EXPECT_EQ(run_sql(stmt2, "UPDATE t SET y = 13 WHERE CURRENT OF c1"),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "01001");
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, stmt2, SQL_DIAG_CURSOR_NAME), "C1");

  /* The row can be gone, which isn't no data. */
  EXPECT_EQ(run_sql(stmt2, "DELETE FROM t WHERE x = 1"),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_EQ(run_sql(stmt2, "DELETE FROM t WHERE CURRENT OF c1"),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "01001");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, stmt2, SQL_DIAG_ROW_COUNT), 0);

  /* Another warning from an earlier statement of the connection isn't raised
   * again. */
  EXPECT_EQ(run_sql(stmt2, "UPDATE t SET y = 21 WHERE x = 2"), SQL_SUCCESS);
}

/* A row that the cursor has deleted can be scrolled back to, but it's not a row
 * that can be changed. */
UTEST_F(db, cursor_operation_conflict_scrolled_back) {
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER)"), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "INSERT INTO t (x) VALUES (1), (2)"), SQL_SUCCESS);
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_SCROLLABLE,
                           INTEGER_VALUE(SQL_SCROLLABLE), 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"c1", SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT x FROM t"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "DELETE FROM t WHERE CURRENT OF c1"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLFetchScroll(utest_fixture->stmt, SQL_FETCH_PRIOR, 0),
            SQL_SUCCESS);

  EXPECT_EQ(run_sql(stmt2, "DELETE FROM t WHERE CURRENT OF c1"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "24000");
}
