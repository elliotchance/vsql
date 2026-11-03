#include "test.h"

/* 6.51 PrimaryKeys */

UTEST_F(db, 6_51_primary_keys) {
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE t (a INT, b INT, PRIMARY KEY (b, a))"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLPrimaryKeys(utest_fixture->stmt, NULL, 0, NULL, 0,
                           (SQLCHAR *)"T", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 4), "B,A");
  ASSERT_EQ(SQLPrimaryKeys(utest_fixture->stmt, NULL, 0, NULL, 0,
                           (SQLCHAR *)"T", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 5), "1,2");
  ASSERT_EQ(SQLPrimaryKeys(utest_fixture->stmt, (SQLCHAR *)":memory:", SQL_NTS,
                           (SQLCHAR *)"PUBLIC", SQL_NTS, (SQLCHAR *)"T",
                           SQL_NTS),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 6),
               "T_PRIMARY_KEY,T_PRIMARY_KEY");
}

/* The name isn't a pattern, and a table without a PRIMARY KEY has no rows. */
UTEST_F(db, 6_51_primary_keys_none) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (a INT PRIMARY KEY)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE u (a INT UNIQUE)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLPrimaryKeys(utest_fixture->stmt, NULL, 0, NULL, 0,
                           (SQLCHAR *)"%", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 4), "");
  ASSERT_EQ(SQLPrimaryKeys(utest_fixture->stmt, NULL, 0, NULL, 0,
                           (SQLCHAR *)"U", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 4), "");
}

UTEST_F(db, 6_51_primary_keys_null_table) {
  EXPECT_EQ(SQLPrimaryKeys(utest_fixture->stmt, NULL, 0, NULL, 0, NULL, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
}

/* The null pointers are checked before any length is read. */
UTEST_F(db, 6_51_primary_keys_null_pointer_before_length) {
  EXPECT_EQ(SQLPrimaryKeys(utest_fixture->stmt, NULL, 0, (SQLCHAR *)"A", -5,
                           NULL, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");

  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_METADATA_ID,
                           INTEGER_VALUE(SQL_TRUE), 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLPrimaryKeys(utest_fixture->stmt, NULL, 0, (SQLCHAR *)"A", -5,
                           (SQLCHAR *)"T", SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
}
