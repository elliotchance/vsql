#include "test.h"

/* 6.22 FetchScroll */

/* fetch_x fetches with FetchScroll and returns the bound value, or -1. */
static SQLINTEGER fetch_x(SQLHSTMT stmt, SQLSMALLINT orientation,
                          SQLINTEGER offset, SQLINTEGER *x) {
  *x = -1;
  if (SQLFetchScroll(stmt, orientation, offset) != SQL_SUCCESS) {
    return -1;
  }

  return *x;
}

struct scroll {
  SQLHENV env;
  SQLHDBC dbc;
  SQLHSTMT stmt;
  SQLINTEGER x;
};

UTEST_F_SETUP(scroll) {
  ASSERT_EQ(SQLAllocEnv(&utest_fixture->env), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocConnect(utest_fixture->env, &utest_fixture->dbc),
            SQL_SUCCESS);
  ASSERT_EQ(connect_memory(utest_fixture->dbc), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &utest_fixture->stmt),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_SCROLLABLE,
                           (SQLPOINTER)SQL_SCROLLABLE, 0),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1, 2, 3, 4, 5"), SQL_SUCCESS);
  ASSERT_EQ(SQLBindCol(utest_fixture->stmt, 1, SQL_INTEGER, &utest_fixture->x,
                       sizeof(SQLINTEGER), NULL),
            SQL_SUCCESS);
}

UTEST_F_TEARDOWN(scroll) {
  (void)utest_result;
  free_handles(utest_fixture->env, utest_fixture->dbc, utest_fixture->stmt);
}

#define SCROLL(o, j) fetch_x(utest_fixture->stmt, o, j, &utest_fixture->x)

UTEST_F(scroll, 6_22_fetch_scroll) {
  EXPECT_EQ(SCROLL(SQL_FETCH_NEXT, 0), 1);
  EXPECT_EQ(SCROLL(SQL_FETCH_NEXT, 0), 2);
  EXPECT_EQ(SCROLL(SQL_FETCH_LAST, 0), 5);
  EXPECT_EQ(SCROLL(SQL_FETCH_PRIOR, 0), 4);
  EXPECT_EQ(SCROLL(SQL_FETCH_FIRST, 0), 1);
  EXPECT_EQ(SCROLL(SQL_FETCH_ABSOLUTE, 3), 3);
  EXPECT_EQ(SCROLL(SQL_FETCH_ABSOLUTE, -2), 4);
  EXPECT_EQ(SCROLL(SQL_FETCH_RELATIVE, -2), 2);
  EXPECT_EQ(SCROLL(SQL_FETCH_RELATIVE, 2), 4);
  EXPECT_EQ(SCROLL(SQL_FETCH_RELATIVE, 0), 4);
}

/* Moving past the last row (or before the first) is no data, and the next
 * fetch continues from there. */
UTEST_F(scroll, 6_22_fetch_scroll_no_data) {
  EXPECT_EQ(SQLFetchScroll(utest_fixture->stmt, SQL_FETCH_ABSOLUTE, 6),
            SQL_NO_DATA);
  EXPECT_EQ(SCROLL(SQL_FETCH_PRIOR, 0), 5);
  EXPECT_EQ(SQLFetchScroll(utest_fixture->stmt, SQL_FETCH_RELATIVE, -10),
            SQL_NO_DATA);
  EXPECT_EQ(SCROLL(SQL_FETCH_NEXT, 0), 1);
  EXPECT_EQ(SQLFetchScroll(utest_fixture->stmt, SQL_FETCH_PRIOR, 0),
            SQL_NO_DATA);
  EXPECT_EQ(SQLFetchScroll(utest_fixture->stmt, SQL_FETCH_PRIOR, 0),
            SQL_NO_DATA);
  EXPECT_EQ(SCROLL(SQL_FETCH_RELATIVE, 2), 2);
  EXPECT_EQ(SCROLL(SQL_FETCH_LAST, 0), 5);
  EXPECT_EQ(SQLFetchScroll(utest_fixture->stmt, SQL_FETCH_NEXT, 0),
            SQL_NO_DATA);
  EXPECT_EQ(SQLFetchScroll(utest_fixture->stmt, SQL_FETCH_RELATIVE, 1),
            SQL_NO_DATA);
}

