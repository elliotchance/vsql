#include "test.h"

/*
 * BINARY and BINARY VARYING aren't in SQL/CLI 2003, so their codes are
 * SQL_BINARY (60) and SQL_VARBINARY (61), which are their codes in dynamic SQL
 * (Table 30 of Part 2). The C data type of both is an array of octets, with a
 * length in octets.
 */

UTEST_F(db, binary_describe_col) {
  struct column col;
  SQLHDESC ird;

  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE t (a BINARY(3), b VARBINARY(10))"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT a, b FROM t"), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 1, &col), SQL_SUCCESS);
  EXPECT_EQ(col.type, SQL_BINARY);
  EXPECT_EQ(col.size, 3);
  EXPECT_EQ(col.digits, 0);
  EXPECT_EQ(describe(utest_fixture->stmt, 2, &col), SQL_SUCCESS);
  EXPECT_EQ(col.type, SQL_VARBINARY);
  EXPECT_EQ(col.size, 10);

  ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);
  EXPECT_EQ(desc_short(ird, 1, SQL_DESC_TYPE), SQL_BINARY);
  EXPECT_EQ(desc_int(ird, 1, SQL_DESC_LENGTH), 3);
  EXPECT_EQ(desc_int(ird, 1, SQL_DESC_OCTET_LENGTH), 3);
  EXPECT_EQ(desc_short(ird, 2, SQL_DESC_TYPE), SQL_VARBINARY);
  EXPECT_EQ(desc_int(ird, 2, SQL_DESC_LENGTH), 10);
}

/* The octets are retrieved without a null terminator, in pieces if the buffer
 * is too small. */
UTEST_F(db, binary_get_data) {
  unsigned char b[10];
  SQLINTEGER len = 0;

  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "VALUES (X'0001FF', CAST(X'0A' AS BINARY(3)))"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  memset(b, 7, sizeof(b));
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_VARBINARY, b, sizeof(b),
                       &len),
            SQL_SUCCESS);
  EXPECT_EQ(len, 3);
  EXPECT_EQ(memcmp(b, "\x00\x01\xff\x07", 4), 0);

  /* A BINARY is padded with X'00', and can be retrieved as SQL_DEFAULT. */
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 2, SQL_DEFAULT, b, sizeof(b),
                       &len),
            SQL_SUCCESS);
  EXPECT_EQ(len, 3);
  EXPECT_EQ(memcmp(b, "\x0a\x00\x00", 3), 0);

  /* In pieces, each up to the length of the buffer. */
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_BINARY, b, 2, &len),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "01004");
  EXPECT_EQ(len, 3);
  EXPECT_EQ(memcmp(b, "\x00\x01", 2), 0);

  /* The rest must be retrieved as a binary string. */
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, b, 2, &len),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07009");
}

UTEST_F(db, binary_get_data_pieces) {
  unsigned char b[10];
  SQLINTEGER len = 0;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES X'0001FF'"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_BINARY, b, 2, &len),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_BINARY, b, 2, &len),
            SQL_SUCCESS);
  EXPECT_EQ(len, 1);
  EXPECT_EQ(b[0], 0xff);

  /* The buffer must have room for at least one octet. */
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_BINARY, b, 0, &len),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY090");
}

/* A binary string can only be retrieved as a binary string, and the other way
 * around. */
UTEST_F(db, binary_get_data_restricted) {
  char s[10];
  unsigned char b[10];

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES (X'00', 'a')"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, s, sizeof(s), NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07006");
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, 2, SQL_BINARY, b, sizeof(b), NULL),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07006");
}

UTEST_F(db, binary_bind_col) {
  unsigned char b[4];
  SQLINTEGER len = 0;

  ASSERT_EQ(SQLBindCol(utest_fixture->stmt, 1, SQL_VARBINARY, b, sizeof(b),
                       &len),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES X'CAFE'"), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(len, 2);
  EXPECT_EQ(memcmp(b, "\xca\xfe", 2), 0);
  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);

  /* A value that doesn't fit is truncated. */
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES X'0102030405'"), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS_WITH_INFO);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "01004");
  EXPECT_EQ(len, 5);
  EXPECT_EQ(memcmp(b, "\x01\x02\x03\x04", 4), 0);
}

/* The length of a binary string parameter is StrLen_or_Ind, or BufferLength
 * if that's a null pointer. A X'00' octet is part of the value. */
UTEST_F(db, binary_bind_parameter) {
  unsigned char in[] = {0x00, 0x01, 0xff}, out[10];
  SQLINTEGER in_len = 2, len = 0;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_VARBINARY, SQL_VARBINARY, 10, 0, in, 0,
                             &in_len),
            SQL_SUCCESS);
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 2, SQL_PARAM_MODE_IN,
                             SQL_BINARY, SQL_BINARY, 4, 0, in, sizeof(in),
                             NULL),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES (CAST(? AS VARBINARY(10)), CAST(? AS BINARY(4)))"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_BINARY, out, sizeof(out),
                       &len),
            SQL_SUCCESS);
  EXPECT_EQ(len, 2);
  EXPECT_EQ(memcmp(out, "\x00\x01", 2), 0);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 2, SQL_BINARY, out, sizeof(out),
                       &len),
            SQL_SUCCESS);
  EXPECT_EQ(len, 4);
  EXPECT_EQ(memcmp(out, "\x00\x01\xff\x00", 4), 0);
  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);

  /* The length can be NULL TERMINATED, which is the octets before X'00'. */
  in_len = SQL_NTS;
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES (CAST(? AS VARBINARY(10)), CAST(? AS BINARY(4)))"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_BINARY, out, sizeof(out),
                       &len),
            SQL_SUCCESS);
  EXPECT_EQ(len, 0);
}

