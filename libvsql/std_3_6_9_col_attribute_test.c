#include "test.h"

/* 6.9 ColAttribute */

UTEST_F(row, 6_9_col_attribute) {
  SQLCHAR name[32];
  SQLSMALLINT len;
  SQLINTEGER value = -1;

  EXPECT_EQ(SQLColAttribute(utest_fixture->stmt, COL_VARCHAR, SQL_DESC_NAME,
                            name, sizeof(name), &len, NULL),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)name, "COL2");
  EXPECT_EQ(len, 4);

  EXPECT_EQ(SQLColAttribute(utest_fixture->stmt, COL_VARCHAR, SQL_DESC_LENGTH,
                            NULL, 0, NULL, &value),
            SQL_SUCCESS);
  EXPECT_EQ(value, 20);

  /* A SMALLINT field is returned as an SQLINTEGER. */
  value = -1;
  EXPECT_EQ(SQLColAttribute(utest_fixture->stmt, COL_NUMERIC, SQL_DESC_SCALE,
                            NULL, 0, NULL, &value),
            SQL_SUCCESS);
  EXPECT_EQ(value, 2);
}

/* The TYPE of a datetime is the concise code, like DescribeCol. */
UTEST_F(row, 6_9_col_attribute_type) {
  SQLINTEGER value = -1;

  EXPECT_EQ(SQLColAttribute(utest_fixture->stmt, COL_DATE, SQL_DESC_TYPE, NULL,
                            0, NULL, &value),
            SQL_SUCCESS);
  EXPECT_EQ(value, SQL_TYPE_DATE);
  EXPECT_EQ(SQLColAttribute(utest_fixture->stmt, COL_DATE,
                            SQL_DESC_DATETIME_INTERVAL_CODE, NULL, 0, NULL,
                            &value),
            SQL_SUCCESS);
  EXPECT_EQ(value, SQL_CODE_DATE);
}

/* A header field needs a column number, but it isn't used. */
UTEST_F(row, 6_9_col_attribute_header) {
  SQLINTEGER value = -1;

  EXPECT_EQ(SQLColAttribute(utest_fixture->stmt, 1, SQL_DESC_COUNT, NULL, 0,
                            NULL, &value),
            SQL_SUCCESS);
  EXPECT_EQ(value, 6);
}

UTEST_F(row, 6_9_col_attribute_column_number) {
  SQLINTEGER value;

  EXPECT_EQ(SQLColAttribute(utest_fixture->stmt, 0, SQL_DESC_TYPE, NULL, 0,
                            NULL, &value),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07009");
  EXPECT_EQ(SQLColAttribute(utest_fixture->stmt, 7, SQL_DESC_TYPE, NULL, 0,
                            NULL, &value),
            SQL_NO_DATA);
}

UTEST_F(row, 6_9_col_attribute_invalid_field) {
  SQLINTEGER value;

  EXPECT_EQ(
      SQLColAttribute(utest_fixture->stmt, 1, 9999, NULL, 0, NULL, &value),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY091");

  /* The DATA_POINTER can't be retrieved from an IRD. */
  EXPECT_EQ(SQLColAttribute(utest_fixture->stmt, 1, SQL_DESC_DATA_POINTER, NULL,
                            0, NULL, &value),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY091");
}

UTEST_F(row, 6_9_col_attribute_truncated) {
  SQLCHAR name[3];
  SQLSMALLINT len;

  EXPECT_EQ(SQLColAttribute(utest_fixture->stmt, COL_VARCHAR, SQL_DESC_NAME,
                            name, sizeof(name), &len, NULL),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "01004");
  EXPECT_STREQ((char *)name, "CO");
  EXPECT_EQ(len, 4);
}

UTEST_F(db, 6_9_col_attribute_no_statement) {
  SQLINTEGER value;

  EXPECT_EQ(SQLColAttribute(utest_fixture->stmt, 1, SQL_DESC_TYPE, NULL, 0,
                            NULL, &value),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

UTEST_F(db, 6_9_col_attribute_not_a_query) {
  SQLINTEGER value;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLColAttribute(utest_fixture->stmt, 1, SQL_DESC_TYPE, NULL, 0,
                            NULL, &value),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "07005");
}
