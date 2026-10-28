#include "test.h"

/* 6.49 ParamData */

UTEST_F(db, 6_49_param_data) {
  SQLINTEGER at_exec = SQL_DATA_AT_EXEC, x = 3, n = 0;
  char s[20];
  SQLPOINTER p = NULL;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_CHAR, SQL_VARCHAR, 20, 0, s, sizeof(s),
                             &at_exec),
            SQL_SUCCESS);
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 2, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_INTEGER, 0, 0, &x, sizeof(x),
                             NULL),
            SQL_SUCCESS);
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 3, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_INTEGER, 0, 0, &n, sizeof(n),
                             &at_exec),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES ROW(?, ? + ?)"),
            SQL_NEED_DATA);

  EXPECT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_NEED_DATA);
  EXPECT_TRUE(p == s);
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, (SQLPOINTER) "hello", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, (SQLPOINTER) " worldXYZ", 6),
            SQL_SUCCESS);

  EXPECT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_NEED_DATA);
  EXPECT_TRUE(p == &n);
  n = 10;
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, &n, 0), SQL_SUCCESS);

  EXPECT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, s, sizeof(s), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ(s, "hello world");
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 2, SQL_INTEGER, &x, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(x, 13);
}

UTEST_F(db, 6_49_param_data_not_deferred) {
  SQLPOINTER p;

  EXPECT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

/* While a parameter is deferred, the other statement routines can't be
 * used, until it's cancelled. */
UTEST_F(db, 6_49_param_data_sequence) {
  SQLINTEGER at_exec = SQL_DATA_AT_EXEC, x;
  SQLPOINTER p;
  SQLSMALLINT n;
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_INTEGER, 0, 0, &x, sizeof(x),
                             &at_exec),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES ?"), SQL_NEED_DATA);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
  EXPECT_EQ(SQLNumResultCols(utest_fixture->stmt, &n), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_STMT, utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY010");
  EXPECT_EQ(SQLGetDescField(ipd, 1, SQL_DESC_TYPE, &n, 0, NULL), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ipd, "HY010");

  /* PutData needs ParamData first. */
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, &x, 0), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
  EXPECT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_NEED_DATA);
  EXPECT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");

  /* An error ends the statement. */
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
}

UTEST_F(db, 6_49_param_data_cancel) {
  SQLINTEGER at_exec = SQL_DATA_AT_EXEC, x;
  SQLPOINTER p;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_INTEGER, 0, 0, &x, sizeof(x),
                             &at_exec),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES ?"), SQL_NEED_DATA);
  EXPECT_EQ(SQLCancel(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
}
