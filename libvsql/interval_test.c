#include "test.h"

/*
 * An interval is SQL_INTERVAL (10) in a descriptor, with its
 * DATETIME_INTERVAL_CODE (SQL_CODE_YEAR, ...) and DATETIME_INTERVAL_PRECISION
 * (the leading field precision). Its concise code (such as the DataType of
 * SQLDescribeCol) is SQL_INTERVAL_YEAR, ... There's no C data type for an
 * interval, so it's retrieved (and bound) as a character string.
 */

UTEST_F(db, interval_describe_col) {
  struct column col;
  SQLHDESC ird;
  SQLINTEGER n = 0;

  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE t (a INTERVAL YEAR TO MONTH, b INTERVAL "
                    "DAY(3) TO SECOND(2), c INTERVAL MINUTE(4), d INTERVAL "
                    "SECOND(2, 0))"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT a, b, c, d FROM t"),
            SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 1, &col), SQL_SUCCESS);
  EXPECT_EQ(col.type, SQL_INTERVAL_YEAR_TO_MONTH);
  EXPECT_EQ(col.size, 6);
  EXPECT_EQ(col.digits, 0);
  EXPECT_EQ(describe(utest_fixture->stmt, 2, &col), SQL_SUCCESS);
  EXPECT_EQ(col.type, SQL_INTERVAL_DAY_TO_SECOND);
  EXPECT_EQ(col.size, 16);
  EXPECT_EQ(col.digits, 2);
  EXPECT_EQ(describe(utest_fixture->stmt, 3, &col), SQL_SUCCESS);
  EXPECT_EQ(col.type, SQL_INTERVAL_MINUTE);
  EXPECT_EQ(col.size, 5);
  EXPECT_EQ(describe(utest_fixture->stmt, 4, &col), SQL_SUCCESS);
  EXPECT_EQ(col.type, SQL_INTERVAL_SECOND);
  EXPECT_EQ(col.size, 3);
  EXPECT_EQ(SQLColAttribute(utest_fixture->stmt, 2, SQL_DESC_TYPE, NULL, 0,
                            NULL, &n),
            SQL_SUCCESS);
  EXPECT_EQ(n, SQL_INTERVAL_DAY_TO_SECOND);

  ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);
  EXPECT_EQ(desc_short(ird, 1, SQL_DESC_TYPE), SQL_INTERVAL);
  EXPECT_EQ(desc_short(ird, 1, SQL_DESC_DATETIME_INTERVAL_CODE),
            SQL_CODE_YEAR_TO_MONTH);
  EXPECT_EQ(desc_int(ird, 1, SQL_DESC_DATETIME_INTERVAL_PRECISION), 2);
  EXPECT_EQ(desc_int(ird, 1, SQL_DESC_LENGTH), 6);
  EXPECT_EQ(desc_short(ird, 2, SQL_DESC_DATETIME_INTERVAL_CODE),
            SQL_CODE_DAY_TO_SECOND);
  EXPECT_EQ(desc_int(ird, 2, SQL_DESC_DATETIME_INTERVAL_PRECISION), 3);
  EXPECT_EQ(desc_short(ird, 2, SQL_DESC_PRECISION), 2);
}

/* An interval is retrieved as its literal, and only as a character string. */
UTEST_F(db, interval_get_data) {
  char s[50];
  SQLINTEGER n = 0;

  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "VALUES (INTERVAL '1-2' YEAR TO MONTH, INTERVAL -'3' DAY)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, s, sizeof(s), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ(s, "INTERVAL '1-02' YEAR(2) TO MONTH");
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 2, SQL_CHAR, s, sizeof(s), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ(s, "INTERVAL '-3' DAY(2)");

  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_INTEGER, &n, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07006");
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_DEFAULT, s, sizeof(s), NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07002");
}

/* The leading field precision of an interval parameter is what's left of its
 * length in positions (ColumnSize), after its other fields, its fractional
 * seconds (DecimalDigits and a period) and its sign (if the value has one). */
