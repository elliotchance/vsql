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

/* These fail when they're prepared, rather than when they're executed. */
UTEST_F(db, 6_50_prepare_not_preparable) {
  const char *statements[] = {
      "DECLARE c CURSOR FOR VALUES 1",
      "OPEN c",
      "FETCH NEXT FROM c",
      "CLOSE c",
      "CONNECT TO DEFAULT",
      "SET CONNECTION DEFAULT",
      "DISCONNECT CURRENT",
  };

  for (size_t i = 0; i < sizeof(statements) / sizeof(statements[0]); i++) {
    EXPECT_EQ(
        SQLPrepare(utest_fixture->stmt, (SQLCHAR *)statements[i], SQL_NTS),
        SQL_ERROR);
    EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "42000");
  }
}

UTEST_F(db, 6_50_prepare_open_cursor) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLPrepare(utest_fixture->stmt, (SQLCHAR *)"VALUES 2", SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

/* The cursor of a positioned statement must exist. An error leaves the prepared
 * statement that was already there. */
UTEST_F(db, 6_50_prepare_positioned_invalid_cursor) {
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER)"), SQL_SUCCESS);
  ASSERT_EQ(SQLPrepare(stmt2, (SQLCHAR *)"VALUES 1", SQL_NTS), SQL_SUCCESS);

  EXPECT_EQ(SQLPrepare(stmt2, (SQLCHAR *)"DELETE FROM t WHERE CURRENT OF c1",
                       SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "34000");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, stmt2, SQL_DIAG_DYNAMIC_FUNCTION_CODE),
            54);
  EXPECT_EQ(SQLPrepare(stmt2,
                       (SQLCHAR *)"UPDATE t SET x = 1 WHERE CURRENT OF c1",
                       SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "34000");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, stmt2, SQL_DIAG_DYNAMIC_FUNCTION_CODE),
            55);

  /* A syntax error is the same. */
  EXPECT_EQ(SQLPrepare(stmt2, (SQLCHAR *)"SELEC 1", SQL_NTS), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "42601");

  EXPECT_EQ(SQLExecute(stmt2), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(stmt2, 1), "1");
}

/* A query that's only been prepared doesn't have a cursor yet, and the cursor
 * has to be of another statement. */
