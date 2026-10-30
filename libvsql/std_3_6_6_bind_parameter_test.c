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
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES ? IS NULL"), SQL_SUCCESS);
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
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES ?"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "22007");

  s[10] = 0;
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES ?"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, out, sizeof(out), NULL),
      SQL_SUCCESS);
  EXPECT_STREQ(out, "2026-10-26");
}

/* A number is out of range for a smaller ParameterType. */
UTEST_F(db, 6_6_bind_parameter_out_of_range) {
  SQLBIGINT x = 100000;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_BIGINT, SQL_SMALLINT, 0, 0, &x, sizeof(x),
                             NULL),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES ?"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "22003");
}

/* A number can't be cast to a DATE. */
UTEST_F(db, 6_6_bind_parameter_restricted) {
  SQLINTEGER x = 1;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_TYPE_DATE, 10, 0, &x, sizeof(x),
                             NULL),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES ?"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07006");
}
