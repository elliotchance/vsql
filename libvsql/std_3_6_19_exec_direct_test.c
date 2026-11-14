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

/* A DELETE, INSERT or UPDATE of no rows raises a completion condition: no
 * data, which doesn't have a status record. It's still executed (with a row
 * count of 0) and doesn't end the SQL-transaction. 5.2 GR 5.b.ii; ISO/IEC
 * 9075-2:2023(E) 14.9 GR 10, 14.11 GR 9 and 14.14 GR 15. */
UTEST_F(db, 6_19_exec_direct_no_data) {
  const char *statements[] = {
      "DELETE FROM t",
      "DELETE FROM t WHERE x > 1",
      "UPDATE t SET x = 2",
      "INSERT INTO t SELECT * FROM t",
  };
  SQLINTEGER rows;
  size_t i;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  for (i = 0; i < sizeof(statements) / sizeof(statements[0]); i++) {
    rows = 123;
    EXPECT_EQ(run_sql(utest_fixture->stmt, statements[i]), SQL_NO_DATA);
    EXPECT_EQ(diag_int(SQL_HANDLE_STMT, utest_fixture->stmt, SQL_DIAG_NUMBER),
              0);
    EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_SUCCESS);
    EXPECT_EQ(rows, 0);
  }

  ASSERT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (1)"),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "DELETE FROM t WHERE x > 1"),
            SQL_NO_DATA);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "UPDATE t SET x = 2 WHERE x = 1"),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "DELETE FROM t"), SQL_SUCCESS);
  EXPECT_EQ(
      diag_int(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_TRANSACTION_ACTIVE),
      1);
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

/* The cursor statements are done with the CLI routines (such as SQLFetch) and
 * the connection statements with SQLConnect and SQLDisconnect, so they aren't
 * preparable. */
UTEST_F(db, 6_19_exec_direct_not_preparable) {
  const char *statements[] = {
      "DECLARE c CURSOR FOR VALUES 1",
      "OPEN c",
      "FETCH NEXT FROM c",
      "CLOSE c",
      "CONNECT TO DEFAULT",
      "SET CONNECTION DEFAULT",
      "DISCONNECT CURRENT",
  };

  for (size_t i = 0; i < sizeof(statements) / sizeof(statements[0]); i++) {
    EXPECT_EQ(run_sql(utest_fixture->stmt, statements[i]), SQL_ERROR);
    EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "42000");
  }

  /* DISCONNECT wasn't executed. */
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
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

  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS INTEGER)"), SQL_ERROR);
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

/* A parameter that's bound beyond the number of "?" is an error, unless it's
 * been unbound. */
UTEST_F(db, 6_19_exec_direct_too_many_parameters) {
  SQLINTEGER x = 7, y = 8;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_INTEGER, 0, 0, &x, sizeof(x),
                             NULL),
            SQL_SUCCESS);
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 2, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_INTEGER, 0, 0, &y, sizeof(y),
                             NULL),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS INTEGER)"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07001");
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07001");

  ASSERT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_RESET_PARAMS), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
}

/* The IPD must be valid. */
UTEST_F(db, 6_19_exec_direct_invalid_ipd) {
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);
  SQLINTEGER x = 7;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_VARCHAR, 0, 0, &x, sizeof(x),
                             NULL),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS VARCHAR(10))"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07001");

  ASSERT_EQ(SQLSetDescField(ipd, 1, SQL_DESC_LENGTH, INTEGER_VALUE(10), 0),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS VARCHAR(10))"), SQL_SUCCESS);
}

/* The PRECISION of a datetime in the IPD must be valid. */
UTEST_F(db, 6_19_exec_direct_invalid_ipd_datetime_precision) {
  char s[] = "12:34:56";
  SQLSMALLINT invalid[] = {-1, 7, 100};
  size_t i;

  for (i = 0; i < sizeof(invalid) / sizeof(invalid[0]); i++) {
    ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                               SQL_CHAR, SQL_TYPE_TIME, 8, invalid[i], s,
                               sizeof(s), NULL),
              SQL_SUCCESS);
    EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS TIME)"), SQL_ERROR);
    EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07001");
  }

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_CHAR, SQL_TYPE_TIME, 8, 6, s, sizeof(s), NULL),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS TIME)"), SQL_SUCCESS);
}

