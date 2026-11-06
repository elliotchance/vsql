#include "test.h"

/* 6.33 GetDiagField, General Rules 11.f: The value of MORE, and the conditions
 * that are in the diagnostics area, which depend on the DIAGNOSTICS SIZE. */

#define TWO_WARNINGS                                                           \
  "SELECT CAST('abc' AS CHAR(1)) AS a, CAST('xyz' AS CHAR(1)) AS b "           \
  "FROM (VALUES 1) AS t (x)"

UTEST_F(db, 6_33_get_diag_field_more_every_condition_kept) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, TWO_WARNINGS), SQL_SUCCESS_WITH_INFO);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "01004");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_NUMBER), 2);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_MORE), 0);
}

UTEST_F(db, 6_33_get_diag_field_more_condition_dropped) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SET TRANSACTION DIAGNOSTICS SIZE 1"),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, TWO_WARNINGS), SQL_SUCCESS_WITH_INFO);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "01004");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_NUMBER), 1);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_MORE), 1);

  /* The next statement of the SQL-transaction starts again. */
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_NUMBER), 0);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_MORE), 0);
}

UTEST_F(db, 6_33_get_diag_field_more_conditions_fit) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SET TRANSACTION DIAGNOSTICS SIZE 2"),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, TWO_WARNINGS), SQL_SUCCESS_WITH_INFO);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_NUMBER), 2);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_MORE), 0);
}

/* The exception condition is the first condition, so it needs a condition area
 * of its own. */
UTEST_F(db, 6_33_get_diag_field_more_exception) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SET TRANSACTION DIAGNOSTICS SIZE 1"),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt,
                    "SELECT CAST('abc' AS CHAR(1)) AS a, 1 / x AS b "
                    "FROM (VALUES 0) AS t (x)"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "22012");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_NUMBER), 1);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_MORE), 1);
}

UTEST_F(db, 6_33_get_diag_field_more_exception_fits) {
  EXPECT_EQ(run_sql(utest_fixture->stmt,
                    "SELECT CAST('abc' AS CHAR(1)) AS a, 1 / x AS b "
                    "FROM (VALUES 0) AS t (x)"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "22012");
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_NUMBER), 2);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_MORE), 0);
}

/* A <set transaction statement> doesn't initiate an SQL-transaction, and can't
 * be executed in one. The limit is only for the next SQL-transaction. */
UTEST_F(db, 6_33_get_diag_field_more_set_transaction) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SET TRANSACTION DIAGNOSTICS SIZE 1"),
            SQL_SUCCESS);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_TRANSACTION_ACTIVE),
      0);

  EXPECT_EQ(run_sql(utest_fixture->stmt, TWO_WARNINGS), SQL_SUCCESS_WITH_INFO);
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SET TRANSACTION DIAGNOSTICS SIZE 1"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "25001");

  EXPECT_EQ(SQLEndTran(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_COMMIT),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, TWO_WARNINGS), SQL_SUCCESS_WITH_INFO);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_NUMBER), 2);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_MORE), 0);
}

/* A warning of a <set transaction statement>, when the limit is too big. */
UTEST_F(db, 6_33_get_diag_field_more_limit_reduced) {
  EXPECT_EQ(
      run_sql(utest_fixture->stmt, "SET TRANSACTION DIAGNOSTICS SIZE 101"),
      SQL_SUCCESS_WITH_INFO);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "01012");
}

/* A completion condition: no data doesn't have a status record. */
UTEST_F(db, 6_33_get_diag_field_more_no_data) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE foo (x INTEGER)"),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "DELETE FROM foo"), SQL_NO_DATA);
  EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_NUMBER), 0);
}