/* The length of a binary string parameter must be greater than 0 (zero) or NULL
 * TERMINATED, the same as a character string, so an empty string of either kind
 * has to be null terminated. */
UTEST_F(db, binary_bind_parameter_empty) {
  unsigned char in[] = {0x00, 0x01};
  SQLINTEGER in_len = 0, len = 0;
  char out[4];

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_BINARY, SQL_VARBINARY, 4, 0, in, 0, &in_len),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS VARBINARY(4))"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07001");

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_CHAR, SQL_VARCHAR, 4, 0, (SQLPOINTER) "ab", 0,
                             &in_len),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS VARCHAR(4))"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07001");

  /* A character large object and a binary large object are the same. */
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_CLOB, SQL_CLOB, 4, 0, (SQLPOINTER) "ab", 0,
                             &in_len),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CHAR_LENGTH(CAST(? AS CLOB(4)))"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07001");
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_BLOB, SQL_BLOB, 4, 0, in, 0, &in_len),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS BLOB(4))"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07001");

  /* A null terminated binary string ends at the first X'00'. */
  in_len = SQL_NTS;
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_BINARY, SQL_VARBINARY, 4, 0, in, 0, &in_len),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS VARBINARY(4))"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_BINARY, out, sizeof(out),
                       &len),
            SQL_SUCCESS);
  EXPECT_EQ(len, 0);
}

/* A binary string parameter is inserted into a binary string column, and only
 * a binary string can be. */
UTEST_F(db, binary_bind_parameter_insert) {
  unsigned char in[] = {0xab, 0xcd}, out[4];
  SQLINTEGER in_len = 2, len = 0;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (b VARBINARY(4))"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_BINARY, SQL_VARBINARY, 4, 0, in, 0, &in_len),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (b) VALUES (?)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_UNBIND_PARAMETERS),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "SELECT b FROM t"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_BINARY, out, sizeof(out),
                       &len),
            SQL_SUCCESS);
  EXPECT_EQ(len, 2);
  EXPECT_EQ(memcmp(out, "\xab\xcd", 2), 0);
  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_CHAR, SQL_VARCHAR, 4, 0, (SQLPOINTER) "ab", 0,
                             NULL),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "INSERT INTO t (b) VALUES (?)"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07006");

  /* A binary string can't be cast to a character string. */
  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_BINARY, SQL_VARCHAR, 4, 0, in, 0, &in_len),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS VARCHAR(4))"),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07006");
}

/* A binary string can be given in pieces. */
UTEST_F(db, binary_put_data) {
  SQLINTEGER at_exec = SQL_DATA_AT_EXEC, len = 0;
  unsigned char b[10];
  SQLPOINTER p;

  ASSERT_EQ(SQLBindParameter(utest_fixture->stmt, 1, SQL_PARAM_MODE_IN,
                             SQL_VARBINARY, SQL_VARBINARY, 10, 0, b, sizeof(b),
                             &at_exec),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(? AS VARBINARY(10))"),
            SQL_NEED_DATA);
  ASSERT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_NEED_DATA);
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, (SQLPOINTER) "\x01\x00", 2),
            SQL_SUCCESS);
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, (SQLPOINTER) "\x02", 1),
            SQL_SUCCESS);

  /* The length can't be negative. */
  EXPECT_EQ(SQLPutData(utest_fixture->stmt, (SQLPOINTER) "\x02", SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY024");

  EXPECT_EQ(SQLParamData(utest_fixture->stmt, &p), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_VARBINARY, b, sizeof(b),
                       &len),
            SQL_SUCCESS);
  EXPECT_EQ(len, 3);
  EXPECT_EQ(memcmp(b, "\x01\x00\x02", 3), 0);
}

UTEST_F(db, binary_ipd_type) {
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);
  SQLHDESC apd = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_PARAM_DESC);

  /* Setting TYPE sets the default LENGTH, which is the maximum length. */
  ASSERT_EQ(
      SQLSetDescField(ipd, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_BINARY), 0),
      SQL_SUCCESS);
  EXPECT_EQ(desc_int(ipd, 1, SQL_DESC_LENGTH), 10485760);
  ASSERT_EQ(
      SQLSetDescField(ipd, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_VARBINARY), 0),
      SQL_SUCCESS);
  EXPECT_EQ(desc_int(ipd, 1, SQL_DESC_LENGTH), 10485760);

  /* The LENGTH must be at least 1 (one) when the DATA_POINTER is set. */
  ASSERT_EQ(SQLSetDescField(ipd, 1, SQL_DESC_LENGTH, INTEGER_VALUE(0), 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLSetDescField(ipd, 1, SQL_DESC_DATA_POINTER, (SQLPOINTER) "1", 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ipd, "HY021");

  /* Both are application data types. */
  EXPECT_EQ(
      SQLSetDescField(apd, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_BINARY), 0),
      SQL_SUCCESS);
  EXPECT_EQ(
      SQLSetDescField(apd, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_VARBINARY), 0),
      SQL_SUCCESS);
}
