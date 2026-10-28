#include "test.h"

/* 6.8 CloseCursor */

UTEST_F(db, 6_8_close_cursor) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
}

UTEST_F(db, 6_8_close_cursor_no_statement) {
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

UTEST_F(db, 6_8_close_cursor_not_a_query) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

UTEST_F(db, 6_8_close_cursor_already_closed) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

UTEST_F(db, 6_8_close_cursor_then_fetch) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

UTEST_F(db, 6_8_close_cursor_invalid_handle) {
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt + 1000), SQL_INVALID_HANDLE);
}
