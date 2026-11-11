#include "test.h"

/* A query can end with an <updatability clause>, which applies to the cursor
 * that it opens. FOR READ ONLY can't be changed by a positioned statement, even
 * though the query is simply updatable.
 *
 * ISO/IEC 9075-2:2016(E), 14.3, <cursor specification>, Syntax Rules, 6.b
 * ISO/IEC 9075-2:2016(E), 14.8, <delete statement: positioned>, Syntax Rules, 4
 */
UTEST_F(db, cursor_updatability_read_only) {
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER, y INTEGER)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "INSERT INTO t (x, y) VALUES (1, 10)"), SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"c1", SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT x, y FROM t FOR READ ONLY"),
            SQL_SUCCESS);
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, utest_fixture->stmt,
                           SQL_DIAG_DYNAMIC_FUNCTION),
               "SELECT CURSOR");
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);

  EXPECT_EQ(run_sql(stmt2, "DELETE FROM t WHERE CURRENT OF c1"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "34000");
  EXPECT_EQ(run_sql(stmt2, "UPDATE t SET y = 1 WHERE CURRENT OF c1"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "34000");
}

/* FOR UPDATE OF limits the columns that a positioned UPDATE can set. The query
 * can be prepared, and FOR UPDATE makes an ordered query updatable.
 *
 * ISO/IEC 9075-2:2016(E), 14.3, <cursor specification>, Syntax Rules, 6.a and 9
 */
UTEST_F(db, cursor_updatability_for_update_of) {
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER, y INTEGER)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "INSERT INTO t (x, y) VALUES (1, 10), (2, 20)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"c1", SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(
      SQLPrepare(utest_fixture->stmt,
                 (SQLCHAR *)"SELECT x, y FROM t ORDER BY x FOR UPDATE OF y",
                 SQL_NTS),
      SQL_SUCCESS);
  ASSERT_EQ(SQLExecute(utest_fixture->stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);

  EXPECT_EQ(run_sql(stmt2, "UPDATE t SET x = 5 WHERE CURRENT OF c1"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "42601");
  EXPECT_EQ(run_sql(stmt2, "UPDATE t SET y = 11 WHERE CURRENT OF c1"),
            SQL_SUCCESS);

  /* A query that isn't simply updatable can't be FOR UPDATE. */
  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(
      run_sql(utest_fixture->stmt, "SELECT x FROM t GROUP BY x FOR UPDATE"),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "42601");

  EXPECT_EQ(run_sql(stmt2, "SELECT x, y FROM t ORDER BY x"), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(stmt2, 2), "11,20");
}

/* A closed cursor still exists until the statement is freed (or its cursor
 * name changes), so a positioned statement is an invalid cursor state rather
 * than an invalid cursor name. A query can then open the cursor again.
 *
 * ISO/IEC 9075-2:2016(E), 15.5, Effect of a positioned delete, General Rules, 6
 * ISO/IEC 9075-2:2016(E), 15.6, Effect of a positioned update, General Rules, 6
 */
UTEST_F(db, cursor_updatability_closed_cursor) {
  SQLHSTMT stmt2;
  SQLHSTMT stmt = utest_fixture->stmt;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER)"), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "INSERT INTO t (x) VALUES (1)"), SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(stmt, (SQLCHAR *)"c1", SQL_NTS), SQL_SUCCESS);
  ASSERT_EQ(SQLPrepare(stmt, (SQLCHAR *)"SELECT x FROM t", SQL_NTS),
            SQL_SUCCESS);

  ASSERT_EQ(SQLExecute(stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLCloseCursor(stmt), SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt2, "DELETE FROM t WHERE CURRENT OF c1"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "24000");

  ASSERT_EQ(SQLExecute(stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLFreeStmt(stmt, SQL_CLOSE), SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt2, "UPDATE t SET x = 2 WHERE CURRENT OF c1"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "24000");

  /* It can be opened again by executing the statement. */
  ASSERT_EQ(SQLExecute(stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(stmt), SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt2, "UPDATE t SET x = 2 WHERE CURRENT OF c1"),
            SQL_SUCCESS);

  /* A new name destroys the cursor. */
  ASSERT_EQ(SQLCloseCursor(stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(stmt, (SQLCHAR *)"c2", SQL_NTS), SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt2, "DELETE FROM t WHERE CURRENT OF c1"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "34000");
}

/* SQLExecDirect of a positioned statement whose cursor was closed by the end
 * of the SQL-transaction is also an invalid cursor state. */
UTEST_F(db, cursor_updatability_closed_by_rollback) {
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER)"), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "INSERT INTO t (x) VALUES (1)"), SQL_SUCCESS);
  ASSERT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_HOLDABLE,
                           INTEGER_VALUE(SQL_NONHOLDABLE), 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"c1", SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT x FROM t"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);

  EXPECT_EQ(run_sql(stmt2, "DELETE FROM t WHERE CURRENT OF c1"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "24000");
}
