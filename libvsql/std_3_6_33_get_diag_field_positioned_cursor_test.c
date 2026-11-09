/* SQL_DIAG_CURSOR_NAME of an invalid cursor state raised by a positioned
 * statement is the cursor that's in the invalid state, rather than the
 * statement handle that executed it.
 *
 * ISO/IEC 9075-3:2003(E), 6.33, GetDiagField, General Rules, 12.i.iv */
#include "test.h"

/* The name is the one that SQLGetCursorName returns, not the one the engine
 * keeps (in upper case). */
UTEST_F(db, 6_33_get_diag_field_positioned_cursor_name) {
  SQLHSTMT stmt2;
  SQLCHAR name[32];
  SQLSMALLINT len;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER)"), SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"c1", SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT x FROM t"), SQL_SUCCESS);

  EXPECT_EQ(run_sql(stmt2, "DELETE FROM t WHERE CURRENT OF c1"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "24000");
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, stmt2, SQL_DIAG_CURSOR_NAME), "c1");

  EXPECT_EQ(run_sql(stmt2, "UPDATE t SET x = 2 WHERE CURRENT OF C1"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "24000");
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, stmt2, SQL_DIAG_CURSOR_NAME), "c1");

  /* The handle that raised it has its own implicit name. */
  ASSERT_EQ(SQLGetCursorName(stmt2, name, sizeof(name), &len), SQL_SUCCESS);
  EXPECT_STRNE((const char *)name, "c1");

  ASSERT_EQ(SQLFreeHandle(SQL_HANDLE_STMT, stmt2), SQL_SUCCESS);
}

/* The implicit name of a cursor that was never given one. */
UTEST_F(db, 6_33_get_diag_field_positioned_cursor_implicit_name) {
  SQLHSTMT stmt2;
  SQLCHAR name[32];
  SQLSMALLINT len;
  char sql[128];

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER)"), SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT x FROM t"), SQL_SUCCESS);
  ASSERT_EQ(SQLGetCursorName(utest_fixture->stmt, name, sizeof(name), &len),
            SQL_SUCCESS);

  snprintf(sql, sizeof(sql), "DELETE FROM t WHERE CURRENT OF %s", name);
  EXPECT_EQ(run_sql(stmt2, sql), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "24000");
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, stmt2, SQL_DIAG_CURSOR_NAME),
               (const char *)name);

  ASSERT_EQ(SQLFreeHandle(SQL_HANDLE_STMT, stmt2), SQL_SUCCESS);
}

/* The condition outlives the statement of the cursor, which only leaves the
 * name that the engine keeps. */
UTEST_F(db, 6_33_get_diag_field_positioned_cursor_freed) {
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER)"), SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"c1", SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT x FROM t"), SQL_SUCCESS);

  EXPECT_EQ(run_sql(stmt2, "DELETE FROM t WHERE CURRENT OF c1"), SQL_ERROR);
  ASSERT_EQ(SQLFreeHandle(SQL_HANDLE_STMT, utest_fixture->stmt), SQL_SUCCESS);
  utest_fixture->stmt = stmt2;

  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "24000");
  EXPECT_STREQ(diag_string(SQL_HANDLE_STMT, stmt2, SQL_DIAG_CURSOR_NAME), "C1");
}
