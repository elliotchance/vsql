#include "test.h"

/*
 * DECFLOAT isn't in SQL/CLI 2003, so its code is SQL_DECFLOAT (26), which is
 * the code of a DECFLOAT in dynamic SQL (Table 30 of Part 2). Its PRECISION is
 * in decimal digits, and is 16 or 34.
 */

UTEST_F(db, decfloat_describe_col) {
  struct column col;
  SQLHDESC ird;

  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE t (a DECFLOAT(16), b DECFLOAT)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT a, b FROM t"), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 1, &col), SQL_SUCCESS);
  EXPECT_EQ(col.type, SQL_DECFLOAT);
  EXPECT_EQ(col.size, 16);
  EXPECT_EQ(col.digits, 0);
  EXPECT_EQ(describe(utest_fixture->stmt, 2, &col), SQL_SUCCESS);
  EXPECT_EQ(col.type, SQL_DECFLOAT);
  EXPECT_EQ(col.size, 34);

  ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);
  EXPECT_EQ(desc_short(ird, 1, SQL_DESC_TYPE), SQL_DECFLOAT);
  EXPECT_EQ(desc_short(ird, 1, SQL_DESC_PRECISION), 16);
  EXPECT_EQ(desc_short(ird, 2, SQL_DESC_PRECISION), 34);
}

UTEST_F(db, decfloat_get_data) {
  SQLCHAR s[50];
  SQLDOUBLE d = 0;

  ASSERT_EQ(
      run_sql(utest_fixture->stmt,
              "SELECT CAST(1.25 AS DECFLOAT(16)) FROM (VALUES 1) AS t (x)"),
      SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, s, sizeof(s), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)s, "1.25");
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_DOUBLE, &d, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(d, 1.25);
}

UTEST_F(db, decfloat_bind_parameter) {
  SQLCHAR s[50];

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_CHAR, SQL_DECFLOAT, 16, 0, (SQLPOINTER) "1.5",
                             0, NULL),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "SELECT CAST(? AS DECFLOAT) + 1 FROM (VALUES 1) AS t (x)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, s, sizeof(s), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)s, "2.5");
}

UTEST_F(db, decfloat_ipd_type) {
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);

  /* Setting TYPE sets the default PRECISION, which is 34. */
  ASSERT_EQ(
      SQLSetDescField(ipd, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_DECFLOAT), 0),
      SQL_SUCCESS);
  EXPECT_EQ(desc_short(ipd, 1, SQL_DESC_PRECISION), 34);

  /* The PRECISION must be 16 or 34 when the DATA_POINTER is set. */
  ASSERT_EQ(SQLSetDescField(ipd, 1, SQL_DESC_PRECISION, SMALLINT_VALUE(16), 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLSetDescField(ipd, 1, SQL_DESC_DATA_POINTER, (SQLPOINTER) "1", 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetDescField(ipd, 1, SQL_DESC_PRECISION, SMALLINT_VALUE(20), 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLSetDescField(ipd, 1, SQL_DESC_DATA_POINTER, (SQLPOINTER) "1", 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ipd, "HY021");
}
