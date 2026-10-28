#include "test.h"

/* 6.30 GetData */

UTEST_F(db, 6_30_get_data_not_fetched) {
  SQLINTEGER i, ind;

  ASSERT_EQ(run_sql(utest_fixture->stmt, ROW_SQL), SQL_SUCCESS);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_BIGINT, SQL_INTEGER, &i, 0, &ind),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

UTEST_F(row, 6_30_get_data_null) {
  SQLINTEGER i, ind;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_NULL, SQL_INTEGER, &i, 0, &ind),
            SQL_SUCCESS);
  EXPECT_EQ(ind, SQL_NULL_DATA);
}

UTEST_F(row, 6_30_get_data_null_needs_indicator) {
  SQLINTEGER i;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_NULL, SQL_INTEGER, &i, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "22002");
}

/* A character value that doesn't fit is retrieved in pieces. */
UTEST_F(row, 6_30_get_data_pieces) {
  char buf[6];
  SQLINTEGER ind;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_CHAR, buf,
                       sizeof(buf), &ind),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "01004");
  EXPECT_STREQ(buf, "hello");
  EXPECT_EQ(ind, 11);

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_CHAR, buf,
                       sizeof(buf), &ind),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_STREQ(buf, " worl");
  EXPECT_EQ(ind, 6);

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_CHAR, buf,
                       sizeof(buf), &ind),
            SQL_SUCCESS);
  EXPECT_STREQ(buf, "d");
  EXPECT_EQ(ind, 1);
}

/* After the last piece, it starts again. */
UTEST_F(row, 6_30_get_data_pieces_again) {
  char buf[16];
  SQLINTEGER ind;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_CHAR, buf,
                       sizeof(buf), &ind),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_CHAR, buf,
                       sizeof(buf), &ind),
            SQL_SUCCESS);
  EXPECT_STREQ(buf, "hello world");
}

/* Only a character value can be retrieved in pieces. */
UTEST_F(row, 6_30_get_data_pieces_as_integer) {
  char buf[6];
  SQLINTEGER i, ind;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_CHAR, buf,
                       sizeof(buf), &ind),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_INTEGER, &i, 0, &ind),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07009");
}

UTEST_F(row, 6_30_get_data_zero_buffer_length) {
  char buf[6];
  SQLINTEGER ind;

  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_CHAR, buf, 0, &ind),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY090");
}

UTEST_F(row, 6_30_get_data_double) {
  SQLDOUBLE d;
  SQLINTEGER ind;

  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_DOUBLE, SQL_DOUBLE, &d, 0, &ind),
      SQL_SUCCESS);
  EXPECT_EQ(d, 4.56);
  EXPECT_EQ(ind, 0);
}

UTEST_F(row, 6_30_get_data_default) {
  SQLDOUBLE d;

  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_DOUBLE, SQL_DEFAULT, &d, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(d, 4.56);
}

UTEST_F(row, 6_30_get_data_real) {
  SQLREAL r;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_DOUBLE, SQL_REAL, &r, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(r, (SQLREAL)4.56);
}

UTEST_F(row, 6_30_get_data_double_as_char) {
  char big[32];

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_DOUBLE, SQL_CHAR, big,
                       sizeof(big), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ(big, "4.56e0");
}

UTEST_F(row, 6_30_get_data_bigint_as_integer) {
  SQLINTEGER i;

  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_BIGINT, SQL_INTEGER, &i, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(i, 100000);
}

UTEST_F(row, 6_30_get_data_out_of_range) {
  SQLSMALLINT s;

  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_BIGINT, SQL_SMALLINT, &s, 0, NULL),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "22003");
}

UTEST_F(row, 6_30_get_data_numeric_as_double) {
  SQLDOUBLE d;

  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_NUMERIC, SQL_DOUBLE, &d, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(d, 12.5);
}

/* A DATE can only be retrieved as a string. */
UTEST_F(row, 6_30_get_data_date) {
  char big[32];
  SQLINTEGER ind;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_DATE, SQL_CHAR, big,
                       sizeof(big), &ind),
            SQL_SUCCESS);
  EXPECT_STREQ(big, "2026-10-25");
  EXPECT_EQ(ind, 10);
}

