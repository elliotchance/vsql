#include "test.h"

/* The SQL_ATTR_VSQL_ connection attributes (connection_options.v). */

static SQLINTEGER get_attr(SQLHDBC dbc, SQLINTEGER attribute) {
  SQLINTEGER v = -1;
  if (SQLGetConnectAttr(dbc, attribute, &v, 0, NULL) != SQL_SUCCESS) {
    return -2;
  }
  return v;
}

static SQLRETURN set_attr(SQLHDBC dbc, SQLINTEGER attribute, SQLINTEGER v) {
  return SQLSetConnectAttr(dbc, attribute, &v, 0);
}

UTEST_F(env, connection_options_defaults) {
  EXPECT_EQ(get_attr(utest_fixture->dbc, SQL_ATTR_VSQL_LOCK_TIMEOUT), 5000);
  EXPECT_EQ(get_attr(utest_fixture->dbc, SQL_ATTR_VSQL_CREATE_INDEX_TIMEOUT),
            60000);
  EXPECT_EQ(get_attr(utest_fixture->dbc, SQL_ATTR_VSQL_ISOLATION_LEVEL),
            SQL_TRANSACTION_SERIALIZABLE);
  EXPECT_EQ(get_attr(utest_fixture->dbc, SQL_ATTR_VSQL_CACHE_SIZE), 2000);
  EXPECT_EQ(get_attr(utest_fixture->dbc, SQL_ATTR_VSQL_PAGE_SIZE), 4096);
  EXPECT_EQ(get_attr(utest_fixture->dbc, SQL_ATTR_VSQL_FULL_FSYNC), SQL_FALSE);
}

UTEST_F(env, connection_options_set) {
  SQLHDBC dbc = utest_fixture->dbc;
  struct {
    SQLINTEGER attribute, value;
  } values[] = {
      {SQL_ATTR_VSQL_LOCK_TIMEOUT, 0},
      {SQL_ATTR_VSQL_LOCK_TIMEOUT, 250},
      {SQL_ATTR_VSQL_CREATE_INDEX_TIMEOUT, 1000},
      {SQL_ATTR_VSQL_ISOLATION_LEVEL, SQL_TRANSACTION_READ_UNCOMMITTED},
      {SQL_ATTR_VSQL_ISOLATION_LEVEL, SQL_TRANSACTION_REPEATABLE_READ},
      {SQL_ATTR_VSQL_ISOLATION_LEVEL, SQL_TRANSACTION_READ_COMMITTED},
      {SQL_ATTR_VSQL_CACHE_SIZE, 0},
      {SQL_ATTR_VSQL_PAGE_SIZE, 1024},
      {SQL_ATTR_VSQL_FULL_FSYNC, SQL_TRUE},
  };
  for (size_t i = 0; i < sizeof(values) / sizeof(values[0]); i++) {
    EXPECT_EQ(set_attr(dbc, values[i].attribute, values[i].value), SQL_SUCCESS);
    EXPECT_EQ(get_attr(dbc, values[i].attribute), values[i].value);
  }

  /* The connection is opened with them. */
  ASSERT_EQ(SQLConnect(dbc, (SQLCHAR *)"DEFAULT", SQL_NTS, NULL, 0, NULL, 0),
            SQL_SUCCESS);
  EXPECT_EQ(get_attr(dbc, SQL_ATTR_VSQL_PAGE_SIZE), 1024);
  EXPECT_EQ(SQLDisconnect(dbc), SQL_SUCCESS);
}