UTEST_F(db, interval_bind_parameter) {
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);
  char s[50];

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_CHAR, SQL_INTERVAL_DAY_TO_SECOND, 15, 2,
                             (SQLPOINTER) "3 04:05:06.7", 50, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(desc_short(ipd, 1, SQL_DESC_TYPE), SQL_INTERVAL);
  EXPECT_EQ(desc_short(ipd, 1, SQL_DESC_DATETIME_INTERVAL_CODE),
            SQL_CODE_DAY_TO_SECOND);
  EXPECT_EQ(desc_int(ipd, 1, SQL_DESC_LENGTH), 15);
  EXPECT_EQ(desc_short(ipd, 1, SQL_DESC_PRECISION), 2);
  EXPECT_EQ(desc_int(ipd, 1, SQL_DESC_DATETIME_INTERVAL_PRECISION), 3);
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 2, SQL_PARAM_MODE_IN,
                             SQL_CHAR, SQL_INTERVAL_YEAR, 3, 0,
                             (SQLPOINTER) "-12", 50, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(desc_int(ipd, 2, SQL_DESC_DATETIME_INTERVAL_PRECISION), 2);
  EXPECT_EQ(desc_short(ipd, 2, SQL_DESC_PRECISION), 0);

  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "VALUES (CAST(? AS INTERVAL DAY(3) TO SECOND(2)), CAST(? "
                    "AS INTERVAL YEAR))"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, s, sizeof(s), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ(s, "INTERVAL '3 04:05:06.70' DAY(3) TO SECOND(2)");
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 2, SQL_CHAR, s, sizeof(s), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ(s, "INTERVAL '-12' YEAR(2)");
  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);

  /* A number can't be an interval. */
  ASSERT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_UNBIND_PARAMETERS),
            SQL_SUCCESS);
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_INTERVAL_YEAR, 3, 0,
                             INTEGER_VALUE(1), 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS INTERVAL YEAR)"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07006");
}

UTEST_F(db, interval_set_desc_field) {
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);
  SQLHDESC apd = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_PARAM_DESC);

  /* Setting TYPE sets the leading field precision to 2. */
  ASSERT_EQ(
      SQLSetDescField(ipd, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_INTERVAL), 0),
      SQL_SUCCESS);
  EXPECT_EQ(desc_int(ipd, 1, SQL_DESC_DATETIME_INTERVAL_PRECISION), 2);

  /* Setting the DATETIME_INTERVAL_CODE sets the PRECISION to 6 if it has
   * seconds, otherwise 0 (zero). */
  ASSERT_EQ(SQLSetDescField(ipd, 1, SQL_DESC_DATETIME_INTERVAL_PRECISION,
                            INTEGER_VALUE(5), 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetDescField(ipd, 1, SQL_DESC_DATETIME_INTERVAL_CODE,
                            SMALLINT_VALUE(SQL_CODE_HOUR_TO_SECOND), 0),
            SQL_SUCCESS);
  EXPECT_EQ(desc_int(ipd, 1, SQL_DESC_DATETIME_INTERVAL_PRECISION), 2);
  EXPECT_EQ(desc_short(ipd, 1, SQL_DESC_PRECISION), 6);
  ASSERT_EQ(SQLSetDescField(ipd, 1, SQL_DESC_DATETIME_INTERVAL_CODE,
                            SMALLINT_VALUE(SQL_CODE_MONTH), 0),
            SQL_SUCCESS);
  EXPECT_EQ(desc_short(ipd, 1, SQL_DESC_PRECISION), 0);

  /* The leading field precision must be 1 to 8 when the DATA_POINTER is
   * set. */
  ASSERT_EQ(SQLSetDescField(ipd, 1, SQL_DESC_DATETIME_INTERVAL_PRECISION,
                            INTEGER_VALUE(9), 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLSetDescField(ipd, 1, SQL_DESC_DATA_POINTER, (SQLPOINTER) "1", 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ipd, "HY021");

  /* An interval isn't an application data type. */
  EXPECT_EQ(
      SQLSetDescField(apd, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_INTERVAL), 0),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, apd, "HY004");
}

UTEST_F(db, interval_columns) {
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE t (a INTERVAL YEAR(3) TO MONTH, b INTERVAL "
                    "HOUR TO SECOND(3), c INTERVAL DAY)"),
            SQL_SUCCESS);

#define COLUMNS(column)                                                        \
  (SQLColumns(utest_fixture->stmt, NULL, 0, NULL, 0, (SQLCHAR *)"T", SQL_NTS,  \
              NULL, 0) == SQL_SUCCESS                                          \
       ? fetch_strings(utest_fixture->stmt, column)                            \
       : "(error)")

  EXPECT_STREQ(COLUMNS(5), "107,112,103");
  EXPECT_STREQ(COLUMNS(6), "INTERVAL,INTERVAL,INTERVAL");
  EXPECT_STREQ(COLUMNS(7), "7,13,3");
  EXPECT_STREQ(COLUMNS(9), "0,3,0");
  EXPECT_STREQ(COLUMNS(14), "10,10,10");
  EXPECT_STREQ(COLUMNS(15), "7,12,3");
#undef COLUMNS
}

