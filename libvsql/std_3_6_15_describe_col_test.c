#include "test.h"

/* 6.15 DescribeCol */

#define DESCRIBE_SQL                                                           \
  "CREATE TABLE t (a INT NOT NULL, bb VARCHAR(20), c NUMERIC(10, 2), d DATE, " \
  "e DOUBLE PRECISION)"

static SQLRETURN select_describe_table(SQLHSTMT stmt) {
  SQLRETURN rc = run_sql(stmt, DESCRIBE_SQL);

  return rc == SQL_SUCCESS ? run_sql(stmt, "SELECT * FROM t") : rc;
}

UTEST_F(db, 6_15_describe_col_no_statement) {
  struct column col;

  EXPECT_EQ(describe(utest_fixture->stmt, 1, &col), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

UTEST_F(db, 6_15_describe_col_not_a_query) {
  struct column col;

  ASSERT_EQ(run_sql(utest_fixture->stmt, DESCRIBE_SQL), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 1, &col), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07005");
}

UTEST_F(db, 6_15_describe_col_integer) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 1, &col), SQL_SUCCESS);
  EXPECT_STREQ((char *)col.name, "A");
  EXPECT_EQ(col.name_length, 1);
  EXPECT_EQ(col.type, SQL_INTEGER);
  EXPECT_EQ(col.size, 10);
  EXPECT_EQ(col.digits, 0);
  EXPECT_EQ(col.nullable, SQL_NO_NULLS);
}

UTEST_F(db, 6_15_describe_col_varchar) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 2, &col), SQL_SUCCESS);
  EXPECT_STREQ((char *)col.name, "BB");
  EXPECT_EQ(col.type, SQL_VARCHAR);
  EXPECT_EQ(col.size, 80);
  EXPECT_EQ(col.nullable, SQL_NULLABLE);
}

UTEST_F(db, 6_15_describe_col_numeric) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 3, &col), SQL_SUCCESS);
  EXPECT_EQ(col.type, SQL_NUMERIC);
  EXPECT_EQ(col.size, 10);
  EXPECT_EQ(col.digits, 2);
}

UTEST_F(db, 6_15_describe_col_date) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 4, &col), SQL_SUCCESS);
  EXPECT_EQ(col.type, SQL_TYPE_DATE);
  EXPECT_EQ(col.size, 10);
}

UTEST_F(db, 6_15_describe_col_double) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 5, &col), SQL_SUCCESS);
  EXPECT_EQ(col.type, SQL_DOUBLE);
}

UTEST_F(db, 6_15_describe_col_null_name_length) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLDescribeCol(utest_fixture->stmt, 2, col.name, sizeof(col.name),
                           NULL, &col.type, &col.size, &col.digits,
                           &col.nullable),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)col.name, "BB");
}

/* A name that doesn't fit is truncated with a warning. */
UTEST_F(db, 6_15_describe_col_truncated_name) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLDescribeCol(utest_fixture->stmt, 2, col.name, 2,
                           &col.name_length, &col.type, &col.size, &col.digits,
                           &col.nullable),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_STREQ((char *)col.name, "B");
  EXPECT_EQ(col.name_length, 2);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "01004");
}

UTEST_F(db, 6_15_describe_col_zero_buffer_length) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLDescribeCol(utest_fixture->stmt, 1, col.name, 0,
                           &col.name_length, &col.type, &col.size, &col.digits,
                           &col.nullable),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY090");
}

UTEST_F(db, 6_15_describe_col_column_zero) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 0, &col), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07009");
}

UTEST_F(db, 6_15_describe_col_column_after_last) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 6, &col), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07009");
}

/* Only the NameLength may be a null pointer. */
UTEST_F(db, 6_15_describe_col_null_data_type) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLDescribeCol(utest_fixture->stmt, 1, col.name, sizeof(col.name),
                           NULL, NULL, &col.size, &col.digits, &col.nullable),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
}

/* The IRD still describes the columns after the cursor is closed. */
UTEST_F(db, 6_15_describe_col_closed_cursor) {
  struct column col;

  ASSERT_EQ(select_describe_table(utest_fixture->stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLCloseCursor(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(describe(utest_fixture->stmt, 1, &col), SQL_SUCCESS);
  EXPECT_STREQ((char *)col.name, "A");
}
