#include "test.h"

/* 6.46 MoreResults */

/* A query has only one result set, which is closed. */
UTEST_F(db, 6_46_more_results) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLMoreResults(utest_fixture->stmt), SQL_NO_DATA);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "02001");
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

UTEST_F(db, 6_46_more_results_not_executed) {
  EXPECT_EQ(SQLMoreResults(utest_fixture->stmt), SQL_NO_DATA);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "02001");
}

UTEST_F(db, 6_46_more_results_not_a_query) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLMoreResults(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}
