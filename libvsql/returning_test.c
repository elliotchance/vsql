#include "test.h"

/* An INSERT, UPDATE or DELETE with RETURNING (V119-01, V113-02 and V112-02) can
 * be prepared and described before it's executed, and then its rows are
 * fetched like the rows of a query. The row count is the number of rows that
 * it changed. */
UTEST_F(db, returning_prepare) {
  struct column col;
  SQLSMALLINT columns = 0;
  SQLINTEGER rows = 0;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT, y INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLPrepare(utest_fixture->stmt,
                       (SQLCHAR *)"INSERT INTO t (x) VALUES (1), (2) "
                                  "RETURNING x * 10 AS z, y",
                       SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLNumResultCols(utest_fixture->stmt, &columns), SQL_SUCCESS);
  EXPECT_EQ(columns, 2);
  EXPECT_EQ(describe(utest_fixture->stmt, 1, &col), SQL_SUCCESS);
  EXPECT_STREQ((char *)col.name, "Z");
  EXPECT_EQ(describe(utest_fixture->stmt, 2, &col), SQL_SUCCESS);
  EXPECT_STREQ((char *)col.name, "Y");

  EXPECT_EQ(SQLExecute(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_SUCCESS);
  EXPECT_EQ(rows, 2);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 1), "10,20");
}

UTEST_F(db, returning_exec_direct) {
  SQLSMALLINT columns = 0;
  SQLINTEGER rows = 0;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (1), (2)"),
            SQL_SUCCESS);

  ASSERT_EQ(run_sql(utest_fixture->stmt, "UPDATE t SET x = x + 1 RETURNING x"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLNumResultCols(utest_fixture->stmt, &columns), SQL_SUCCESS);
  EXPECT_EQ(columns, 1);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 1), "2,3");

  ASSERT_EQ(
      run_sql(utest_fixture->stmt, "DELETE FROM t WHERE x = 3 RETURNING x"),
      SQL_SUCCESS);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_SUCCESS);
  EXPECT_EQ(rows, 1);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 1), "3");

  /* It's the same as a query of a data change delta table (T495), which has
   * a cursor. */
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "SELECT x FROM NEW TABLE (INSERT INTO t (x) VALUES (4))"),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 1), "4");
}
