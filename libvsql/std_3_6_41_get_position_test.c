#include "test.h"

/* 6.41 GetPosition */

/* There are no large object locators, so a locator is never valid. */
UTEST_F(db, 6_41_get_position) {
  SQLINTEGER located_at, indicator;

  EXPECT_EQ(SQLGetPosition(utest_fixture->stmt, SQL_CLOB_LOCATOR, 1, 0,
                           (SQLCHAR *)"a", 1, 1, &located_at, &indicator),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "0F001");
  EXPECT_EQ(SQLGetPosition(utest_fixture->stmt, SQL_BLOB_LOCATOR, 1, 2, NULL, 0,
                           1, &located_at, &indicator),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "0F001");
  EXPECT_EQ(SQLGetPosition(-1, SQL_CLOB_LOCATOR, 1, 0, (SQLCHAR *)"a", 1, 1,
                           &located_at, &indicator),
            SQL_INVALID_HANDLE);
}

/* Unlike GetLength and GetSubString, it's an invalid attribute identifier. */
UTEST_F(db, 6_41_get_position_invalid_locator_type) {
  SQLINTEGER located_at, indicator;

  EXPECT_EQ(SQLGetPosition(utest_fixture->stmt, SQL_CHAR, 1, 0, (SQLCHAR *)"a",
                           1, 1, &located_at, &indicator),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY092");
}

/* The statement handle can't have a prepared or executed statement. */
UTEST_F(db, 6_41_get_position_prepared) {
  SQLINTEGER located_at, indicator;

  ASSERT_EQ(SQLPrepare(utest_fixture->stmt, (SQLCHAR *)"VALUES 1", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetPosition(utest_fixture->stmt, SQL_CHAR, 1, 0, (SQLCHAR *)"a",
                           1, 1, &located_at, &indicator),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLGetPosition(utest_fixture->stmt, SQL_CLOB_LOCATOR, 1, 0,
                           (SQLCHAR *)"a", 1, 1, &located_at, &indicator),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

UTEST_F(db, 6_41_get_position_implicit_set_connection) {
  SQLHDBC dbc2;
  SQLHSTMT stmt2;
  SQLINTEGER located_at, indicator;

  stmt2 = inactive_stmt(utest_fixture->env, utest_fixture->stmt, &dbc2);
  ASSERT_NE(stmt2, SQL_NULL_HANDLE);
  EXPECT_EQ(SQLGetPosition(stmt2, SQL_CHAR, 1, 0, (SQLCHAR *)"a", 1, 1,
                           &located_at, &indicator),
            SQL_ERROR);
  EXPECT_STRNE(sqlstate(SQL_HANDLE_STMT, stmt2), "0A001");
  free_inactive_stmt(utest_fixture->dbc, dbc2, stmt2);
}
