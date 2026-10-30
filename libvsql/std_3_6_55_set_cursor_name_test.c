#include "test.h"

/* 6.55 SetCursorName */

UTEST_F(db, 6_55_set_cursor_name) {
  SQLCHAR name[200];

  EXPECT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"  c1  ", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetCursorName(utest_fixture->stmt, name, sizeof(name), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)name, "c1");

  EXPECT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"\"my cursor\"",
                             SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetCursorName(utest_fixture->stmt, name, sizeof(name), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)name, "\"my cursor\"");
}

/* Two statements can't have the same name (regular identifiers are case
 * insensitive). */
UTEST_F(db, 6_55_set_cursor_name_duplicate) {
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"c1", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLSetCursorName(stmt2, (SQLCHAR *)"C1", SQL_NTS), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "34000");
  EXPECT_EQ(SQLSetCursorName(stmt2, (SQLCHAR *)"\"C1\"", SQL_NTS), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "34000");
  EXPECT_EQ(SQLSetCursorName(stmt2, (SQLCHAR *)"\"c1\"", SQL_NTS), SQL_SUCCESS);

  /* The same statement can use its own name again. */
  EXPECT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"c1", SQL_NTS),
            SQL_SUCCESS);
}

UTEST_F(db, 6_55_set_cursor_name_invalid) {
  EXPECT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"1abc", SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "34000");
  EXPECT_EQ(
      SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"sql_cur1", SQL_NTS),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "34000");
  EXPECT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"SQLCUR", SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "34000");
  EXPECT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"", SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY090");

  /* An incomplete UTF-8 character. */
  EXPECT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"a\xc3\xa9", 2),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "34000");
}

UTEST_F(db, 6_55_set_cursor_name_open_cursor) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"c1", SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

/* A positioned UPDATE or DELETE of another statement changes the current row
 * of the cursor with the name. */
UTEST_F(db, 6_55_set_cursor_name_positioned) {
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER)"), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "INSERT INTO t (x) VALUES (1), (2), (3)"),
            SQL_SUCCESS);

  ASSERT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"c1", SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT x FROM t"), SQL_SUCCESS);

  /* The cursor isn't on a row before the first fetch. */
  EXPECT_EQ(run_sql(stmt2, "DELETE FROM t WHERE CURRENT OF c1"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "24000");

  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt2, "UPDATE t SET x = 10 WHERE CURRENT OF c1"),
            SQL_SUCCESS);
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, stmt2, SQL_DIAG_DYNAMIC_FUNCTION),
               "PREPARABLE DYNAMIC UPDATE CURSOR");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, stmt2, SQL_DIAG_DYNAMIC_FUNCTION_CODE),
            55);

  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt2, "DELETE FROM t WHERE CURRENT OF c1"), SQL_SUCCESS);
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, stmt2, SQL_DIAG_DYNAMIC_FUNCTION),
               "PREPARABLE DYNAMIC DELETE CURSOR");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, stmt2, SQL_DIAG_DYNAMIC_FUNCTION_CODE),
            54);

  /* After the last row the cursor isn't on a row. */
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_NO_DATA);
  EXPECT_EQ(run_sql(stmt2, "DELETE FROM t WHERE CURRENT OF c1"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "24000");

  /* A closed cursor can't be used, and the query can be executed again. */
  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt2, "DELETE FROM t WHERE CURRENT OF c1"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "34000");
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT x FROM t"), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 1), "10,3");
}

/* A cursor that hasn't been named has the generated name. */
UTEST_F(db, 6_55_set_cursor_name_positioned_generated_name) {
  SQLHSTMT stmt2;
  SQLCHAR name[200];
  char sql[300];

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER)"), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "INSERT INTO t (x) VALUES (1), (2)"), SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT x FROM t"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);

  ASSERT_EQ(SQLGetCursorName(utest_fixture->stmt, name, sizeof(name), NULL),
            SQL_SUCCESS);
  snprintf(sql, sizeof(sql), "DELETE FROM t WHERE CURRENT OF %s", name);
  EXPECT_EQ(run_sql(stmt2, sql), SQL_SUCCESS);

  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT x FROM t"), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 1), "2");
}

/* The current row is the CURRENT OF POSITION row of the rowset. */
UTEST_F(db, 6_55_set_cursor_name_positioned_rowset) {
  SQLHSTMT stmt2;
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER)"), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "INSERT INTO t (x) VALUES (1), (2), (3)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetDescField(ard, 0, SQL_DESC_ARRAY_SIZE, INTEGER_VALUE(2), 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_SCROLLABLE,
                           INTEGER_VALUE(SQL_SCROLLABLE), 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"c1", SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT x FROM t"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURRENT_OF_POSITION,
                           INTEGER_VALUE(2), 0),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt2, "DELETE FROM t WHERE CURRENT OF c1"), SQL_SUCCESS);

  /* The last rowset only has one row, so there's no second row. */
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt2, "UPDATE t SET x = 30 WHERE CURRENT OF c1"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURRENT_OF_POSITION,
                           INTEGER_VALUE(2), 0),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt2, "UPDATE t SET x = 40 WHERE CURRENT OF c1"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "24000");

  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLSetDescField(ard, 0, SQL_DESC_ARRAY_SIZE, INTEGER_VALUE(1), 0),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT x FROM t"), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 1), "1,30");
}

/* A holdable cursor stays open after a commit, but it must be fetched again
 * before its current row can be changed. */
UTEST_F(db, 6_55_set_cursor_name_positioned_holdable) {
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER)"), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "INSERT INTO t (x) VALUES (1), (2)"), SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"c1", SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT x FROM t"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);

  EXPECT_EQ(run_sql(stmt2, "DELETE FROM t WHERE CURRENT OF c1"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "24000");
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt2, "DELETE FROM t WHERE CURRENT OF c1"), SQL_SUCCESS);

  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT x FROM t"), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 1), "1");
}
