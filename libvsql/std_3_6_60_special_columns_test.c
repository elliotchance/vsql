#include "test.h"

/* 6.60 SpecialColumns */

UTEST_F(db, 6_60_special_columns) {
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE t (a INT, b VARCHAR(10), c INT, PRIMARY KEY "
                    "(b, a))"),
            SQL_SUCCESS);

#define SPECIAL(column, scope)                                                 \
  (SQLSpecialColumns(utest_fixture->stmt, SQL_BEST_ROWID, NULL, 0, NULL, 0,    \
                     (SQLCHAR *)"T", SQL_NTS, scope,                           \
                     SQL_NO_NULLS) == SQL_SUCCESS                              \
       ? fetch_strings(utest_fixture->stmt, column)                            \
       : "(error)")

  EXPECT_STREQ(SPECIAL(1, SQL_SCOPE_CURROW), "2,2");
  EXPECT_STREQ(SPECIAL(2, SQL_SCOPE_CURROW), "B,A");
  EXPECT_STREQ(SPECIAL(3, SQL_SCOPE_CURROW), "12,4");
  EXPECT_STREQ(SPECIAL(4, SQL_SCOPE_CURROW), "CHARACTER VARYING,INTEGER");
  EXPECT_STREQ(SPECIAL(5, SQL_SCOPE_CURROW), "10,10");
  EXPECT_STREQ(SPECIAL(8, SQL_SCOPE_CURROW), "1,1");
  EXPECT_STREQ(SPECIAL(2, SQL_SCOPE_SESSION), "B,A");
#undef SPECIAL
}

UTEST_F(db, 6_60_special_columns_no_key) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (a INT UNIQUE)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSpecialColumns(utest_fixture->stmt, SQL_BEST_ROWID, NULL, 0,
                              NULL, 0, (SQLCHAR *)"T", SQL_NTS,
                              SQL_SCOPE_CURROW, SQL_NULLABLE),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 2), "");
}

UTEST_F(db, 6_60_special_columns_invalid) {
  EXPECT_EQ(SQLSpecialColumns(utest_fixture->stmt, 2, NULL, 0, NULL, 0,
                              (SQLCHAR *)"T", SQL_NTS, SQL_SCOPE_CURROW,
                              SQL_NULLABLE),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY097");
  EXPECT_EQ(SQLSpecialColumns(utest_fixture->stmt, SQL_BEST_ROWID, NULL, 0,
                              NULL, 0, (SQLCHAR *)"T", SQL_NTS, 3,
                              SQL_NULLABLE),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY098");
  EXPECT_EQ(SQLSpecialColumns(utest_fixture->stmt, SQL_BEST_ROWID, NULL, 0,
                              NULL, 0, (SQLCHAR *)"T", SQL_NTS,
                              SQL_SCOPE_CURROW, 2),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY099");
  EXPECT_EQ(SQLSpecialColumns(utest_fixture->stmt, SQL_BEST_ROWID, NULL, 0,
                              NULL, 0, NULL, 0, SQL_SCOPE_CURROW, SQL_NULLABLE),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
}
