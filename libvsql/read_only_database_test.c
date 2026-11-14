#include "test.h"

/* Each statement runs in an SQL-transaction, which doesn't lock or change the
 * file until a statement changes something (#672). So a file that needs a
 * newer version of vsql to be changed can still be queried. */
UTEST_F(env, read_only_database_query) {
  SQLHSTMT stmt;
  FILE *f;

  remove("libvsql_read_only.vsql");
  ASSERT_EQ(SQLConnect(utest_fixture->dbc, (SQLCHAR *)"libvsql_read_only.vsql",
                       SQL_NTS, NULL, 0, NULL, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_STMT, utest_fixture->dbc, &stmt),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt, "CREATE TABLE t (x INT)"), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt, "INSERT INTO t (x) VALUES (1)"), SQL_SUCCESS);
  ASSERT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);
  ASSERT_EQ(SQLFreeHandle(SQL_HANDLE_STMT, stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);

  /* Connecting again copies the log into the file, so that the log doesn't
   * put the header back. Then the write version (at offset 10) is made newer
   * than this version of vsql. */
  ASSERT_EQ(SQLConnect(utest_fixture->dbc, (SQLCHAR *)"libvsql_read_only.vsql",
                       SQL_NTS, NULL, 0, NULL, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);
  f = fopen("libvsql_read_only.vsql", "r+b");
  ASSERT_TRUE(f != NULL);
  fseek(f, 10, SEEK_SET);
  fputc(0xff, f);
  fputc(0xff, f);
  fclose(f);

  ASSERT_EQ(SQLConnect(utest_fixture->dbc, (SQLCHAR *)"libvsql_read_only.vsql",
                       SQL_NTS, NULL, 0, NULL, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_STMT, utest_fixture->dbc, &stmt),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt, "SELECT CAST(x AS VARCHAR(10)) FROM t"), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(stmt, 1), "1");
  EXPECT_EQ(run_sql(stmt, "INSERT INTO t (x) VALUES (2)"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt, "25006");
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);

  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_STMT, stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);
  remove("libvsql_read_only.vsql");
  remove("libvsql_read_only.vsql.wal");
  remove("libvsql_read_only.vsql.session");
  remove("libvsql_read_only.vsql.isolation");
  remove("libvsql_read_only.vsql.isolation.queue");
}
