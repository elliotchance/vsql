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
