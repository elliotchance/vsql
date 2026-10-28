#include "test.h"

/* 6.5 BindCol */

UTEST_F(db, 6_5_bind_col) {
  SQLINTEGER x, ind;
  char s[10];
  SQLINTEGER len;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES ROW(1, 'a'), ROW(2, 'bc')"),
            SQL_SUCCESS);
  EXPECT_EQ(
      SQLBindCol(utest_fixture->stmt, 1, SQL_INTEGER, &x, sizeof(x), &ind),
      SQL_SUCCESS);
  EXPECT_EQ(SQLBindCol(utest_fixture->stmt, 2, SQL_CHAR, s, sizeof(s), &len),
            SQL_SUCCESS);

  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(x, 1);
  EXPECT_EQ(ind, 0);
  EXPECT_STREQ(s, "a ");
  EXPECT_EQ(len, 2);

  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(x, 2);
  EXPECT_STREQ(s, "bc");
  EXPECT_EQ(len, 2);

  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_NO_DATA);
}

/* BindCol sets the record of the column in the ARD. */
UTEST_F(db, 6_5_bind_col_ard) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLDOUBLE d;
  SQLINTEGER ind;
  SQLPOINTER p;

  EXPECT_EQ(SQLBindCol(utest_fixture->stmt, 3, SQL_DOUBLE, &d, sizeof(d), &ind),
            SQL_SUCCESS);
  EXPECT_EQ(desc_short(ard, 0, SQL_DESC_COUNT), 3);
  EXPECT_EQ(desc_short(ard, 3, SQL_DESC_TYPE), SQL_DOUBLE);
  EXPECT_EQ(desc_int(ard, 3, SQL_DESC_OCTET_LENGTH), (SQLINTEGER)sizeof(d));
  EXPECT_EQ(SQLGetDescField(ard, 3, SQL_DESC_DATA_POINTER, &p, 0, NULL),
            SQL_SUCCESS);
  EXPECT_TRUE(p == &d);
  EXPECT_EQ(SQLGetDescField(ard, 3, SQL_DESC_INDICATOR_POINTER, &p, 0, NULL),
            SQL_SUCCESS);
  EXPECT_TRUE(p == &ind);
  EXPECT_EQ(SQLGetDescField(ard, 3, SQL_DESC_OCTET_LENGTH_POINTER, &p, 0, NULL),
            SQL_SUCCESS);
  EXPECT_TRUE(p == &ind);

  /* A null TargetValue unbinds the column. */
  EXPECT_EQ(
      SQLBindCol(utest_fixture->stmt, 3, SQL_DOUBLE, NULL, sizeof(d), NULL),
      SQL_SUCCESS);
  EXPECT_EQ(SQLGetDescField(ard, 3, SQL_DESC_DATA_POINTER, &p, 0, NULL),
            SQL_SUCCESS);
  EXPECT_TRUE(p == NULL);
}

UTEST_F(db, 6_5_bind_col_invalid) {
  SQLINTEGER x;

  EXPECT_EQ(
      SQLBindCol(utest_fixture->stmt, 0, SQL_INTEGER, &x, sizeof(x), NULL),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07009");
  EXPECT_EQ(
      SQLBindCol(utest_fixture->stmt, 1, SQL_NUMERIC, &x, sizeof(x), NULL),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY003");
  EXPECT_EQ(
      SQLBindCol(utest_fixture->stmt, 1, SQL_VARCHAR, &x, sizeof(x), NULL),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY003");
  EXPECT_EQ(SQLBindCol(utest_fixture->stmt, 1, SQL_INTEGER, &x, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY090");
  EXPECT_EQ(SQLBindCol(utest_fixture->dbc, 1, SQL_INTEGER, &x, 4, NULL),
            SQL_INVALID_HANDLE);
}

/* SQL_DEFAULT is the type of the column, which needs a C type. */
UTEST_F(db, 6_5_bind_col_default) {
  SQLDOUBLE d = 0;
  char s[10];

  ASSERT_EQ(
      run_sql(utest_fixture->stmt,
              "VALUES ROW(CAST(1.5 AS DOUBLE PRECISION), DATE '2026-10-26')"),
      SQL_SUCCESS);
  ASSERT_EQ(
      SQLBindCol(utest_fixture->stmt, 1, SQL_DEFAULT, &d, sizeof(d), NULL),
      SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(d, 1.5);

  ASSERT_EQ(SQLBindCol(utest_fixture->stmt, 2, SQL_DEFAULT, s, sizeof(s), NULL),
            SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07002");
}

/* A bound column after the last column of the cursor. */
UTEST_F(db, 6_5_bind_col_after_last) {
  SQLINTEGER x;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  ASSERT_EQ(
      SQLBindCol(utest_fixture->stmt, 2, SQL_INTEGER, &x, sizeof(x), NULL),
      SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07009");
}
