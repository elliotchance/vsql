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
