#include "test.h"

/* 6.40 GetParamData */

/* There's no CALL statement, so it's always a function sequence error, before
 * or after a statement is executed. */
UTEST_F(db, 6_40_get_param_data) {
  SQLINTEGER value, indicator;

  EXPECT_EQ(SQLGetParamData(utest_fixture->stmt, 1, SQL_INTEGER, &value, 0,
                            &indicator),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLGetParamData(utest_fixture->stmt, 1, SQL_INTEGER, &value, 0,
                            &indicator),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
  EXPECT_EQ(SQLGetParamData(-1, 1, SQL_INTEGER, &value, 0, &indicator),
            SQL_INVALID_HANDLE);
}

UTEST_F(db, 6_40_get_param_data_implicit_set_connection) {
  SQLHDBC dbc2;
  SQLHSTMT stmt2;
  SQLINTEGER value, indicator;

  stmt2 = inactive_stmt(utest_fixture->env, utest_fixture->stmt, &dbc2);
  ASSERT_NE(stmt2, SQL_NULL_HANDLE);
  EXPECT_EQ(SQLGetParamData(stmt2, 1, SQL_INTEGER, &value, 0, &indicator),
            SQL_ERROR);
  EXPECT_STRNE(sqlstate(SQL_HANDLE_STMT, stmt2), "0A001");
  free_inactive_stmt(utest_fixture->dbc, dbc2, stmt2);
}
