#include "test.h"

/* 6.10 ColumnPrivileges */

/* There are no privileges, so valid arguments are an optional feature not
 * implemented. */
UTEST_F(db, 6_10_column_privileges) {
  EXPECT_EQ(SQLColumnPrivileges(utest_fixture->stmt, NULL, 0, NULL, 0,
                                (SQLCHAR *)"T", SQL_NTS, NULL, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HYC00");
  EXPECT_EQ(SQLColumnPrivileges(-1, NULL, 0, NULL, 0, NULL, 0, NULL, 0),
            SQL_INVALID_HANDLE);
}

UTEST_F(db, 6_10_column_privileges_invalid) {
  EXPECT_EQ(SQLColumnPrivileges(utest_fixture->stmt, NULL, 0, NULL, 0, NULL, 0,
                                NULL, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
  EXPECT_EQ(SQLColumnPrivileges(utest_fixture->stmt, NULL, 0, NULL, 0,
                                (SQLCHAR *)"T", SQL_NTS, (SQLCHAR *)"C", -5),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY090");
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLColumnPrivileges(utest_fixture->stmt, NULL, 0, NULL, 0,
                                (SQLCHAR *)"T", SQL_NTS, NULL, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

/* With the METADATA ID attribute, the catalog, schema and column names can't
 * be null pointers, which is checked before any length is read. */
UTEST_F(db, 6_10_column_privileges_metadata_id) {
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_METADATA_ID,
                           INTEGER_VALUE(SQL_TRUE), 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLColumnPrivileges(utest_fixture->stmt, (SQLCHAR *)"", -5,
                                (SQLCHAR *)"public", SQL_NTS, (SQLCHAR *)"T",
                                SQL_NTS, NULL, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
  EXPECT_EQ(SQLColumnPrivileges(utest_fixture->stmt, (SQLCHAR *)"", SQL_NTS,
                                (SQLCHAR *)"public", SQL_NTS, (SQLCHAR *)"T",
                                SQL_NTS, (SQLCHAR *)"C", SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HYC00");
}

UTEST_F(db, 6_10_column_privileges_implicit_set_connection) {
  SQLHDBC dbc2;
  SQLHSTMT stmt2;

  stmt2 = inactive_stmt(utest_fixture->env, utest_fixture->stmt, &dbc2);
  ASSERT_NE(stmt2, SQL_NULL_HANDLE);
  EXPECT_EQ(SQLColumnPrivileges(stmt2, NULL, 0, NULL, 0, NULL, 0, NULL, 0),
            SQL_ERROR);
  EXPECT_STRNE(sqlstate(SQL_HANDLE_STMT, stmt2), "0A001");
  free_inactive_stmt(utest_fixture->dbc, dbc2, stmt2);
}