/* The length of a character parameter must be greater than 0 (zero) or NULL
 * TERMINATED, so an empty string has to be null terminated. */
UTEST_F(db, 6_19_exec_direct_character_length) {
  SQLHDESC apd = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_PARAM_DESC);
  char s[] = "";
  char out[10];
  SQLINTEGER x = 7;
  SQLINTEGER len = 0;
  SQLINTEGER ind = SQL_NULL_DATA;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_CHAR, SQL_VARCHAR, 5, 0, s, sizeof(s), &len),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS VARCHAR(5))"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07001");

  /* A negative length that doesn't have a meaning isn't valid either. */
  len = -100;
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS VARCHAR(5))"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07001");

  /* The length doesn't matter when the value is NULL. */
  len = 0;
  ASSERT_EQ(SQLSetDescField(apd, 1, SQL_DESC_INDICATOR_POINTER, &ind, 0),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS VARCHAR(5))"), SQL_SUCCESS);
  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLSetDescField(apd, 1, SQL_DESC_INDICATOR_POINTER, NULL, 0),
            SQL_SUCCESS);

  len = SQL_NTS;
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES CHAR_LENGTH(?)"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, out, sizeof(out), NULL),
      SQL_SUCCESS);
  EXPECT_STREQ(out, "0");
  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);

  /* The rule is only for character types. */
  len = 0;
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_INTEGER, SQL_INTEGER, 0, 0, &x, sizeof(x),
                             &len),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS VARCHAR(5))"), SQL_SUCCESS);
}

/* A failed statement doesn't replace the executed statement. */
UTEST_F(db, 6_19_exec_direct_failed_keeps_executed) {
  SQLINTEGER rows = 123;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT PRIMARY KEY)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (1)"),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (x) VALUES (1)"),
            SQL_ERROR);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_SUCCESS);
  EXPECT_EQ(rows, 0);
}

/* The cursor of a positioned statement must be of another statement, and an
 * invalid cursor name doesn't destroy the prepared statement. */
UTEST_F(db, 6_19_exec_direct_positioned_invalid_cursor) {
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER)"), SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(utest_fixture->stmt, (SQLCHAR *)"c1", SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT x FROM t"), SQL_SUCCESS);
  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "DELETE FROM t WHERE CURRENT OF c1"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "34000");

  ASSERT_EQ(SQLPrepare(stmt2, (SQLCHAR *)"VALUES 1", SQL_NTS), SQL_SUCCESS);
  EXPECT_EQ(run_sql(stmt2, "DELETE FROM t WHERE CURRENT OF c2"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "34000");
  EXPECT_EQ(SQLExecute(stmt2), SQL_SUCCESS);
}

/* Executing another statement destroys the cursor, and the prepared statements
 * that reference it. They don't use a later cursor with the name. */
UTEST_F(db, 6_19_exec_direct_positioned_destroyed) {
  SQLHSTMT stmt2;
  SQLHSTMT stmt = utest_fixture->stmt;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "CREATE TABLE t (x INTEGER)"), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt2, "INSERT INTO t (x) VALUES (1), (2)"), SQL_SUCCESS);
  ASSERT_EQ(SQLSetCursorName(stmt, (SQLCHAR *)"c1", SQL_NTS), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt, "SELECT x FROM t"), SQL_SUCCESS);
  ASSERT_EQ(SQLPrepare(stmt2, (SQLCHAR *)"DELETE FROM t WHERE CURRENT OF c1",
                       SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(SQLCloseCursor(stmt), SQL_SUCCESS);

  ASSERT_EQ(run_sql(stmt, "SELECT x FROM t"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLExecute(stmt2), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, stmt2, "HY010");

  ASSERT_EQ(SQLCloseCursor(stmt), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt, "SELECT x FROM t"), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(stmt, 1), "1,2");
}