/* ABSOLUTE 0 is the first row. */
UTEST_F(scroll, 6_22_fetch_scroll_absolute_zero) {
  EXPECT_EQ(SCROLL(SQL_FETCH_LAST, 0), 5);
  EXPECT_EQ(SCROLL(SQL_FETCH_ABSOLUTE, 0), 1);
}

/* A rowset moves by ARRAY_SIZE rows. */
UTEST_F(db, 6_22_fetch_scroll_rowset) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLINTEGER x[2];

  ASSERT_EQ(SQLSetDescField(ard, 0, SQL_DESC_ARRAY_SIZE, (SQLPOINTER)2, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_SCROLLABLE,
                           (SQLPOINTER)SQL_SCROLLABLE, 0),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1, 2, 3, 4, 5"), SQL_SUCCESS);
  ASSERT_EQ(
      SQLBindCol(utest_fixture->stmt, 1, SQL_INTEGER, x, sizeof(x[0]), NULL),
      SQL_SUCCESS);

  EXPECT_EQ(SQLFetchScroll(utest_fixture->stmt, SQL_FETCH_LAST, 0),
            SQL_SUCCESS);
  EXPECT_EQ(x[0], 4);
  EXPECT_EQ(x[1], 5);
  EXPECT_EQ(SQLFetchScroll(utest_fixture->stmt, SQL_FETCH_PRIOR, 0),
            SQL_SUCCESS);
  EXPECT_EQ(x[0], 2);
  EXPECT_EQ(x[1], 3);
  EXPECT_EQ(SQLFetchScroll(utest_fixture->stmt, SQL_FETCH_PRIOR, 0),
            SQL_SUCCESS);
  EXPECT_EQ(x[0], 1);
  EXPECT_EQ(x[1], 2);
  /* There's nothing before the first rowset. */
  EXPECT_EQ(SQLFetchScroll(utest_fixture->stmt, SQL_FETCH_RELATIVE, -1),
            SQL_NO_DATA);
}

/* Only NEXT can be used without a scrollable cursor. */
UTEST_F(db, 6_22_fetch_scroll_not_scrollable) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1, 2"), SQL_SUCCESS);
  EXPECT_EQ(SQLFetchScroll(utest_fixture->stmt, SQL_FETCH_NEXT, 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLFetchScroll(utest_fixture->stmt, SQL_FETCH_FIRST, 0), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY106");
}

UTEST_F(scroll, 6_22_fetch_scroll_invalid_orientation) {
  EXPECT_EQ(SQLFetchScroll(utest_fixture->stmt, 7, 0), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY106");
}

UTEST_F(db, 6_22_fetch_scroll_no_cursor) {
  EXPECT_EQ(SQLFetchScroll(utest_fixture->stmt, SQL_FETCH_NEXT, 0), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLFetchScroll(utest_fixture->stmt, SQL_FETCH_NEXT, 0), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

/* An empty result has no rows to scroll to. */
UTEST_F(db, 6_22_fetch_scroll_empty) {
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_SCROLLABLE,
                           (SQLPOINTER)SQL_SCROLLABLE, 0),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM t"), SQL_SUCCESS);
  EXPECT_EQ(SQLFetchScroll(utest_fixture->stmt, SQL_FETCH_FIRST, 0),
            SQL_NO_DATA);
  EXPECT_EQ(SQLFetchScroll(utest_fixture->stmt, SQL_FETCH_LAST, 0),
            SQL_NO_DATA);
  EXPECT_EQ(SQLFetchScroll(utest_fixture->stmt, SQL_FETCH_ABSOLUTE, 1),
            SQL_NO_DATA);
}
