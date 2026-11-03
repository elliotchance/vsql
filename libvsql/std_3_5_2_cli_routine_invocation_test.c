#include "test.h"

/* 5.2 <CLI routine> invocation */

/* A statement that fails has no effect, even though the SQL-transaction is
 * still active. */
UTEST_F(db, 5_2_failed_statement_has_no_effect) {
  SQLINTEGER count = 0;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (1)"),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (2), (1 / 0)"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "22012");
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT COUNT(*) FROM t"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_INTEGER, &count, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(count, 1);
}