UTEST_F(row, 6_30_get_data_date_as_integer) {
  SQLINTEGER i;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_DATE, SQL_INTEGER, &i, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07006");
}

/* A DATE doesn't have a C type. */
UTEST_F(row, 6_30_get_data_date_as_default) {
  SQLINTEGER i;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_DATE, SQL_DEFAULT, &i, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07002");
}

/* Neither does a CHARACTER VARYING (only a CHARACTER). */
UTEST_F(row, 6_30_get_data_varchar_as_default) {
  char buf[20];

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, COL_VARCHAR, SQL_DEFAULT, buf,
                       sizeof(buf), NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07002");
}

/* NUMERIC has no C data type. */
UTEST_F(row, 6_30_get_data_as_numeric) {
  SQLDOUBLE d;

  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_NUMERIC, SQL_NUMERIC, &d, 0, NULL),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY003");
}

UTEST_F(row, 6_30_get_data_column_after_last) {
  SQLINTEGER i;

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 7, SQL_INTEGER, &i, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07009");
}

UTEST_F(row, 6_30_get_data_null_target) {
  SQLINTEGER ind;

  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_BIGINT, SQL_INTEGER, NULL, 0, &ind),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
}

/* There's no row after the last row. */
UTEST_F(row, 6_30_get_data_after_last_row) {
  SQLINTEGER i, ind;

  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_NO_DATA);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_BIGINT, SQL_INTEGER, &i, 0, &ind),
      SQL_NO_DATA);
}

/* SQL_ARD_TYPE uses the TYPE of the column in the ARD. */
UTEST_F(row, 6_30_get_data_ard_type) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLDOUBLE d = 0;

  ASSERT_EQ(SQLSetDescField(ard, COL_BIGINT, SQL_DESC_TYPE,
                            (SQLPOINTER)SQL_DOUBLE, 0),
            SQL_SUCCESS);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_BIGINT, SQL_ARD_TYPE, &d, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(d, 100000.0);
}

/* Without a record in the ARD, SQL_ARD_TYPE is SQL_DEFAULT. */
UTEST_F(row, 6_30_get_data_ard_type_no_record) {
  SQLDOUBLE d = 0;

  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_DOUBLE, SQL_ARD_TYPE, &d, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(d, 4.56);
}

/* A NUMERIC TYPE in the ARD doesn't have a C type. */
UTEST_F(row, 6_30_get_data_ard_type_numeric) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLDOUBLE d;

  ASSERT_EQ(SQLSetDescField(ard, COL_NUMERIC, SQL_DESC_TYPE,
                            (SQLPOINTER)SQL_NUMERIC, 0),
            SQL_SUCCESS);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_NUMERIC, SQL_ARD_TYPE, &d, 0, NULL),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07002");
}

/* The TargetType becomes the TYPE of the column in the ARD. */
UTEST_F(row, 6_30_get_data_sets_ard_type) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLINTEGER i;

  ASSERT_EQ(SQLSetDescField(ard, 0, SQL_DESC_COUNT, (SQLPOINTER)6, 0),
            SQL_SUCCESS);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_BIGINT, SQL_INTEGER, &i, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(desc_short(ard, COL_BIGINT, SQL_DESC_TYPE), SQL_INTEGER);
}

/* A bound column can't be retrieved with GetData. */
UTEST_F(row, 6_30_get_data_bound_column) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLINTEGER i;

  ASSERT_EQ(SQLSetDescField(ard, COL_BIGINT, SQL_DESC_TYPE,
                            (SQLPOINTER)SQL_INTEGER, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetDescField(ard, COL_BIGINT, SQL_DESC_DATA_POINTER, &i, 0),
            SQL_SUCCESS);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_BIGINT, SQL_INTEGER, &i, 0, NULL),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07009");

  /* The columns before it can still be retrieved. */
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, COL_DOUBLE, SQL_INTEGER, &i, 0, NULL),
      SQL_SUCCESS);
}
