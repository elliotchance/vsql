#include "test.h"

/* 6.17 EndTran */

/* count_rows returns the number of rows in the table t. */
static SQLINTEGER count_rows(SQLHSTMT stmt) {
  SQLINTEGER count = -1;

  if (run_sql(stmt, "SELECT COUNT(*) FROM t") != SQL_SUCCESS ||
      SQLFetch(stmt) != SQL_SUCCESS ||
      SQLGetData(stmt, 1, SQL_INTEGER, &count, 0, NULL) != SQL_SUCCESS) {
    count = -2;
  }
  SQLCloseCursor(stmt);

  return count;
}

UTEST_F(db, 6_17_end_tran_commit) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (1)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);

  ASSERT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (2)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(count_rows(utest_fixture->stmt), 1);
}

/* A rollback also undoes a CREATE TABLE. */
UTEST_F(db, 6_17_end_tran_rollback) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM t"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "42P01");
}

/* Every cursor is holdable, so a commit doesn't close it. */
UTEST_F(db, 6_17_end_tran_commit_keeps_cursor) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1, 2"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
}

UTEST_F(db, 6_17_end_tran_rollback_closes_cursor) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1, 2"), SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

/* AND CHAIN starts another transaction. */
UTEST_F(db, 6_17_end_tran_chain) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(
      SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT_AND_CHAIN),
      SQL_SUCCESS);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_TRANSACTION_ACTIVE),
      1);
  EXPECT_EQ(
      SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK_AND_CHAIN),
      SQL_SUCCESS);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_TRANSACTION_ACTIVE),
      1);
  EXPECT_EQ(diag_int(SQL_HANDLE_DBC, utest_fixture->dbc,
                     SQL_DIAG_TRANSACTIONS_ROLLED_BACK),
            1);
}

/* The environment ends the transaction of its connections. Only one can be
 * active (see 5.3, "Implicit set connection"). */
UTEST_F(db, 6_17_end_tran_environment) {
  SQLHDBC dbc2;
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_DBC, utest_fixture->env, &dbc2),
            SQL_SUCCESS);
  ASSERT_EQ(connect_memory(dbc2), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_STMT, dbc2, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);

  EXPECT_EQ(SQLEndTran(SQL_HANDLE_ENV, utest_fixture->env, SQL_COMMIT),
            SQL_SUCCESS);
  EXPECT_EQ(diag_int(SQL_HANDLE_ENV, utest_fixture->env,
                     SQL_DIAG_TRANSACTIONS_COMMITTED),
            1);
  EXPECT_EQ(run_sql(stmt2, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_ENV, utest_fixture->env, SQL_COMMIT),
            SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(dbc2), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_DBC, dbc2), SQL_SUCCESS);
}

/* There may not be an active transaction, or an established connection. */
UTEST_F(env, 6_17_end_tran_no_transaction) {
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);
  ASSERT_EQ(connect_memory(utest_fixture->dbc), SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(diag_int(SQL_HANDLE_DBC, utest_fixture->dbc,
                     SQL_DIAG_TRANSACTIONS_ROLLED_BACK),
            0);
}

UTEST_F(db, 6_17_end_tran_invalid_completion_type) {
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, 3), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY012");
}

/* A savepoint that doesn't exist. */
UTEST_F(db, 6_17_end_tran_savepoint_missing) {
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                       SQL_SAVEPOINT_NAME_ROLLBACK),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "3B001");
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                       SQL_SAVEPOINT_NAME_RELEASE),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "3B001");
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_ENV, utest_fixture->env,
                       SQL_SAVEPOINT_NAME_ROLLBACK),
            SQL_INVALID_HANDLE);

  /* It isn't an identifier, or it's not a savepoint. */
  const char *names[] = {"a b", "a;b", "\"a\"b\"", "select", "1a"};
  for (int i = 0; i < 5; i++) {
    EXPECT_EQ(SQLSetConnectAttr(utest_fixture->dbc, SQL_ATTR_SAVEPOINT_NAME,
                                (SQLPOINTER)names[i], SQL_NTS),
              SQL_SUCCESS);
    EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                         SQL_SAVEPOINT_NAME_ROLLBACK),
              SQL_ERROR);
    EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "3B001");
  }
}

/* 13, 15: rolling back to a savepoint, then releasing it. */
UTEST_F(db, 6_17_end_tran_savepoint) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (1)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SAVEPOINT s1"), SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (2)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetConnectAttr(utest_fixture->dbc, SQL_ATTR_SAVEPOINT_NAME,
                              (SQLPOINTER) "s1", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                       SQL_SAVEPOINT_NAME_ROLLBACK),
            SQL_SUCCESS);

  /* It's still the same transaction, and the savepoint can be used again. */
  EXPECT_EQ(
      diag_int(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_TRANSACTION_ACTIVE),
      1);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                       SQL_SAVEPOINT_NAME_ROLLBACK),
            SQL_SUCCESS);

  /* A delimited name is the name as it's stored. */
  ASSERT_EQ(SQLSetConnectAttr(utest_fixture->dbc, SQL_ATTR_SAVEPOINT_NAME,
                              (SQLPOINTER) "\"S1\"", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                       SQL_SAVEPOINT_NAME_RELEASE),
            SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                       SQL_SAVEPOINT_NAME_RELEASE),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "3B001");
  ASSERT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);

  /* Only the first row was kept. A DELETE that finds no rows is no data. */
  EXPECT_EQ(run_sql(utest_fixture->stmt, "DELETE FROM t WHERE x = 2"),
            SQL_NO_DATA);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "DELETE FROM t WHERE x = 1"),
            SQL_SUCCESS);
}

