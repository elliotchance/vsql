#include "test.h"

/* 6.42 GetSessionInfo, General Rules, 3 */

#define ACTIVE(dbc) diag_int(SQL_HANDLE_DBC, dbc, SQL_DIAG_TRANSACTION_ACTIVE)

/* Implicit set connection is applied before the InfoType is checked and the
 * value is selected, and after checking that the connection is established. */
UTEST_F(db, 6_42_get_session_info_implicit_set_connection) {
  SQLHDBC dbc2, dbc3;
  SQLCHAR value[32];

  ASSERT_EQ(SQLAllocConnect(utest_fixture->env, &dbc2), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocConnect(utest_fixture->env, &dbc3), SQL_SUCCESS);
  ASSERT_EQ(connect_memory(dbc2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);

  /* The first connection has an active transaction, so the second one can't
   * become current. */
  EXPECT_EQ(SQLGetSessionInfo(dbc2, SQL_CURRENT_USER, value, sizeof(value),
                              NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, dbc2, "0A001");
  EXPECT_EQ(SQLGetSessionInfo(dbc2, 123, value, sizeof(value), NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, dbc2, "0A001");
  EXPECT_EQ(SQLGetSessionInfo(dbc3, SQL_CURRENT_USER, value, sizeof(value),
                              NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, dbc3, "08003");

  /* Failing to switch leaves the first connection current. */
  EXPECT_EQ(ACTIVE(utest_fixture->dbc), 1);
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);

  /* After the transaction ends, the second connection can become current. */
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetSessionInfo(dbc2, SQL_CURRENT_USER, value, sizeof(value),
                              NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, dbc2, "42601");
  EXPECT_EQ(ACTIVE(dbc2), 0);

  EXPECT_EQ(SQLDisconnect(dbc2), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeConnect(dbc3), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeConnect(dbc2), SQL_SUCCESS);
}
