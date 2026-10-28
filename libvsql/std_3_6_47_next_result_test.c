#include "test.h"

/* 6.47 NextResult */

UTEST_F(db, 6_47_next_result) {
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  EXPECT_EQ(SQLNextResult(utest_fixture->stmt, stmt2), SQL_NO_DATA);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLNextResult(utest_fixture->stmt, stmt2), SQL_NO_DATA);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "02001");

  /* The first cursor stays open. */
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);

  ASSERT_EQ(SQLPrepare(stmt2, (SQLCHAR *)"VALUES 2", SQL_NTS), SQL_SUCCESS);
  EXPECT_EQ(SQLNextResult(utest_fixture->stmt, stmt2), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
  EXPECT_EQ(SQLNextResult(utest_fixture->stmt, utest_fixture->dbc),
            SQL_INVALID_HANDLE);
}
