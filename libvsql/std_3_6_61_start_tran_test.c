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

/* READ UNCOMMITTED is satisfied by READ COMMITTED, and it's always READ ONLY. */
UTEST_F(db, 6_61_start_tran_read_uncommitted) {
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_ENV, utest_fixture->env,
                         SQL_TRANSACTION_READ_ONLY,
                         SQL_TRANSACTION_READ_UNCOMMITTED),
            SQL_SUCCESS);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_TRANSACTION_ACTIVE),
      1);
}

UTEST_F(db, 6_61_start_tran_read_uncommitted_read_write) {
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_UNCOMMITTED),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "42601");
}

UTEST_F(db, 6_61_start_tran_active) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "25001");
}

/* A READ ONLY transaction can't change the database, and chaining keeps it. */
UTEST_F(db, 6_61_start_tran_read_only) {
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                         SQL_TRANSACTION_READ_ONLY,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "25006");
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT_AND_CHAIN),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "25006");
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
}

/* SERIALIZABLE and REPEATABLE READ can both be started. */
UTEST_F(db, 6_61_start_tran_serializable) {
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_SERIALIZABLE),
            SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_REPEATABLE_READ),
            SQL_SUCCESS);
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

  /* An environment without established connections still starts one, which
   * is started in the first connection that executes a statement. EndTran
   * doesn't end it, since none of the connections is active. */
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_ENV, utest_fixture->env,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_SUCCESS);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_ENV, utest_fixture->env, SQL_DIAG_TRANSACTION_ACTIVE),
      1);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_ENV, utest_fixture->env, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_ENV, utest_fixture->env, SQL_DIAG_TRANSACTION_ACTIVE),
      1);
}

/* An environment with more than one connection starts the transaction
 * without it being in any connection, since none of them is active. The first
 * connection that executes a statement starts it, after which the other
 * connections can't be used until it ends (#747). */
UTEST_F(db, 6_61_start_tran_multiple_connections) {
  SQLHDBC dbc2;
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocConnect(utest_fixture->env, &dbc2), SQL_SUCCESS);
  ASSERT_EQ(connect_memory(dbc2), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocStmt(dbc2, &stmt2), SQL_SUCCESS);

  EXPECT_EQ(SQLStartTran(SQL_HANDLE_ENV, utest_fixture->env,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_SUCCESS);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_ENV, utest_fixture->env, SQL_DIAG_TRANSACTION_ACTIVE),
      1);
  EXPECT_EQ(diag_int(SQL_HANDLE_DBC, dbc2, SQL_DIAG_TRANSACTION_ACTIVE), 1);

  /* None of the connections is active, so another StartTran for the
   * environment replaces it. */
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_ENV, utest_fixture->env,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_SERIALIZABLE),
            SQL_SUCCESS);

  /* It's started in the second connection, which is now the only one that
   * can be used. AUTOCOMMIT doesn't end it. */
  ASSERT_EQ(SQLSetConnectAttr(dbc2, SQL_ATTR_AUTOCOMMIT,
                              INTEGER_VALUE(SQL_AUTOCOMMIT_ON), 0),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt2, "CREATE TABLE t (x INT)"), SQL_SUCCESS);
  EXPECT_EQ(diag_int(SQL_HANDLE_DBC, dbc2, SQL_DIAG_TRANSACTION_ACTIVE), 1);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "0A001");

  /* Now that the second connection is active, StartTran is 25001. */
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_ENV, utest_fixture->env,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_ENV, utest_fixture->env, "25001");

  /* Ending it for the environment ends it in the second connection. */
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_ENV, utest_fixture->env, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_ENV, utest_fixture->env, SQL_DIAG_TRANSACTION_ACTIVE),
      0);
  EXPECT_EQ(run_sql(stmt2, "SELECT * FROM t"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "42P01");
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_ENV, utest_fixture->env, SQL_ROLLBACK),
            SQL_SUCCESS);

  /* A StartTran for a connection replaces one for the environment that no
   * connection has started yet, and is started in that connection. */
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_ENV, utest_fixture->env,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_SUCCESS);
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_SUCCESS);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_TRANSACTION_ACTIVE),
      1);
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, dbc2, SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, dbc2, "0A001");
  EXPECT_EQ(run_sql(stmt2, "VALUES 1"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "0A001");
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_ENV, utest_fixture->env,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_ENV, utest_fixture->env, "25001");
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_ENV, utest_fixture->env, SQL_COMMIT),
            SQL_SUCCESS);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_ENV, utest_fixture->env, SQL_DIAG_TRANSACTION_ACTIVE),
      0);

  EXPECT_EQ(SQLDisconnect(dbc2), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeConnect(dbc2), SQL_SUCCESS);
}

/* The isolation level is that of the StartTran, not of a SET TRANSACTION, which
 * can't be executed while the transaction is active. */
UTEST_F(db, 6_61_start_tran_environment_set_transaction) {
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_ENV, utest_fixture->env,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_SERIALIZABLE),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt,
                    "SET TRANSACTION ISOLATION LEVEL READ COMMITTED"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "25001");
  EXPECT_EQ(
      diag_int(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_TRANSACTION_ACTIVE),
      1);

  /* No connection is active, so EndTran leaves it, with or without AND
   * CHAIN. */
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_ENV, utest_fixture->env, SQL_COMMIT_AND_CHAIN),
            SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_ENV, utest_fixture->env, SQL_COMMIT),
            SQL_SUCCESS);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_TRANSACTION_ACTIVE),
      1);

  /* Once the connection has started it, EndTran ends it. */
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_ENV, utest_fixture->env, SQL_COMMIT),
            SQL_SUCCESS);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_TRANSACTION_ACTIVE),
      0);
}

/* A handle that isn't allocated is invalid, for each type of handle, and a
 * statement or descriptor can't start an SQL-transaction. */
UTEST_F(db, 6_61_start_tran_handle_types) {
  SQLHDESC apd = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_PARAM_DESC);

  EXPECT_EQ(SQLStartTran(7, utest_fixture->dbc, SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_INVALID_HANDLE);
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_STMT, 999999, SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_INVALID_HANDLE);
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DESC, 999999, SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_INVALID_HANDLE);
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_ENV, 999999, SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_INVALID_HANDLE);
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DESC, apd, SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, apd, "HY092");
}

/* The DIAGNOSTICS SIZE of a SET TRANSACTION is kept, since StartTran doesn't
 * have one. */
UTEST_F(db, 6_61_start_tran_diagnostics_size) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SET TRANSACTION DIAGNOSTICS SIZE 1"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_READ_COMMITTED),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt,
                    "SELECT CAST('abc' AS CHAR(1)) AS a, "
                    "CAST('xyz' AS CHAR(1)) AS b FROM (VALUES 1) AS t (x)"),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_NUMBER), 1);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_MORE), 1);
}
