#include "test.h"

/* 5.3 ImplicitSetConnection */

/* A routine on another connection makes it the current connection. An
 * SQL-transaction can have a branch on each connection (ISO/IEC 9075-2:2023,
 * Feature T262), so that's also the case while the current connection has an
 * active transaction, and the other connection's statements start a branch of
 * it. Ending the transaction of either connection ends both branches. */
UTEST_F(db, 5_3_implicit_set_connection) {
  SQLHDBC dbc2;
  SQLHSTMT stmt2;
  SQLHDESC desc2;
  SQLCHAR value[20];
  SQLSMALLINT supported;

  ASSERT_EQ(SQLAllocConnect(utest_fixture->env, &dbc2), SQL_SUCCESS);
  ASSERT_EQ(connect_memory(dbc2), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocStmt(dbc2, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_DESC, dbc2, &desc2), SQL_SUCCESS);

  EXPECT_EQ(run_sql(stmt2, "CREATE TABLE u (y INT)"), SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, dbc2, SQL_COMMIT), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);

  /* The first connection has an active transaction, and each routine on the
   * second one still works. */
  EXPECT_EQ(run_sql(stmt2, "INSERT INTO u (y) VALUES (2)"), SQL_SUCCESS);
  EXPECT_EQ(SQLNumResultCols(stmt2, &supported), SQL_SUCCESS);
  EXPECT_EQ(SQLSetDescField(desc2, 0, SQL_DESC_COUNT, SMALLINT_VALUE(1), 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetInfo(dbc2, SQL_DBMS_NAME, value, sizeof(value), NULL),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetFunctions(dbc2, SQL_API_SQLFETCH, &supported), SQL_SUCCESS);
  EXPECT_EQ(SQLGetFeatureInfo(dbc2, (SQLCHAR *)"FEATURE", SQL_NTS,
                              (SQLCHAR *)"E011", SQL_NTS, NULL, 0, &supported),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (1)"),
            SQL_SUCCESS);
  EXPECT_EQ(diag_int(SQL_HANDLE_DBC, dbc2, SQL_DIAG_TRANSACTION_ACTIVE), 1);

  /* A commit of the second connection commits both branches. */
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, dbc2, SQL_COMMIT), SQL_SUCCESS);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_TRANSACTION_ACTIVE),
      0);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM t"), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 1), "1");
  EXPECT_EQ(run_sql(stmt2, "SELECT * FROM u"), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(stmt2, 1), "2");

  /* A rollback of the first connection rolls back both branches. */
  EXPECT_EQ(run_sql(stmt2, "INSERT INTO u (y) VALUES (3)"), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (3)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(diag_int(SQL_HANDLE_DBC, dbc2, SQL_DIAG_TRANSACTION_ACTIVE), 0);
  EXPECT_EQ(run_sql(stmt2, "SELECT * FROM u"), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(stmt2, 1), "2");

  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, dbc2, SQL_COMMIT), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_DESC, desc2), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(dbc2), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeConnect(dbc2), SQL_SUCCESS);
}

/* A statement or descriptor can be allocated on another connection, and
 * another connection can be made, while the current connection has an active
 * transaction (T262). */
UTEST_F(db, 5_3_implicit_set_connection_alloc_and_connect) {
  SQLHDBC dbc2, dbc3;
  SQLHSTMT stmt2 = 123;
  SQLHDESC desc2 = 123;

  ASSERT_EQ(SQLAllocConnect(utest_fixture->env, &dbc2), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocConnect(utest_fixture->env, &dbc3), SQL_SUCCESS);
  ASSERT_EQ(connect_memory(dbc2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);

  EXPECT_EQ(SQLAllocStmt(dbc2, &stmt2), SQL_SUCCESS);
  EXPECT_EQ(SQLAllocHandle(SQL_HANDLE_DESC, dbc2, &desc2), SQL_SUCCESS);
  EXPECT_EQ(connect_memory(dbc3), SQL_SUCCESS);

  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_DESC, desc2), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_STMT, stmt2), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(dbc3), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(dbc2), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeConnect(dbc3), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeConnect(dbc2), SQL_SUCCESS);
}

/* A branch on another connection has the characteristics of the
 * SQL-transaction, unless SET LOCAL TRANSACTION changes them first, which
 * can't make it less strict (ISO/IEC 9075-2:2023, 17.2, <set transaction
 * statement>, General Rules, 1.b). A commit checks the deferred constraints of
 * every branch first, and rolls back every branch if one of them fails. */
UTEST_F(db, 5_3_implicit_set_connection_branches) {
  SQLHDBC dbc2;
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocConnect(utest_fixture->env, &dbc2), SQL_SUCCESS);
  ASSERT_EQ(connect_memory(dbc2), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocStmt(dbc2, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE d (z INT CHECK (z > 0) INITIALLY DEFERRED)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLEndTran(SQL_HANDLE_DBC, dbc2, SQL_COMMIT), SQL_SUCCESS);

  /* Without an active SQL-transaction there's no branch. */
  EXPECT_EQ(run_sql(stmt2, "SET LOCAL TRANSACTION READ ONLY"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "25005");

  ASSERT_EQ(SQLStartTran(SQL_HANDLE_DBC, utest_fixture->dbc,
                         SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_REPEATABLE_READ),
            SQL_SUCCESS);
  EXPECT_EQ(SQLStartTran(SQL_HANDLE_DBC, dbc2, SQL_TRANSACTION_READ_WRITE,
                         SQL_TRANSACTION_SERIALIZABLE),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, dbc2, "25001");
  EXPECT_EQ(run_sql(stmt2, "SET LOCAL TRANSACTION ISOLATION LEVEL READ COMMITTED"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "25004");
  EXPECT_EQ(run_sql(stmt2, "SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE"),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt2, "INSERT INTO d (z) VALUES (-1)"), SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt2, "SET LOCAL TRANSACTION READ ONLY"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "25002");

  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "23514");
  EXPECT_EQ(diag_int(SQL_HANDLE_DBC, dbc2, SQL_DIAG_TRANSACTION_ACTIVE), 0);
  EXPECT_EQ(run_sql(stmt2, "SELECT * FROM d"), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(stmt2, 1), "");

  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, dbc2, SQL_COMMIT), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(dbc2), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeConnect(dbc2), SQL_SUCCESS);
}

/* Disconnecting the current connection leaves no current connection, so any
 * other connection can be used. */
UTEST_F(db, 5_3_implicit_set_connection_disconnect) {
  SQLHDBC dbc2;
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocConnect(utest_fixture->env, &dbc2), SQL_SUCCESS);
  ASSERT_EQ(connect_memory(dbc2), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocStmt(dbc2, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, dbc2, SQL_COMMIT), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(dbc2), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeConnect(dbc2), SQL_SUCCESS);
}


/* Each SQL-environment is its own SQL-agent, with its own current connection,
 * so connections in different environments can each have an active
 * transaction. */
UTEST_F(db, 5_3_implicit_set_connection_environments) {
  SQLHENV env2;
  SQLHDBC dbc2;
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocEnv(&env2), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocConnect(env2, &dbc2), SQL_SUCCESS);
  ASSERT_EQ(connect_memory(dbc2), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocStmt(dbc2, &stmt2), SQL_SUCCESS);

  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt2, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt,
                     SQL_DIAG_TRANSACTION_ACTIVE),
            1);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, stmt2, SQL_DIAG_TRANSACTION_ACTIVE), 1);

  EXPECT_EQ(SQLEndTran(SQL_HANDLE_ENV, env2, SQL_COMMIT), SQL_SUCCESS);
  free_handles(env2, dbc2, stmt2);
}
