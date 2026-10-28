#include "test.h"

/* 6.21 Fetch */

UTEST_F(db, 6_21_fetch) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1, 2"), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_NO_DATA);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_NO_DATA);
}

UTEST_F(db, 6_21_fetch_no_statement) {
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

UTEST_F(db, 6_21_fetch_not_a_query) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

UTEST_F(db, 6_21_fetch_null) {
  SQLINTEGER x = 5, ind = 5;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(NULL AS INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(
      SQLBindCol(utest_fixture->stmt, 1, SQL_INTEGER, &x, sizeof(x), &ind),
      SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(ind, SQL_NULL_DATA);
}

/* A NULL needs an indicator, so the row is an error. */
UTEST_F(db, 6_21_fetch_null_no_indicator) {
  SQLINTEGER x;
  SQLINTEGER row = -1;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(NULL AS INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(
      SQLBindCol(utest_fixture->stmt, 1, SQL_INTEGER, &x, sizeof(x), NULL),
      SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "22002");
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 1,
                            SQL_DIAG_ROW_NUMBER, &row, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(row, 1);
}

/* A string that doesn't fit is truncated with a warning. */
UTEST_F(db, 6_21_fetch_truncated) {
  char s[4];
  SQLINTEGER len;
  SQLINTEGER column = -1;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 'hello'"), SQL_SUCCESS);
  ASSERT_EQ(SQLBindCol(utest_fixture->stmt, 1, SQL_CHAR, s, sizeof(s), &len),
            SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS_WITH_INFO);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "01004");
  EXPECT_STREQ(s, "hel");
  EXPECT_EQ(len, 5);
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 1,
                            SQL_DIAG_COLUMN_NUMBER, &column, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(column, 1);
}

/* With an ARRAY_SIZE, each Fetch assigns a rowset of rows to arrays. The
 * strings are a CHARACTER(3), so they're padded. */
UTEST_F(db, 6_21_fetch_rowset) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLHDESC ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);
  SQLINTEGER x[3], ind[3], statuses[3], processed = -1;
  char s[3][5];

  ASSERT_EQ(SQLSetDescField(ard, 0, SQL_DESC_ARRAY_SIZE, (SQLPOINTER)3, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetDescField(ird, 0, SQL_DESC_ARRAY_STATUS_POINTER, statuses, 0),
            SQL_SUCCESS);
  ASSERT_EQ(
      SQLSetDescField(ird, 0, SQL_DESC_ROWS_PROCESSED_POINTER, &processed, 0),
      SQL_SUCCESS);
  ASSERT_EQ(
      run_sql(utest_fixture->stmt,
              "VALUES ROW(1, 'a'), ROW(2, 'bb'), ROW(3, 'ccc'), ROW(4, 'd')"),
      SQL_SUCCESS);
  ASSERT_EQ(
      SQLBindCol(utest_fixture->stmt, 1, SQL_INTEGER, x, sizeof(x[0]), ind),
      SQL_SUCCESS);
  ASSERT_EQ(SQLBindCol(utest_fixture->stmt, 2, SQL_CHAR, s, sizeof(s[0]), NULL),
            SQL_SUCCESS);

  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(processed, 3);
  EXPECT_EQ(x[0], 1);
  EXPECT_EQ(x[1], 2);
  EXPECT_EQ(x[2], 3);
  EXPECT_STREQ(s[0], "a  ");
  EXPECT_STREQ(s[1], "bb ");
  EXPECT_STREQ(s[2], "ccc");
  EXPECT_EQ(statuses[0], SQL_ROW_SUCCESS);
  EXPECT_EQ(statuses[2], SQL_ROW_SUCCESS);

  /* The last rowset is partial. */
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(processed, 1);
  EXPECT_EQ(x[0], 4);
  EXPECT_STREQ(s[0], "d  ");
  EXPECT_EQ(statuses[0], SQL_ROW_SUCCESS);
  EXPECT_EQ(statuses[1], SQL_ROW_NO_ROW);
  EXPECT_EQ(statuses[2], SQL_ROW_NO_ROW);

  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_NO_DATA);
}

/* A row that can't be assigned is a row error, and the others are still
 * fetched. */
UTEST_F(db, 6_21_fetch_row_error) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLHDESC ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);
  SQLSMALLINT x[2];
  SQLINTEGER statuses[2], processed = -1, row = -1;

  ASSERT_EQ(SQLSetDescField(ard, 0, SQL_DESC_ARRAY_SIZE, (SQLPOINTER)2, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetDescField(ird, 0, SQL_DESC_ARRAY_STATUS_POINTER, statuses, 0),
            SQL_SUCCESS);
  ASSERT_EQ(
      SQLSetDescField(ird, 0, SQL_DESC_ROWS_PROCESSED_POINTER, &processed, 0),
      SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1, 100000"), SQL_SUCCESS);
  ASSERT_EQ(
      SQLBindCol(utest_fixture->stmt, 1, SQL_SMALLINT, x, sizeof(x[0]), NULL),
      SQL_SUCCESS);

  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS_WITH_INFO);
  EXPECT_EQ(processed, 1);
  EXPECT_EQ(x[0], 1);
  EXPECT_EQ(statuses[0], SQL_ROW_SUCCESS);
  EXPECT_EQ(statuses[1], SQL_ROW_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "01000");
  EXPECT_EQ(SQLGetDiagField(SQL_HANDLE_STMT, utest_fixture->stmt, 2,
                            SQL_DIAG_ROW_NUMBER, &row, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(row, 2);
}

/* A rowset of more than one row needs a scrollable cursor for GetData. */
UTEST_F(db, 6_21_fetch_rowset_get_data) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLINTEGER x;

  ASSERT_EQ(SQLSetDescField(ard, 0, SQL_DESC_ARRAY_SIZE, (SQLPOINTER)2, 0),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1, 2, 3"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_INTEGER, &x, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY109");

  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_SCROLLABLE,
                           (SQLPOINTER)SQL_SCROLLABLE, 0),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1, 2, 3"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_INTEGER, &x, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(x, 1);

  /* The CURRENT OF POSITION selects the row of the rowset. */
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURRENT_OF_POSITION,
                           (SQLPOINTER)2, 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_INTEGER, &x, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(x, 2);

  /* The last rowset only has one row. */
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURRENT_OF_POSITION,
                           (SQLPOINTER)2, 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_INTEGER, &x, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY109");
}
