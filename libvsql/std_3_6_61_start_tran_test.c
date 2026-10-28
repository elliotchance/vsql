#include "test.h"

/* 6.61 StartTran */

UTEST_F(db, 6_61_start_tran) {
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_SUCCESS);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_TRANSACTION_ACTIVE),
      1);
}

/* READ UNCOMMITTED is satisfied by READ COMMITTED. */
UTEST_F(db, 6_61_start_tran_read_uncommitted) {
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_ENV, utest_fixture->env,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_UNCOMMITTED),
            SQL_SUCCESS);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_TRANSACTION_ACTIVE),
      1);
}

UTEST_F(db, 6_61_start_tran_active) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "25001");
}

UTEST_F(db, 6_61_start_tran_not_supported) {
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                         SQL_TRANSACTION_READ_ONLY,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HYC00");
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_SERIALIZABLE),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HYC00");
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_REPEATABLE_READ),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HYC00");
}

UTEST_F(db, 6_61_start_tran_invalid) {
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, utest_fixture->dbc, 3,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY092");
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                         SQL_TRANSACTION_READ_WRITE, 3),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY092");
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_STMT, utest_fixture->stmt,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY092");
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, utest_fixture->env,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_INVALID_HANDLE);
}

UTEST_F(env, 6_61_start_tran_not_connected) {
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "08003");

  /* An environment without established connections has nothing to start. */
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_ENV, utest_fixture->env,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_SUCCESS);
}