UTEST_F(db, 6_50_prepare_positioned_no_cursor_yet) {
  SQLHSTMT stmt2;
  SQLHSTMT stmt = utest_fixture->stmt;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER)"), SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(stmt, (SQLCHAR *)"c1", SQL_NTS), SQL_SUCCESS);
  ASSERT_EQ(SQLPrepare(stmt, (SQLCHAR *)"SELECT x FROM t", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLPrepare(stmt2, (SQLCHAR *)"DELETE FROM t WHERE CURRENT OF c1",
                       SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "34000");

  ASSERT_EQ(SQLExecute(stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLCloseCursor(stmt), SQL_SUCCESS);
  EXPECT_EQ(
      SQLPrepare(stmt, (SQLCHAR *)"DELETE FROM t WHERE CURRENT OF c1", SQL_NTS),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt, "34000");
}

/* A prepared positioned statement can be executed on each row, and it stays
 * prepared while the cursor is closed and opened again. */
UTEST_F(db, 6_50_prepare_positioned) {
  SQLHSTMT stmt2, stmt3;
  SQLHSTMT stmt = utest_fixture->stmt;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt3), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt3, "CREATE TABLE t (x INTEGER)"), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt3, "INSERT INTO t (x) VALUES (1), (2)"), SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(stmt, (SQLCHAR *)"C1", SQL_NTS), SQL_SUCCESS);
  ASSERT_EQ(SQLPrepare(stmt, (SQLCHAR *)"SELECT x FROM t", SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(SQLExecute(stmt), SQL_SUCCESS);

  ASSERT_EQ(SQLPrepare(stmt2,
                       (SQLCHAR *)"UPDATE t SET x = x + 10 WHERE CURRENT OF c1",
                       SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLExecute(stmt2), SQL_SUCCESS);

  /* A closed cursor isn't destroyed, so it can still be referenced. */
  ASSERT_EQ(SQLCloseCursor(stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLPrepare(stmt3, (SQLCHAR *)"DELETE FROM t WHERE CURRENT OF c1",
                       SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(SQLExecute(stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLExecute(stmt2), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLExecute(stmt3), SQL_SUCCESS);
  ASSERT_EQ(SQLCloseCursor(stmt), SQL_SUCCESS);

  ASSERT_EQ(SQLExecute(stmt), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(stmt, 1), "21");
}

/* Preparing another statement destroys the cursor, and the prepared statements
 * that reference it. They don't use a later cursor with the name. */
UTEST_F(db, 6_50_prepare_positioned_destroyed) {
  SQLHSTMT stmt2, stmt3;
  SQLHSTMT stmt = utest_fixture->stmt;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt3), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER)"), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "INSERT INTO t (x) VALUES (1), (2)"), SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(stmt, (SQLCHAR *)"c1", SQL_NTS), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt, "SELECT x FROM t"), SQL_SUCCESS);
  ASSERT_EQ(SQLPrepare(stmt2, (SQLCHAR *)"DELETE FROM t WHERE CURRENT OF c1",
                       SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(SQLPrepare(stmt3, (SQLCHAR *)"VALUES 1", SQL_NTS), SQL_SUCCESS);
  ASSERT_EQ(SQLCloseCursor(stmt), SQL_SUCCESS);

  ASSERT_EQ(SQLPrepare(stmt, (SQLCHAR *)"SELECT x FROM t", SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(SQLExecute(stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLExecute(stmt2), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "HY010");

  /* A statement that doesn't reference it stays prepared. */
  EXPECT_EQ(SQLExecute(stmt3), SQL_SUCCESS);

  /* The row wasn't deleted. */
  ASSERT_EQ(SQLCloseCursor(stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLExecute(stmt), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(stmt, 1), "1,2");
}

/* A cursor is also destroyed by reallocating or freeing its statement, or by
 * giving it another name. */
UTEST_F(db, 6_50_prepare_positioned_destroyed_free) {
  SQLHSTMT stmt2, stmt3;
  SQLHSTMT stmt = utest_fixture->stmt;
  const char *sql = "DELETE FROM t WHERE CURRENT OF c1";

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER)"), SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(stmt, (SQLCHAR *)"c1", SQL_NTS), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt, "SELECT x FROM t"), SQL_SUCCESS);
  ASSERT_EQ(SQLPrepare(stmt2, (SQLCHAR *)sql, SQL_NTS), SQL_SUCCESS);
  ASSERT_EQ(SQLFreeStmt(stmt, SQL_REALLOCATE), SQL_SUCCESS);
  EXPECT_EQ(SQLExecute(stmt2), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "HY010");

  /* Giving it the same name doesn't. */
  ASSERT_EQ(run_sql(stmt, "SELECT x FROM t"), SQL_SUCCESS);
  ASSERT_EQ(SQLPrepare(stmt2, (SQLCHAR *)sql, SQL_NTS), SQL_SUCCESS);
  ASSERT_EQ(SQLCloseCursor(stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(stmt, (SQLCHAR *)"C1", SQL_NTS), SQL_SUCCESS);
  EXPECT_EQ(SQLPrepare(stmt2, (SQLCHAR *)sql, SQL_NTS), SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(stmt, (SQLCHAR *)"c2", SQL_NTS), SQL_SUCCESS);
  EXPECT_EQ(SQLExecute(stmt2), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "HY010");
  EXPECT_EQ(SQLPrepare(stmt2, (SQLCHAR *)sql, SQL_NTS), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "34000");

  /* Freeing a statement. */
  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt3), SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(stmt3, (SQLCHAR *)"c1", SQL_NTS), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt3, "SELECT x FROM t"), SQL_SUCCESS);
  ASSERT_EQ(SQLPrepare(stmt2, (SQLCHAR *)sql, SQL_NTS), SQL_SUCCESS);
  ASSERT_EQ(SQLFreeHandle(SQL_HANDLE_STMT, stmt3), SQL_SUCCESS);
  EXPECT_EQ(SQLExecute(stmt2), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "HY010");
}
