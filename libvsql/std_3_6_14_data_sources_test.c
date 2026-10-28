#include "test.h"

/* 6.14 DataSources */

UTEST_F(env, 6_14_data_sources) {
  SQLCHAR name[50], description[100];
  SQLSMALLINT name_length, description_length;

  EXPECT_EQ(SQLDataSources(utest_fixture->env, SQL_FETCH_FIRST, name,
                           sizeof(name), &name_length, description,
                           sizeof(description), &description_length),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)name, "DEFAULT");
  EXPECT_EQ(name_length, 7);
  EXPECT_EQ(SQLDataSources(utest_fixture->env, SQL_FETCH_NEXT, name,
                           sizeof(name), &name_length, description,
                           sizeof(description), &description_length),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)name, ":memory:");
  EXPECT_STREQ((char *)description, "A new in-memory database");
  EXPECT_EQ(description_length, 24);
  EXPECT_EQ(SQLDataSources(utest_fixture->env, SQL_FETCH_NEXT, name,
                           sizeof(name), NULL, description, sizeof(description),
                           NULL),
            SQL_NO_DATA);

  /* After the last one, NEXT starts again. */
  EXPECT_EQ(SQLDataSources(utest_fixture->env, SQL_FETCH_NEXT, name,
                           sizeof(name), NULL, description, sizeof(description),
                           NULL),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)name, "DEFAULT");
}

UTEST_F(env, 6_14_data_sources_truncated) {
  SQLCHAR name[4], description[100];
  SQLSMALLINT name_length;

  EXPECT_EQ(SQLDataSources(utest_fixture->env, SQL_FETCH_FIRST, name,
                           sizeof(name), &name_length, description,
                           sizeof(description), NULL),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_STREQ((char *)name, "DEF");
  EXPECT_EQ(name_length, 7);
  EXPECT_STATE(SQL_HANDLE_ENV, utest_fixture->env, "01004");
}

UTEST_F(env, 6_14_data_sources_invalid_direction) {
  SQLCHAR name[50], description[100];

  EXPECT_EQ(SQLDataSources(utest_fixture->env, SQL_FETCH_LAST, name,
                           sizeof(name), NULL, description, sizeof(description),
                           NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_ENV, utest_fixture->env, "HY103");
}

UTEST_F(env, 6_14_data_sources_connect) {
  SQLHDBC dbc2;
  SQLHSTMT stmt;

  /* Both data sources can be used as a ServerName. DEFAULT is the default
   * connection (the same as an empty ServerName), not a file. */
  EXPECT_EQ(SQLConnect(utest_fixture->dbc, (SQLCHAR *)"DEFAULT", SQL_NTS, NULL,
                       0, NULL, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLAllocConnect(utest_fixture->env, &dbc2), SQL_SUCCESS);
  EXPECT_EQ(connect_default(dbc2), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, dbc2, "08002");
  EXPECT_EQ(SQLFreeConnect(dbc2), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt), SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt, "CREATE TABLE t (x INT)"), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeStmt(stmt, SQL_DROP), SQL_SUCCESS);
  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(utest_fixture->dbc), SQL_SUCCESS);
}
