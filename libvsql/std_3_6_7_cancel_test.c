#include "test.h"

/* 6.7 Cancel */

/* With nothing to cancel, Cancel only empties the diagnostics area. */
UTEST_F(db, 6_7_cancel) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM bar"), SQL_ERROR);
  EXPECT_EQ(SQLCancel(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_STREQ(sqlstate(SQL_HANDLE_STMT, utest_fixture->stmt), "");
}

/* The cursor stays open. */
UTEST_F(db, 6_7_cancel_open_cursor) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLCancel(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
}

UTEST_F(db, 6_7_cancel_invalid_handle) {
  EXPECT_EQ(SQLCancel(utest_fixture->dbc), SQL_INVALID_HANDLE);
}
