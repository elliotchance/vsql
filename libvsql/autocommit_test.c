#include "test.h"

/* SQL_ATTR_AUTOCOMMIT (see SQLSetConnectAttr) */

#define ACTIVE(dbc) diag_int(SQL_HANDLE_DBC, dbc, SQL_DIAG_TRANSACTION_ACTIVE)

static SQLRETURN set_autocommit(SQLHDBC dbc, SQLINTEGER value) {
  return SQLSetConnectAttr(dbc, SQL_ATTR_AUTOCOMMIT, INTEGER_VALUE(value), 0);
}

static SQLINTEGER get_autocommit(SQLHDBC dbc) {
  SQLINTEGER value = -1;

  if (SQLGetConnectAttr(dbc, SQL_ATTR_AUTOCOMMIT, &value, 0, NULL) !=
      SQL_SUCCESS) {
    return -2;
  }

  return value;
}

/* It's off by default, so a statement starts a transaction that lasts until
 * SQLEndTran. */
UTEST_F(db, autocommit_off) {
  EXPECT_EQ(get_autocommit(utest_fixture->dbc), SQL_AUTOCOMMIT_OFF);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(ACTIVE(utest_fixture->dbc), 1);
}

/* A statement that isn't a query is committed when it finishes. */
UTEST_F(db, autocommit_statement) {
  ASSERT_EQ(set_autocommit(utest_fixture->dbc, SQL_AUTOCOMMIT_ON),
            SQL_SUCCESS);
  EXPECT_EQ(get_autocommit(utest_fixture->dbc), SQL_AUTOCOMMIT_ON);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(ACTIVE(utest_fixture->dbc), 0);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (1)"),
            SQL_SUCCESS);
  EXPECT_EQ(ACTIVE(utest_fixture->dbc), 0);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt,
                     SQL_DIAG_TRANSACTIONS_COMMITTED),
            1);

  /* It was committed, so a rollback doesn't undo it. */
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM t"), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 1), "1");
}

/* A query is committed when its cursor is closed, and only once every cursor
 * of the connection is closed. */
UTEST_F(db, autocommit_query) {
  SQLHSTMT stmt2;

  ASSERT_EQ(set_autocommit(utest_fixture->dbc, SQL_AUTOCOMMIT_ON),
            SQL_SUCCESS);
  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);

  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(ACTIVE(utest_fixture->dbc), 1);
  EXPECT_EQ(run_sql(stmt2, "VALUES 2"), SQL_SUCCESS);
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(ACTIVE(utest_fixture->dbc), 1);
  EXPECT_EQ(SQLFreeStmt(stmt2, SQL_CLOSE), SQL_SUCCESS);
  EXPECT_EQ(ACTIVE(utest_fixture->dbc), 0);

  /* Freeing the statement, or SQLMoreResults, also closes it. */
  EXPECT_EQ(run_sql(stmt2, "VALUES 2"), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_STMT, stmt2), SQL_SUCCESS);
  EXPECT_EQ(ACTIVE(utest_fixture->dbc), 0);
  EXPECT_EQ(SQLPrepare(utest_fixture->stmt, (SQLCHAR *)"VALUES 3", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLExecute(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(ACTIVE(utest_fixture->dbc), 1);
  EXPECT_EQ(SQLMoreResults(utest_fixture->stmt), SQL_NO_DATA);
  EXPECT_EQ(ACTIVE(utest_fixture->dbc), 0);

  /* A connection with an open cursor can be disconnected. */
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);
}

/* A statement that fails is rolled back. */
UTEST_F(db, autocommit_error) {
  ASSERT_EQ(set_autocommit(utest_fixture->dbc, SQL_AUTOCOMMIT_ON),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO missing (x) VALUES (1)"),
            SQL_ERROR);
  EXPECT_EQ(ACTIVE(utest_fixture->dbc), 0);
}

/* A transaction that's started by SQLStartTran lasts until SQLEndTran. */
UTEST_F(db, autocommit_start_tran) {
  ASSERT_EQ(set_autocommit(utest_fixture->dbc, SQL_AUTOCOMMIT_ON),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                         SQL_TRANSACTION_READ_WRITE, SQL_TRANSACTION_READ_COMMITTED),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (1)"),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(ACTIVE(utest_fixture->dbc), 1);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT COUNT(*) FROM t"),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 1), "0");
  EXPECT_EQ(ACTIVE(utest_fixture->dbc), 0);
}

/* Turning it on commits the active transaction. Turning it off makes the
 * transaction of an open cursor last until SQLEndTran. */
UTEST_F(db, autocommit_set) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(ACTIVE(utest_fixture->dbc), 1);
  EXPECT_EQ(set_autocommit(utest_fixture->dbc, SQL_AUTOCOMMIT_ON),
            SQL_SUCCESS);
  EXPECT_EQ(ACTIVE(utest_fixture->dbc), 0);

  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(set_autocommit(utest_fixture->dbc, SQL_AUTOCOMMIT_OFF),
            SQL_SUCCESS);
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(ACTIVE(utest_fixture->dbc), 1);

  EXPECT_EQ(set_autocommit(utest_fixture->dbc, 2), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY024");
  EXPECT_EQ(SQLSetConnectAttr(utest_fixture->dbc, SQL_ATTR_AUTOCOMMIT, NULL, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY009");
}
