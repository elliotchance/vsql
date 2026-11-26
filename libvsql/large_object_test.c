#include "test.h"

/*
 * A CHARACTER LARGE OBJECT is SQL_CLOB (40) and a BINARY LARGE OBJECT is
 * SQL_BLOB (30). The C data type of a CLOB is a character string (the same as
 * SQL_CHAR), and of a BLOB is an array of octets (the same as SQL_BINARY).
 * There are no locators (T041).
 */

UTEST_F(db, lob_describe_col) {
  struct column col;
  SQLHDESC ird;
  SQLINTEGER n = 0;

  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE t (a CLOB(10), b BLOB(20), c CLOB)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT a, b, c FROM t"),
            SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 1, &col), SQL_SUCCESS);
  EXPECT_EQ(col.type, SQL_CLOB);
  EXPECT_EQ(col.size, 40);
  EXPECT_EQ(col.digits, 0);
  EXPECT_EQ(describe(utest_fixture->stmt, 2, &col), SQL_SUCCESS);
  EXPECT_EQ(col.type, SQL_BLOB);
  EXPECT_EQ(col.size, 20);
  EXPECT_EQ(SQLColAttribute(utest_fixture->stmt, 2, SQL_DESC_TYPE, NULL, 0,
                            NULL, &n),
            SQL_SUCCESS);
  EXPECT_EQ(n, SQL_BLOB);

  ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);
  EXPECT_EQ(desc_short(ird, 1, SQL_DESC_TYPE), SQL_CLOB);
  EXPECT_EQ(desc_int(ird, 1, SQL_DESC_LENGTH), 10);
  EXPECT_EQ(desc_int(ird, 1, SQL_DESC_OCTET_LENGTH), 40);
  EXPECT_STREQ(desc_string(ird, 1, SQL_DESC_CHARACTER_SET_NAME), "UTF8");
  EXPECT_EQ(desc_short(ird, 2, SQL_DESC_TYPE), SQL_BLOB);
  EXPECT_EQ(desc_int(ird, 2, SQL_DESC_LENGTH), 20);
  EXPECT_EQ(desc_int(ird, 2, SQL_DESC_OCTET_LENGTH), 20);

  /* Without a length, it's the maximum length. */
  EXPECT_EQ(desc_int(ird, 3, SQL_DESC_LENGTH), 2147483647);
  EXPECT_EQ(desc_int(ird, 3, SQL_DESC_OCTET_LENGTH), 2147483647);
}

/* A CLOB is retrieved as a character string, and a BLOB as a binary string. */
UTEST_F(db, lob_get_data) {
  char s[10];
  unsigned char b[10];
  SQLINTEGER len = 0;

  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "VALUES (CAST('hello' AS CLOB), CAST(X'0001FF' AS BLOB))"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_CLOB, s, sizeof(s), &len),
            SQL_SUCCESS);
  EXPECT_EQ(len, 5);
  EXPECT_STREQ(s, "hello");
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_DEFAULT, s, sizeof(s), &len),
            SQL_SUCCESS);
  EXPECT_STREQ(s, "hello");
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, s, 3, &len),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "01004");
  EXPECT_STREQ(s, "he");

  memset(b, 7, sizeof(b));
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 2, SQL_BLOB, b, sizeof(b), &len),
            SQL_SUCCESS);
  EXPECT_EQ(len, 3);
  EXPECT_EQ(memcmp(b, "\x00\x01\xff\x07", 4), 0);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 2, SQL_DEFAULT, b, sizeof(b), &len),
            SQL_SUCCESS);
  EXPECT_EQ(len, 3);

  /* A BLOB can't be retrieved as a character string. */
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 2, SQL_CHAR, s, sizeof(s), NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07006");
}

UTEST_F(db, lob_bind_col) {
  char s[4];
  unsigned char b[4];
  SQLINTEGER s_len = 0, b_len = 0;

  ASSERT_EQ(SQLBindCol(utest_fixture->stmt, 1, SQL_CLOB, s, sizeof(s), &s_len),
            SQL_SUCCESS);
  ASSERT_EQ(SQLBindCol(utest_fixture->stmt, 2, SQL_BLOB, b, sizeof(b), &b_len),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "VALUES (CAST('abc' AS CLOB), CAST(X'CAFE' AS BLOB))"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(s_len, 3);
  EXPECT_STREQ(s, "abc");
  EXPECT_EQ(b_len, 2);
  EXPECT_EQ(memcmp(b, "\xca\xfe", 2), 0);
}

/* A CLOB and a BLOB parameter are inserted into a CLOB and a BLOB column. */
UTEST_F(db, lob_bind_parameter) {
  unsigned char in[] = {0xab, 0x00, 0xcd}, b[4];
  SQLINTEGER in_len = 3, len = 0;
  char s[10];
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);

  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (a CLOB, b BLOB(4))"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_CLOB, SQL_CLOB, 100, 0, (SQLPOINTER) "hi", 0,
                             NULL),
            SQL_SUCCESS);
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 2, SQL_PARAM_MODE_IN,
                             SQL_BLOB, SQL_BLOB, 4, 0, in, 0, &in_len),
            SQL_SUCCESS);
  EXPECT_EQ(desc_short(ipd, 1, SQL_DESC_TYPE), SQL_CLOB);
  EXPECT_EQ(desc_int(ipd, 1, SQL_DESC_LENGTH), 100);
  EXPECT_EQ(desc_short(ipd, 2, SQL_DESC_TYPE), SQL_BLOB);
  EXPECT_EQ(desc_int(ipd, 2, SQL_DESC_LENGTH), 4);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (a, b) VALUES (?, ?)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_UNBIND_PARAMETERS),
            SQL_SUCCESS);

  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT a, b FROM t"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, s, sizeof(s), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ(s, "hi");
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 2, SQL_BLOB, b, sizeof(b), &len),
            SQL_SUCCESS);
  EXPECT_EQ(len, 3);
  EXPECT_EQ(memcmp(b, "\xab\x00\xcd", 3), 0);
  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);

  /* A character string can't be a BLOB. */
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_CHAR, SQL_BLOB, 4, 0, (SQLPOINTER) "ab", 0,
                             NULL),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS BLOB)"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07006");
}

