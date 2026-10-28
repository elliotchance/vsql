#include "test.h"

/* 6.19 ExecDirect */

UTEST_F(db, 6_19_exec_direct_error) {
  SQLCHAR msg[64];
  SQLSMALLINT msg_length;

  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM missing"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "42P01");
  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_STMT, utest_fixture->stmt, 1, NULL, NULL,
                          msg, sizeof(msg), &msg_length),
            SQL_SUCCESS);
  EXPECT_TRUE(strstr((char *)msg, "MISSING") != NULL);
}

UTEST_F(db, 6_19_exec_direct_empty) {
  EXPECT_EQ(SQLExecDirect(utest_fixture->stmt, (SQLCHAR *)"", SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY090");
}

UTEST_F(db, 6_19_exec_direct_negative_length) {
  EXPECT_EQ(SQLExecDirect(utest_fixture->stmt, (SQLCHAR *)"VALUES 1", -10),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY090");
}

UTEST_F(db, 6_19_exec_direct_null_text) {
  EXPECT_EQ(SQLExecDirect(utest_fixture->stmt, NULL, SQL_NTS), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
}

/* A length is used instead of the null terminator. */
UTEST_F(db, 6_19_exec_direct_length) {
  EXPECT_EQ(SQLExecDirect(utest_fixture->stmt,
                          (SQLCHAR *)"CREATE TABLE t (x INT)garbage", 22),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM t"), SQL_SUCCESS);
}

UTEST_F(db, 6_19_exec_direct_open_cursor) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

/* A transaction is started when there isn't one, and it stays active after an
 * error. */
UTEST_F(db, 6_19_exec_direct_starts_transaction) {
  EXPECT_EQ(
      diag_int(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_TRANSACTION_ACTIVE),
      0);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "SELECT * FROM bar"), SQL_ERROR);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_TRANSACTION_ACTIVE),
      1);
}

/* A transaction is ended with EndTran. */
UTEST_F(db, 6_19_exec_direct_transaction_statements) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "START TRANSACTION"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "42000");
  EXPECT_EQ(run_sql(utest_fixture->stmt, "COMMIT"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "42000");
  EXPECT_EQ(run_sql(utest_fixture->stmt, " rollback"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "42000");
}

UTEST_F(db, 6_19_exec_direct_simple_comment) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1 -- one"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "42000");
}

/* "--" in a literal or a delimited identifier isn't a simple comment. */
UTEST_F(db, 6_19_exec_direct_not_simple_comment) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES '--', 'it''s --'"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt,
                    "SELECT x AS \"a--\" FROM (VALUES 1) AS t (x)"),
            SQL_SUCCESS);
}

/* A bracketed comment is allowed, and "--" inside one isn't a simple comment.
 * (The statement is a syntax error, rather than 42000, until vsql supports
 * bracketed comments.) */
UTEST_F(db, 6_19_exec_direct_bracketed_comment) {
  run_sql(utest_fixture->stmt, "VALUES 1 /* -- not a simple comment */");
  EXPECT_STRNE(sqlstate(SQL_HANDLE_STMT, utest_fixture->stmt), "42000");
}

/* Every parameter must be bound. */
UTEST_F(db, 6_19_exec_direct_parameters) {
  SQLINTEGER x = 7, y = 0;

  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES ?"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07001");

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_INTEGER, 0, 0, &x, sizeof(x),
                             NULL),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES ? + 1"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_INTEGER, &y, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(y, 8);
}

/* The IPD must be valid. */
UTEST_F(db, 6_19_exec_direct_invalid_ipd) {
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);
  SQLINTEGER x = 7;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_VARCHAR, 0, 0, &x, sizeof(x),
                             NULL),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES ?"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07001");

  ASSERT_EQ(SQLSetDescField(ipd, 1, SQL_DESC_LENGTH, INTEGER_VALUE(10), 0),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES ?"), SQL_SUCCESS);
}
