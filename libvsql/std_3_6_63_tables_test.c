#include "test.h"

/* 6.63 Tables */

UTEST_F(db, 6_63_tables) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t2 (x INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t1 (x INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLTables(utest_fixture->stmt, NULL, 0, NULL, 0, NULL, 0,
                      (SQLCHAR *)"TABLE", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 3), "T1,T2");

  ASSERT_EQ(SQLTables(utest_fixture->stmt, (SQLCHAR *)":memory:", SQL_NTS,
                      (SQLCHAR *)"PUB%", SQL_NTS, (SQLCHAR *)"T1", SQL_NTS,
                      NULL, 0),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 4), "TABLE");
}

/* The views of the INFORMATION_SCHEMA are SYSTEM TABLEs. */
UTEST_F(db, 6_63_tables_system) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLTables(utest_fixture->stmt, NULL, 0, NULL, 0,
                      (SQLCHAR *)"TABLES", SQL_NTS,
                      (SQLCHAR *)"'SYSTEM TABLE', TABLE", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 2), "INFORMATION_SCHEMA");
}

/* The special values return the catalogs, schemas or table types. */
UTEST_F(db, 6_63_tables_special) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLTables(utest_fixture->stmt, (SQLCHAR *)SQL_ALL_CATALOGS, SQL_NTS,
                      (SQLCHAR *)"", 0, (SQLCHAR *)"", 0, NULL, 0),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 1), ":memory:");
  ASSERT_EQ(SQLTables(utest_fixture->stmt, (SQLCHAR *)"", 0,
                      (SQLCHAR *)SQL_ALL_SCHEMAS, SQL_NTS, (SQLCHAR *)"", 0,
                      NULL, 0),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 2),
               "INFORMATION_SCHEMA,PUBLIC");
  ASSERT_EQ(SQLTables(utest_fixture->stmt, (SQLCHAR *)"", 0, (SQLCHAR *)"", 0,
                      (SQLCHAR *)"", 0, (SQLCHAR *)SQL_ALL_TABLE_TYPES,
                      SQL_NTS),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 4), "SYSTEM TABLE,TABLE");
}

/* "\" escapes a "_" in a pattern. */
UTEST_F(db, 6_63_tables_escape) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE a_b (x INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE axb (x INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLTables(utest_fixture->stmt, NULL, 0, NULL, 0, (SQLCHAR *)"A\\_B",
                      SQL_NTS, NULL, 0),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 3), "A_B");
}

UTEST_F(db, 6_63_tables_metadata_id) {
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_METADATA_ID,
                           (SQLPOINTER)SQL_TRUE, 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLTables(utest_fixture->stmt, (SQLCHAR *)"", 0, NULL, 0,
                      (SQLCHAR *)"T", SQL_NTS, NULL, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
}