UTEST_F(db, lob_columns) {
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE t (a CLOB(10), b BLOB(20))"),
            SQL_SUCCESS);

#define COLUMNS(column)                                                        \
  (SQLColumns(utest_fixture->stmt, NULL, 0, NULL, 0, (SQLCHAR *)"T", SQL_NTS,  \
              NULL, 0) == SQL_SUCCESS                                          \
       ? fetch_strings(utest_fixture->stmt, column)                            \
       : "(error)")

  EXPECT_STREQ(COLUMNS(5), "40,30");
  EXPECT_STREQ(COLUMNS(6), "CHARACTER LARGE OBJECT,BINARY LARGE OBJECT");
  EXPECT_STREQ(COLUMNS(7), "10,20");
  EXPECT_STREQ(COLUMNS(8), "40,20");
  EXPECT_STREQ(COLUMNS(14), "40,30");
  EXPECT_STREQ(COLUMNS(15), "NULL,NULL");
#undef COLUMNS
}

UTEST_F(db, lob_get_type_info) {
  ASSERT_EQ(SQLGetTypeInfo(utest_fixture->stmt, SQL_CLOB), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 1), "CHARACTER LARGE OBJECT");
  ASSERT_EQ(SQLGetTypeInfo(utest_fixture->stmt, SQL_BLOB), SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 4), "X'");
}

UTEST_F(db, lob_set_desc_field) {
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);
  SQLHDESC apd = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_PARAM_DESC);

  /* Setting TYPE sets the default LENGTH, which is the maximum length, and the
   * character set of a CLOB. */
  ASSERT_EQ(
      SQLSetDescField(ipd, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_CLOB), 0),
      SQL_SUCCESS);
  EXPECT_EQ(desc_int(ipd, 1, SQL_DESC_LENGTH), 2147483647);
  EXPECT_STREQ(desc_string(ipd, 1, SQL_DESC_CHARACTER_SET_NAME), "UTF8");
  ASSERT_EQ(
      SQLSetDescField(ipd, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_BLOB), 0),
      SQL_SUCCESS);
  EXPECT_EQ(desc_int(ipd, 1, SQL_DESC_LENGTH), 2147483647);

  /* The LENGTH must be at least 1 (one) when the DATA_POINTER is set. */
  ASSERT_EQ(SQLSetDescField(ipd, 1, SQL_DESC_LENGTH, INTEGER_VALUE(0), 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLSetDescField(ipd, 1, SQL_DESC_DATA_POINTER, (SQLPOINTER) "1", 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ipd, "HY021");

  /* Both are application data types, but their locators aren't supported. */
  EXPECT_EQ(
      SQLSetDescField(apd, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_CLOB), 0),
      SQL_SUCCESS);
  EXPECT_EQ(
      SQLSetDescField(apd, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_BLOB), 0),
      SQL_SUCCESS);
  EXPECT_EQ(SQLSetDescField(apd, 1, SQL_DESC_TYPE,
                            SMALLINT_VALUE(SQL_CLOB_LOCATOR), 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, apd, "HYC00");
}

/* A CLOB and a BLOB can be given in pieces. */
UTEST_F(db, lob_put_data) {
  SQLINTEGER at_exec = SQL_DATA_AT_EXEC, len = 0;
  char s[10];
  unsigned char b[10];
  SQLPOINTER p;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_CLOB, SQL_CLOB, 10, 0, s, sizeof(s),
                             &at_exec),
            SQL_SUCCESS);
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 2, SQL_PARAM_MODE_IN,
                             SQL_BLOB, SQL_BLOB, 10, 0, b, sizeof(b),
                             &at_exec),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "VALUES (CAST(? AS CLOB), CAST(? AS BLOB))"),
            SQL_NEED_DATA);
  ASSERT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_NEED_DATA);
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, (SQLPOINTER) "ab", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, (SQLPOINTER) "c", SQL_NTS),
            SQL_SUCCESS);
  ASSERT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_NEED_DATA);
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, (SQLPOINTER) "\x01\x00", 2),
            SQL_SUCCESS);
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, (SQLPOINTER) "\x02", 1),
            SQL_SUCCESS);
  EXPECT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, s, sizeof(s), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ(s, "abc");
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 2, SQL_BLOB, b, sizeof(b), &len),
            SQL_SUCCESS);
  EXPECT_EQ(len, 3);
  EXPECT_EQ(memcmp(b, "\x01\x00\x02", 3), 0);
}

/* The IPD of a dynamic parameter has the large object type of the column. */
UTEST_F(db, lob_prepare) {
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);

  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (a CLOB(5), b BLOB(6))"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLPrepare(utest_fixture->stmt,
                       (SQLCHAR *)"INSERT INTO t (a, b) VALUES (?, ?)",
                       SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(desc_short(ipd, 1, SQL_DESC_TYPE), SQL_CLOB);
  EXPECT_EQ(desc_int(ipd, 1, SQL_DESC_LENGTH), 5);
  EXPECT_EQ(desc_short(ipd, 2, SQL_DESC_TYPE), SQL_BLOB);
  EXPECT_EQ(desc_int(ipd, 2, SQL_DESC_LENGTH), 6);
}
