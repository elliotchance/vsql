#include "test.h"

/* 6.52 PutData */

/* A number can't be given in pieces. */
UTEST_F(db, 6_52_put_data_pieces) {
  SQLINTEGER at_exec = SQL_DATA_AT_EXEC, x = 1;
  SQLPOINTER p;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_INTEGER, 0, 0, &x, sizeof(x),
                             &at_exec),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES ?"), SQL_NEED_DATA);
  ASSERT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_NEED_DATA);
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, &x, 0), SQL_SUCCESS);
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, &x, 0), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY019");
}

/* A NULL can be given, but not in pieces. */
UTEST_F(db, 6_52_put_data_null) {
  SQLINTEGER at_exec = SQL_DATA_AT_EXEC;
  char s[10];
  SQLPOINTER p;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_CHAR, SQL_VARCHAR, 10, 0, s, sizeof(s),
                             &at_exec),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES ? IS NULL"), SQL_NEED_DATA);
  ASSERT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_NEED_DATA);
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, NULL, SQL_NULL_DATA), SQL_SUCCESS);
  EXPECT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, s, sizeof(s), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ(s, "TRUE");
  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES ? IS NULL"), SQL_NEED_DATA);
  ASSERT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_NEED_DATA);
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, (SQLPOINTER) "a", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, NULL, SQL_NULL_DATA), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY020");
  EXPECT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

UTEST_F(db, 6_52_put_data_not_deferred) {
  SQLINTEGER x = 1;

  EXPECT_EQ(SQLPutData(utest_fixture->stmt, &x, 0), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

/* A piece can end with part of a character that the next piece completes,
 * but a string that isn't valid UTF-8 can't be given. */
UTEST_F(db, 6_52_put_data_partial_character) {
  SQLINTEGER at_exec = SQL_DATA_AT_EXEC;
  char s[10];
  SQLPOINTER p;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_CHAR, SQL_VARCHAR, 10, 0, s, sizeof(s),
                             &at_exec),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES ?"), SQL_NEED_DATA);
  ASSERT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_NEED_DATA);
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, (SQLPOINTER) "a\xc3", 2),
            SQL_SUCCESS);
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, (SQLPOINTER) "\xa9", 1),
            SQL_SUCCESS);
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, (SQLPOINTER) "\xff", 1), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07001");
  EXPECT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, s, sizeof(s), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ(s, "a\xc3\xa9");
  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES ?"), SQL_NEED_DATA);
  ASSERT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_NEED_DATA);
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, (SQLPOINTER) "\xff", 1), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07001");
}