UTEST_F(db, interval_get_type_info) {
  ASSERT_EQ(SQLGetTypeInfo(utest_fixture->stmt, SQL_INTERVAL_DAY_TO_SECOND),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 1), "INTERVAL DAY TO SECOND");
  ASSERT_EQ(SQLGetTypeInfo(utest_fixture->stmt, SQL_INTERVAL_DAY_TO_SECOND),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 3), "25");
  ASSERT_EQ(SQLGetTypeInfo(utest_fixture->stmt, SQL_INTERVAL_DAY_TO_SECOND),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 5), "' DAY TO SECOND");
  ASSERT_EQ(SQLGetTypeInfo(utest_fixture->stmt, SQL_INTERVAL_YEAR),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 16), "10");
  ASSERT_EQ(SQLGetTypeInfo(utest_fixture->stmt, SQL_INTERVAL_YEAR),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 17), "1");
  ASSERT_EQ(SQLGetTypeInfo(utest_fixture->stmt, SQL_INTERVAL_YEAR),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 19), "8");
}

UTEST_F(db, interval_special_columns) {
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE t (a INTERVAL DAY(3) TO SECOND(1) PRIMARY "
                    "KEY)"),
            SQL_SUCCESS);

#define SPECIAL(column)                                                        \
  (SQLSpecialColumns(utest_fixture->stmt, SQL_BEST_ROWID, NULL, 0, NULL, 0,    \
                     (SQLCHAR *)"T", SQL_NTS, SQL_SCOPE_CURROW,                \
                     SQL_NO_NULLS) == SQL_SUCCESS                              \
       ? fetch_strings(utest_fixture->stmt, column)                            \
       : "(error)")

  EXPECT_STREQ(SPECIAL(3), "110");
  EXPECT_STREQ(SPECIAL(5), "15");
#undef SPECIAL
}

/* The IPD of a dynamic parameter has the interval type of the column. */
UTEST_F(db, interval_prepare) {
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);

  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE t (a INTERVAL HOUR(4) TO MINUTE)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLPrepare(utest_fixture->stmt,
                       (SQLCHAR *)"INSERT INTO t (a) VALUES (?)", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(desc_short(ipd, 1, SQL_DESC_TYPE), SQL_INTERVAL);
  EXPECT_EQ(desc_short(ipd, 1, SQL_DESC_DATETIME_INTERVAL_CODE),
            SQL_CODE_HOUR_TO_MINUTE);
  EXPECT_EQ(desc_int(ipd, 1, SQL_DESC_DATETIME_INTERVAL_PRECISION), 4);
  EXPECT_EQ(desc_int(ipd, 1, SQL_DESC_LENGTH), 8);
}
