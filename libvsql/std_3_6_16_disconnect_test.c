#include "test.h"

/* 6.16 Disconnect */

/* An active transaction must be ended first. */
UTEST_F(db, 6_16_disconnect_active_transaction) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "25001");
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);
}

UTEST_F(db, 6_16_disconnect_frees_statements) {
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_INVALID_HANDLE);
}

UTEST_F(db, 6_16_disconnect_not_connected) {
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "08003");
}

/* A file database can be opened again after it's disconnected. */
UTEST_F(env, 6_16_disconnect_reopen_file) {
  SQLHSTMT stmt;
  SQLDOUBLE x;

  remove("libvsql_test.vsql");
  ASSERT_EQ(SQLConnect(utest_fixture->dbc, (SQLCHAR *)"libvsql_test.vsql",
                       SQL_NTS, NULL, 0, NULL, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_STMT, utest_fixture->dbc, &stmt),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt, "CREATE TABLE t (x DOUBLE PRECISION)"), SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt, "INSERT INTO t (x) VALUES (1.5)"), SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);

  ASSERT_EQ(SQLConnect(utest_fixture->dbc, (SQLCHAR *)"libvsql_test.vsql",
                       SQL_NTS, NULL, 0, NULL, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_STMT, utest_fixture->dbc, &stmt),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt, "SELECT * FROM t"), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(stmt, 1, SQL_DOUBLE, &x, 0, NULL), SQL_SUCCESS);
  EXPECT_EQ(x, 1.5);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);

  remove("libvsql_test.vsql");
}

UTEST_F(db, 6_16_disconnect_frees_descriptors) {
  SQLHDESC desc;

  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_DESC, utest_fixture->dbc, &desc),
            SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_DESC, desc), SQL_INVALID_HANDLE);
}

/* A statement that's waiting for a deferred parameter is a function sequence
 * error, rather than an active SQL-transaction. */
UTEST_F(db, 6_16_disconnect_deferred_parameter) {
  SQLINTEGER at_exec = SQL_DATA_AT_EXEC, x = 1;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_INTEGER, 0, 0, &x, sizeof(x),
                             &at_exec),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES ?"), SQL_NEED_DATA);
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY010");
  EXPECT_EQ(SQLCancel(utest_fixture->stmt), SQL_SUCCESS);
}
