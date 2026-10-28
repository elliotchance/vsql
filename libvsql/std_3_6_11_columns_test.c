#include "test.h"

/* 6.11 Columns */

UTEST_F(db, 6_11_columns) {
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE t (a INT NOT NULL, b VARCHAR(10) DEFAULT "
                    "'x', c NUMERIC(5, 2), d TIMESTAMP(3))"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE u (x INT)"),
            SQL_SUCCESS);

#define COLUMNS(column)                                                        \
  (SQLColumns(utest_fixture->stmt, NULL, 0, NULL, 0, (SQLCHAR *)"T", SQL_NTS,  \
              NULL, 0) == SQL_SUCCESS                                          \
       ? fetch_strings(utest_fixture->stmt, column)                            \
       : "(error)")

  EXPECT_STREQ(COLUMNS(1), ":memory:,:memory:,:memory:,:memory:");
  EXPECT_STREQ(COLUMNS(2), "PUBLIC,PUBLIC,PUBLIC,PUBLIC");
  EXPECT_STREQ(COLUMNS(3), "T,T,T,T");
  EXPECT_STREQ(COLUMNS(4), "A,B,C,D");
  EXPECT_STREQ(COLUMNS(5), "4,12,2,93");
  EXPECT_STREQ(COLUMNS(6), "INTEGER,CHARACTER VARYING,NUMERIC,TIMESTAMP");
  EXPECT_STREQ(COLUMNS(7), "10,10,5,23");
  EXPECT_STREQ(COLUMNS(9), "0,NULL,2,3");
  EXPECT_STREQ(COLUMNS(10), "2,NULL,10,NULL");
  EXPECT_STREQ(COLUMNS(11), "0,1,1,1");
  EXPECT_STREQ(COLUMNS(13), "NULL,'x',NULL,NULL");
  EXPECT_STREQ(COLUMNS(14), "4,12,2,9");
  EXPECT_STREQ(COLUMNS(15), "NULL,NULL,NULL,3");
  EXPECT_STREQ(COLUMNS(16), "NULL,40,NULL,NULL");
  EXPECT_STREQ(COLUMNS(17), "1,2,3,4");
  EXPECT_STREQ(COLUMNS(18), "NO,YES,YES,YES");
  EXPECT_STREQ(COLUMNS(21), "NULL,UTF8,NULL,NULL");
#undef COLUMNS
}

/* The names are patterns. */
UTEST_F(db, 6_11_columns_pattern) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (a_b INT, axb INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLColumns(utest_fixture->stmt, NULL, 0, NULL, 0, (SQLCHAR *)"%",
                       SQL_NTS, (SQLCHAR *)"A\\_%", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 4), "A_B");
  ASSERT_EQ(SQLColumns(utest_fixture->stmt, NULL, 0, NULL, 0, (SQLCHAR *)"T",
                       SQL_NTS, (SQLCHAR *)"A_B", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 4), "A_B,AXB");
}

/* With METADATA ID, the names are identifiers. */
UTEST_F(db, 6_11_columns_metadata_id) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (a INT, \"b\" INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_METADATA_ID,
                           (SQLPOINTER)SQL_TRUE, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLColumns(utest_fixture->stmt, (SQLCHAR *)"", SQL_NTS,
                       (SQLCHAR *)"public", SQL_NTS, (SQLCHAR *)"t", SQL_NTS,
                       (SQLCHAR *)"a", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 4), "A");
  ASSERT_EQ(SQLColumns(utest_fixture->stmt, (SQLCHAR *)"", SQL_NTS,
                       (SQLCHAR *)"public", SQL_NTS, (SQLCHAR *)"t", SQL_NTS,
                       (SQLCHAR *)"\"b\"", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 4), "b");
  ASSERT_EQ(SQLColumns(utest_fixture->stmt, (SQLCHAR *)"", SQL_NTS,
                       (SQLCHAR *)"public", SQL_NTS, (SQLCHAR *)"t", SQL_NTS,
                       (SQLCHAR *)"\"B\"", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 4), "");

  EXPECT_EQ(SQLColumns(utest_fixture->stmt, NULL, 0, (SQLCHAR *)"public",
                       SQL_NTS, (SQLCHAR *)"t", SQL_NTS, (SQLCHAR *)"a",
                       SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
}

UTEST_F(db, 6_11_columns_invalid) {
  EXPECT_EQ(SQLColumns(utest_fixture->stmt, NULL, 0, NULL, 0, (SQLCHAR *)"T",
                       -5, NULL, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY090");
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLColumns(utest_fixture->stmt, NULL, 0, NULL, 0, NULL, 0, NULL, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}
