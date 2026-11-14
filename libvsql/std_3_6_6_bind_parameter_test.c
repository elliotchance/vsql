#include "test.h"

/* 6.6 BindParameter */

UTEST_F(db, 6_6_bind_parameter) {
  SQLINTEGER x = 0;
  char s[10] = "";
  SQLINTEGER len = SQL_NTS;

  ASSERT_EQ(
      run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT, s VARCHAR(5))"),
      SQL_SUCCESS);
  ASSERT_EQ(SQLPrepare(utest_fixture->stmt,
                       (SQLCHAR *)"INSERT INTO t (x, s) VALUES (?, ?)",
                       SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_INTEGER, 0, 0, &x, sizeof(x),
                             NULL),
            SQL_SUCCESS);
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 2, SQL_PARAM_MODE_IN,
                             SQL_CHAR, SQL_VARCHAR, 5, 0, s, sizeof(s), &len),
            SQL_SUCCESS);

  x = 1;
  strcpy(s, "a");
  EXPECT_EQ(SQLExecute(utest_fixture->stmt), SQL_SUCCESS);
  x = 2;
  strcpy(s, "bcd");
  EXPECT_EQ(SQLExecute(utest_fixture->stmt), SQL_SUCCESS);

  ASSERT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_RESET_PARAMS), SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT SUM(x), MAX(s) FROM t"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_INTEGER, &x, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(x, 3);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 2, SQL_CHAR, s, sizeof(s), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ(s, "bcd");
}

/* BindParameter sets the APD and the IPD. */
UTEST_F(db, 6_6_bind_parameter_descriptors) {
  SQLHDESC apd = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_PARAM_DESC);
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);
  SQLDOUBLE d;
  SQLINTEGER ind;
  SQLPOINTER p;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 2, SQL_PARAM_MODE_IN,
                             SQL_DOUBLE, SQL_NUMERIC, 10, 2, &d, sizeof(d),
                             &ind),
            SQL_SUCCESS);
  EXPECT_EQ(desc_short(apd, 0, SQL_DESC_COUNT), 2);
  EXPECT_EQ(desc_short(apd, 2, SQL_DESC_TYPE), SQL_DOUBLE);
  EXPECT_EQ(SQLGetDescField(apd, 2, SQL_DESC_DATA_POINTER, &p, 0, NULL),
            SQL_SUCCESS);
  EXPECT_TRUE(p == &d);
  EXPECT_EQ(SQLGetDescField(apd, 2, SQL_DESC_INDICATOR_POINTER, &p, 0, NULL),
            SQL_SUCCESS);
  EXPECT_TRUE(p == &ind);
  EXPECT_EQ(desc_short(ipd, 0, SQL_DESC_COUNT), 2);
  EXPECT_EQ(desc_short(ipd, 2, SQL_DESC_TYPE), SQL_NUMERIC);
  EXPECT_EQ(desc_short(ipd, 2, SQL_DESC_PRECISION), 10);
  EXPECT_EQ(desc_short(ipd, 2, SQL_DESC_SCALE), 2);
  EXPECT_EQ(desc_short(ipd, 2, SQL_DESC_PARAMETER_MODE), SQL_PARAM_MODE_IN);

  /* A datetime has the concise code's DATETIME_INTERVAL_CODE. */
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_CHAR, SQL_TYPE_TIMESTAMP, 26, 6, &d, 10, &ind),
            SQL_SUCCESS);
  EXPECT_EQ(desc_short(ipd, 1, SQL_DESC_TYPE), SQL_DATETIME);
  EXPECT_EQ(desc_short(ipd, 1, SQL_DESC_DATETIME_INTERVAL_CODE),
            SQL_CODE_TIMESTAMP);
  EXPECT_EQ(desc_short(ipd, 1, SQL_DESC_PRECISION), 6);
}

UTEST_F(db, 6_6_bind_parameter_invalid) {
  SQLINTEGER x;

  EXPECT_EQ(SQLBindParameter(utest_fixture->stmt, 0, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_INTEGER, 0, 0, &x, 4, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07009");
  EXPECT_EQ(SQLBindParameter(utest_fixture->stmt, 1, 3, SQL_INTEGER,
                             SQL_INTEGER, 0, 0, &x, 4, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY105");
  EXPECT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_NUMERIC, SQL_INTEGER, 0, 0, &x, 4, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY003");
  EXPECT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, 999, 0, 0, &x, 4, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY004");
  EXPECT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_INOUT,
                             SQL_INTEGER, SQL_INTEGER, 0, 0, &x, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY090");

  /* The descriptors are unchanged. */
  EXPECT_EQ(desc_short(stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_PARAM_DESC),
                       0, SQL_DESC_COUNT),
            0);
}

/* A NULL is given with SQL_NULL_DATA. */
UTEST_F(db, 6_6_bind_parameter_null) {
  SQLINTEGER x = 5, ind = SQL_NULL_DATA;
  SQLCHAR value[10];

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_INTEGER, 0, 0, &x, sizeof(x),
                             &ind),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS INTEGER) IS NULL"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, value, sizeof(value), NULL),
      SQL_SUCCESS);
  EXPECT_STREQ((char *)value, "TRUE");
}

