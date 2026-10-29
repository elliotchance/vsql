#include "test.h"

/* 5.3 ImplicitSetConnection */

/* A routine on another connection makes it the current connection, unless
 * the current connection has an active transaction. */
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

  /* There's no active transaction, so each routine switches connection. */
  EXPECT_EQ(run_sql(stmt2, "CREATE TABLE t (x INT)"), SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, dbc2, SQL_COMMIT), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);

  /* The first connection now has an active transaction. */
  EXPECT_EQ(run_sql(stmt2, "VALUES 1"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "0A001");
  EXPECT_EQ(SQLNumResultCols(stmt2, &supported), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "0A001");
  EXPECT_EQ(SQLSetDescField(desc2, 0, SQL_DESC_COUNT, SMALLINT_VALUE(1), 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, desc2, "0A001");
  EXPECT_EQ(SQLGetInfo(dbc2, SQL_DBMS_NAME, value, sizeof(value), NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, dbc2, "0A001");
  EXPECT_EQ(SQLGetFunctions(dbc2, SQL_API_SQLFETCH, &supported), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, dbc2, "0A001");
  EXPECT_EQ(SQLGetFeatureInfo(dbc2, (SQLCHAR *)"FEATURE", SQL_NTS,
                              (SQLCHAR *)"E011", SQL_NTS, NULL, 0, &supported),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, dbc2, "0A001");
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_DESC, desc2), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, desc2, "0A001");
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_STMT, stmt2), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "0A001");

  /* The routines on the current connection still work. */
  EXPECT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (1)"),
            SQL_SUCCESS);

  /* After the transaction ends, the other connection can be used. */
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt2, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, dbc2, SQL_COMMIT), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_DESC, desc2), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(dbc2), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeConnect(dbc2), SQL_SUCCESS);
}

/* A statement or descriptor can't be allocated on another connection, and
 * another connection can't be made, while the current connection has an
 * active transaction. */
UTEST_F(db, 5_3_implicit_set_connection_alloc_and_connect) {
  SQLHDBC dbc2, dbc3;
  SQLHSTMT stmt2 = 123;
  SQLHDESC desc2 = 123;

  ASSERT_EQ(SQLAllocConnect(utest_fixture->env, &dbc2), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocConnect(utest_fixture->env, &dbc3), SQL_SUCCESS);
  ASSERT_EQ(connect_memory(dbc2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);

  EXPECT_EQ(SQLAllocStmt(dbc2, &stmt2), SQL_ERROR);
  EXPECT_EQ(stmt2, 0);
  EXPECT_STATE(SQL_HANDLE_DBC, dbc2, "0A001");
  EXPECT_EQ(SQLAllocHandle(SQL_HANDLE_DESC, dbc2, &desc2), SQL_ERROR);
  EXPECT_EQ(desc2, 0);
  EXPECT_STATE(SQL_HANDLE_DBC, dbc2, "0A001");
  EXPECT_EQ(connect_memory(dbc3), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, dbc3, "0A001");

  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(SQLAllocStmt(dbc2, &stmt2), SQL_SUCCESS);
  EXPECT_EQ(connect_memory(dbc3), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(dbc3), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(dbc2), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeConnect(dbc3), SQL_SUCCESS);
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
