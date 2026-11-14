#include "test.h"

/* 6.44 GetSubString */

/* There are no large object locators, so a locator is never valid. */
UTEST_F(db, 6_44_get_sub_string) {
  SQLCHAR value[32];
  SQLINTEGER length, indicator;

  EXPECT_EQ(SQLGetSubString(utest_fixture->stmt, SQL_CLOB_LOCATOR, 1, 1, 1,
                            SQL_CHAR, value, sizeof(value), &length,
                            &indicator),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "0F001");
  EXPECT_EQ(SQLGetSubString(utest_fixture->stmt, SQL_BLOB_LOCATOR, 1, 1, 1,
                            SQL_CHAR, value, sizeof(value), &length,
                            &indicator),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "0F001");
  EXPECT_EQ(SQLGetSubString(-1, SQL_CLOB_LOCATOR, 1, 1, 1, SQL_CHAR, value,
                            sizeof(value), &length, &indicator),
            SQL_INVALID_HANDLE);
}

UTEST_F(db, 6_44_get_sub_string_invalid_locator_type) {
  SQLCHAR value[32];
  SQLINTEGER length, indicator;

  EXPECT_EQ(SQLGetSubString(utest_fixture->stmt, SQL_CHAR, 1, 1, 1, SQL_CHAR,
                            value, sizeof(value), &length, &indicator),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY024");
}

/* The statement handle can't have a prepared or executed statement. */
UTEST_F(db, 6_44_get_sub_string_prepared) {
  SQLCHAR value[32];
  SQLINTEGER length, indicator;

  ASSERT_EQ(SQLPrepare(utest_fixture->stmt, (SQLCHAR *)"VALUES 1", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetSubString(utest_fixture->stmt, SQL_CHAR, 1, 1, 1, SQL_CHAR,
                            value, sizeof(value), &length, &indicator),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLGetSubString(utest_fixture->stmt, SQL_CLOB_LOCATOR, 1, 1, 1,
                            SQL_CHAR, value, sizeof(value), &length,
                            &indicator),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

UTEST_F(db, 6_44_get_sub_string_implicit_set_connection) {
  SQLHDBC dbc2;
  SQLHSTMT stmt2;
  SQLCHAR value[32];
  SQLINTEGER length, indicator;

  stmt2 = inactive_stmt(utest_fixture->env, utest_fixture->stmt, &dbc2);
  ASSERT_NE(stmt2, SQL_NULL_HANDLE);
  EXPECT_EQ(SQLGetSubString(stmt2, SQL_CHAR, 1, 1, 1, SQL_CHAR, value,
                            sizeof(value), &length, &indicator),
            SQL_ERROR);
  EXPECT_STRNE(sqlstate(SQL_HANDLE_STMT, stmt2), "0A001");
  free_inactive_stmt(utest_fixture->dbc, dbc2, stmt2);
}