/* The C value is cast to the ParameterType. */
UTEST_F(db, 6_6_bind_parameter_cast) {
  char s[] = "2026-10-26 12:34:56";
  char out[30];

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_CHAR, SQL_TYPE_DATE, 10, 0, s, sizeof(s),
                             NULL),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS DATE)"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "22007");

  s[10] = 0;
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS DATE)"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, out, sizeof(out), NULL),
      SQL_SUCCESS);
  EXPECT_STREQ(out, "DATE '2026-10-26'");
}

/* A number is out of range for a smaller ParameterType. */
UTEST_F(db, 6_6_bind_parameter_out_of_range) {
  SQLBIGINT x = 100000;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_BIGINT, SQL_SMALLINT, 0, 0, &x, sizeof(x),
                             NULL),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS SMALLINT)"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "22003");
}

/* A number can't be cast to a DATE. */
UTEST_F(db, 6_6_bind_parameter_restricted) {
  SQLINTEGER x = 1;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_TYPE_DATE, 10, 0, &x, sizeof(x),
                             NULL),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS DATE)"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07006");
}

/* The value is cast again to the type of the parameter, which must also be
 * allowed. */
UTEST_F(db, 6_6_bind_parameter_restricted_parameter_type) {
  SQLINTEGER x = 1, y = 0;
  char s[] = "2026-10-26";

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_CHAR, SQL_TYPE_DATE, 10, 0, s, sizeof(s),
                             NULL),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS INTEGER)"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07006");

  /* The IPD type can be different, as long as it can be cast. */
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_DOUBLE, 0, 0, &x, sizeof(x),
                             NULL),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS SMALLINT) + 1"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_INTEGER, &y, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(y, 2);
}

/* A string with a length in octets is the characters wholly contained in
 * them, so "é" (2 octets) with a length of 1 is a zero-length string. A string
 * that isn't valid UTF-8 can't be used. */
UTEST_F(db, 6_6_bind_parameter_partial_character) {
  char s[10] = "a\xc3\xa9";
  SQLINTEGER len = 2;
  char out[10];

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_CHAR, SQL_VARCHAR, 5, 0, s, sizeof(s), &len),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS VARCHAR(5))"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, out, sizeof(out), NULL),
      SQL_SUCCESS);
  EXPECT_STREQ(out, "a");
  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);

  strcpy(s, "\xc3\xa9");
  len = 1;
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES CHAR_LENGTH(?)"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, out, sizeof(out), NULL),
      SQL_SUCCESS);
  EXPECT_STREQ(out, "0");
  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);

  len = 2;
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS VARCHAR(5))"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, out, sizeof(out), NULL),
      SQL_SUCCESS);
  EXPECT_STREQ(out, "\xc3\xa9");
  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);

  strcpy(s, "a\xffz");
  len = 3;
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS VARCHAR(5))"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07001");

  /* A null terminated string can't end with part of a character. */
  strcpy(s, "a\xc3");
  len = SQL_NTS;
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS VARCHAR(5))"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07001");
}

/* TOP_LEVEL_COUNT is the same as COUNT, since nothing is nested. */
UTEST_F(db, 6_6_bind_parameter_top_level_count) {
  SQLINTEGER x;
  SQLHDESC apd = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_PARAM_DESC);
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);

  EXPECT_EQ(desc_short(apd, 0, SQL_DESC_TOP_LEVEL_COUNT), 0);
  EXPECT_EQ(desc_short(ipd, 0, SQL_DESC_TOP_LEVEL_COUNT), 0);
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 2, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_INTEGER, 0, 0, &x, 4, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(desc_short(apd, 0, SQL_DESC_TOP_LEVEL_COUNT), 2);
  EXPECT_EQ(desc_short(ipd, 0, SQL_DESC_TOP_LEVEL_COUNT), 2);

  ASSERT_EQ(SQLSetDescField(apd, 0, SQL_DESC_COUNT, SMALLINT_VALUE(1), 0),
            SQL_SUCCESS);
  EXPECT_EQ(desc_short(apd, 0, SQL_DESC_TOP_LEVEL_COUNT), 1);
}

/* ParameterType is checked against the concise codes in Table 37. */
UTEST_F(db, 6_6_bind_parameter_concise_types) {
  SQLINTEGER x;
  SQLSMALLINT invalid[] = {9, 10, 18, 31, 41, 51, 56};
  SQLSMALLINT unsupported[] = {17, 19, 20, 30, 40, 50, 55, 101, 113};
  size_t i;

  for (i = 0; i < sizeof(invalid) / sizeof(invalid[0]); i++) {
    EXPECT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                               SQL_INTEGER, invalid[i], 0, 0, &x, 4, NULL),
              SQL_ERROR);
    EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY004");
  }
  for (i = 0; i < sizeof(unsupported) / sizeof(unsupported[0]); i++) {
    EXPECT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                               SQL_INTEGER, unsupported[i], 0, 0, &x, 4, NULL),
              SQL_ERROR);
    EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HYC00");
  }
}