UTEST_F(env, connection_options_invalid) {
  SQLHDBC dbc = utest_fixture->dbc;
  struct {
    SQLINTEGER attribute, value;
  } values[] = {
      {SQL_ATTR_VSQL_LOCK_TIMEOUT, -1},
      {SQL_ATTR_VSQL_CREATE_INDEX_TIMEOUT, -1},
      {SQL_ATTR_VSQL_ISOLATION_LEVEL, 3},
      {SQL_ATTR_VSQL_CACHE_SIZE, -1},
      {SQL_ATTR_VSQL_PAGE_SIZE, 16},
      {SQL_ATTR_VSQL_PAGE_SIZE, 65536},
      {SQL_ATTR_VSQL_FULL_FSYNC, 2},
  };
  for (size_t i = 0; i < sizeof(values) / sizeof(values[0]); i++) {
    EXPECT_EQ(set_attr(dbc, values[i].attribute, values[i].value), SQL_ERROR);
    EXPECT_STATE(SQL_HANDLE_DBC, dbc, "HY024");
  }
  EXPECT_EQ(get_attr(dbc, SQL_ATTR_VSQL_PAGE_SIZE), 4096);

  EXPECT_EQ(SQLSetConnectAttr(dbc, SQL_ATTR_VSQL_LOCK_TIMEOUT, NULL, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, dbc, "HY009");
}

/* They can't be set while the connection is established, but they can be read,
 * and set again after it's disconnected. */
UTEST_F(db, connection_options_connected) {
  EXPECT_EQ(set_attr(utest_fixture->dbc, SQL_ATTR_VSQL_LOCK_TIMEOUT, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY011");
  EXPECT_EQ(get_attr(utest_fixture->dbc, SQL_ATTR_VSQL_LOCK_TIMEOUT), 5000);

  ASSERT_EQ(SQLFreeHandle(SQL_HANDLE_STMT, utest_fixture->stmt), SQL_SUCCESS);
  utest_fixture->stmt = SQL_NULL_HANDLE;
  ASSERT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);
  ASSERT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);
  EXPECT_EQ(set_attr(utest_fixture->dbc, SQL_ATTR_VSQL_LOCK_TIMEOUT, 0),
            SQL_SUCCESS);
  EXPECT_EQ(get_attr(utest_fixture->dbc, SQL_ATTR_VSQL_LOCK_TIMEOUT), 0);
}

/* A connection with a LOCK_TIMEOUT of 0 fails straight away while another
 * connection has a SERIALIZABLE transaction, and one with an ISOLATION_LEVEL of
 * READ COMMITTED doesn't wait for it. */
UTEST_F(env, connection_options_lock_timeout) {
  SQLHDBC other;
  SQLHSTMT stmt, other_stmt;

  remove("libvsql_connection_options.vsql");
  ASSERT_EQ(SQLConnect(utest_fixture->dbc,
                       (SQLCHAR *)"libvsql_connection_options.vsql", SQL_NTS,
                       NULL, 0, NULL, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_STMT, utest_fixture->dbc, &stmt),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt, "CREATE TABLE t (x INT)"), SQL_SUCCESS);
  ASSERT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt, "INSERT INTO t (x) VALUES (1)"), SQL_SUCCESS);

  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_DBC, utest_fixture->env, &other),
            SQL_SUCCESS);
  ASSERT_EQ(set_attr(other, SQL_ATTR_VSQL_LOCK_TIMEOUT, 0), SQL_SUCCESS);
  ASSERT_EQ(SQLConnect(other, (SQLCHAR *)"libvsql_connection_options.vsql",
                       SQL_NTS, NULL, 0, NULL, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_STMT, other, &other_stmt), SQL_SUCCESS);
  EXPECT_EQ(run_sql(other_stmt, "INSERT INTO t (x) VALUES (2)"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, other_stmt, "40001");
  SQLEndTran(SQL_HANDLE_DBC, other, SQL_ROLLBACK);
  ASSERT_EQ(SQLFreeHandle(SQL_HANDLE_STMT, other_stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLDisconnect(other), SQL_SUCCESS);

  ASSERT_EQ(set_attr(other, SQL_ATTR_VSQL_ISOLATION_LEVEL,
                     SQL_TRANSACTION_READ_COMMITTED),
            SQL_SUCCESS);
  ASSERT_EQ(SQLConnect(other, (SQLCHAR *)"libvsql_connection_options.vsql",
                       SQL_NTS, NULL, 0, NULL, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_STMT, other, &other_stmt), SQL_SUCCESS);
  EXPECT_EQ(run_sql(other_stmt, "INSERT INTO t (x) VALUES (3)"), SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, other, SQL_ROLLBACK), SQL_SUCCESS);
  ASSERT_EQ(SQLFreeHandle(SQL_HANDLE_STMT, other_stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLDisconnect(other), SQL_SUCCESS);
  ASSERT_EQ(SQLFreeHandle(SQL_HANDLE_DBC, other), SQL_SUCCESS);

  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_ROLLBACK),
            SQL_SUCCESS);
  ASSERT_EQ(SQLFreeHandle(SQL_HANDLE_STMT, stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);
  remove("libvsql_connection_options.vsql");
  remove("libvsql_connection_options.vsql.wal");
  remove("libvsql_connection_options.vsql.session");
  remove("libvsql_connection_options.vsql.isolation");
  remove("libvsql_connection_options.vsql.isolation.queue");
}