UTEST_F(db, 6_17_end_tran_statement) {
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_COMMIT),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY092");
}

UTEST_F(db, 6_17_end_tran_invalid_handle) {
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->stmt, SQL_COMMIT),
            SQL_INVALID_HANDLE);
  EXPECT_EQ(SQLEndTran(7, utest_fixture->dbc, SQL_COMMIT), SQL_INVALID_HANDLE);
}

/* A commit closes a cursor that isn't holdable. */
UTEST_F(db, 6_17_end_tran_commit_nonholdable) {
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_HOLDABLE,
                           INTEGER_VALUE(SQL_NONHOLDABLE), 0),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1, 2"), SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

UTEST_F(db, 6_17_end_tran_descriptor) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);

  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DESC, ard, SQL_COMMIT), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "HY092");
}

/* A handle that isn't allocated is invalid, for each type of handle. */
UTEST(libvsql, 6_17_end_tran_unallocated_handle) {
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_STMT, 999999, SQL_COMMIT),
            SQL_INVALID_HANDLE);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DESC, 999999, SQL_COMMIT),
            SQL_INVALID_HANDLE);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_ENV, 999999, SQL_COMMIT),
            SQL_INVALID_HANDLE);
}

/* A COMMIT that fails with an I/O error (rather than a constraint that isn't
 * satisfied) is rolled back, so there's nothing left to commit, and a holdable
 * cursor is closed like any other rollback. General Rules 12.d.iii. */
UTEST_F(env, 6_17_end_tran_commit_fails) {
  SQLHSTMT stmt;

  remove("libvsql_end_tran.vsql");
  ASSERT_EQ(SQLConnect(utest_fixture->dbc, (SQLCHAR *)"libvsql_end_tran.vsql",
                       SQL_NTS, NULL, 0, NULL, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_STMT, utest_fixture->dbc, &stmt),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt, "CREATE TABLE t (x INT)"), SQL_SUCCESS);
  ASSERT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt, "INSERT INTO t (x) VALUES (1)"), SQL_SUCCESS);

  ASSERT_EQ(run_sql(stmt, "VALUES 1, 2"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(stmt), SQL_SUCCESS);

  ASSERT_EQ(vsql_arm_fault("wal_write", 1), 0);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "40V01");
  EXPECT_EQ(diag_int(SQL_HANDLE_DBC, utest_fixture->dbc,
                     SQL_DIAG_TRANSACTIONS_ROLLED_BACK),
            1);
  EXPECT_EQ(diag_int(SQL_HANDLE_DBC, utest_fixture->dbc,
                     SQL_DIAG_TRANSACTION_ACTIVE),
            0);
  EXPECT_EQ(SQLFetch(stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt, "24000");
  EXPECT_EQ(count_rows(stmt), 0);

  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);
  remove("libvsql_end_tran.vsql");
  remove("libvsql_end_tran.vsql.wal");
  remove("libvsql_end_tran.vsql.session");
}

/* If the rollback of a COMMIT that failed also fails, then the SQL-transaction
 * is still active, and it can be committed again. */
UTEST_F(env, 6_17_end_tran_commit_and_rollback_fail) {
  SQLHSTMT stmt;

  remove("libvsql_end_tran_fail.vsql");
  ASSERT_EQ(SQLConnect(utest_fixture->dbc,
                       (SQLCHAR *)"libvsql_end_tran_fail.vsql", SQL_NTS, NULL,
                       0, NULL, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_STMT, utest_fixture->dbc, &stmt),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt, "CREATE TABLE t (x INT)"), SQL_SUCCESS);
  ASSERT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt, "INSERT INTO t (x) VALUES (1)"), SQL_SUCCESS);

  ASSERT_EQ(vsql_arm_fault("read_page", 1), 0);
  ASSERT_EQ(vsql_arm_fault("wal_write", 1), 0);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "58030");
  EXPECT_EQ(diag_int(SQL_HANDLE_DBC, utest_fixture->dbc,
                     SQL_DIAG_TRANSACTIONS_ROLLED_BACK),
            0);
  EXPECT_EQ(diag_int(SQL_HANDLE_DBC, utest_fixture->dbc,
                     SQL_DIAG_TRANSACTION_ACTIVE),
            1);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);
  EXPECT_EQ(count_rows(stmt), 1);

  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);
  remove("libvsql_end_tran_fail.vsql");
  remove("libvsql_end_tran_fail.vsql.wal");
  remove("libvsql_end_tran_fail.vsql.session");
}
