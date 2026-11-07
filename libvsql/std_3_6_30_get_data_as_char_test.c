#include "test.h"

/*
 * A value retrieved as SQL_CHAR is the result of CAST ( SV AS TDT ), by
 * SQLGetData (6.30, GetData, General Rules, 25.b.vi.2) and for a bound column
 * (5.8, Implicit FETCH USING clause, General Rules, 3.h.vi.2). Each test has
 * the column x of a type and the same value cast with SQL.
 */

static SQLRETURN select_as_char(SQLHSTMT stmt, const char *type,
                                const char *literal) {
  char sql[128];

  snprintf(sql, sizeof(sql), "CREATE TABLE t (x %s)", type);
  if (run_sql(stmt, sql) != SQL_SUCCESS) {
    return SQL_ERROR;
  }

  snprintf(sql, sizeof(sql), "INSERT INTO t (x) VALUES (%s)", literal);
  if (run_sql(stmt, sql) != SQL_SUCCESS) {
    return SQL_ERROR;
  }

  return run_sql(stmt, "SELECT x, CAST(x AS VARCHAR(64)) FROM t");
}

#define AS_CHAR_TEST(name, type, literal, expected)                            \
  UTEST_F(db, 6_30_get_data_as_char_##name) {                                  \
    char value[64], cast[64];                                                  \
    SQLINTEGER ind;                                                            \
                                                                               \
    ASSERT_EQ(select_as_char(utest_fixture->stmt, type, literal),              \
              SQL_SUCCESS);                                                    \
    ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);                     \
    EXPECT_EQ(SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, value,              \
                         sizeof(value), &ind),                                 \
              SQL_SUCCESS);                                                    \
    EXPECT_EQ(SQLGetData(utest_fixture->stmt, 2, SQL_CHAR, cast, sizeof(cast), \
                         NULL),                                                \
              SQL_SUCCESS);                                                    \
    EXPECT_STREQ(value, expected);                                             \
    EXPECT_STREQ(value, cast);                                                 \
    EXPECT_EQ(ind, (SQLINTEGER)strlen(expected));                              \
  }                                                                            \
                                                                               \
  UTEST_F(db, 5_8_implicit_fetch_as_char_##name) {                             \
    char value[64], cast[64];                                                  \
    SQLINTEGER ind;                                                            \
                                                                               \
    ASSERT_EQ(select_as_char(utest_fixture->stmt, type, literal),              \
              SQL_SUCCESS);                                                    \
    EXPECT_EQ(SQLBindCol(utest_fixture->stmt, 1, SQL_CHAR, value,              \
                         sizeof(value), &ind),                                 \
              SQL_SUCCESS);                                                    \
    EXPECT_EQ(SQLBindCol(utest_fixture->stmt, 2, SQL_CHAR, cast, sizeof(cast), \
                         NULL),                                                \
              SQL_SUCCESS);                                                    \
    ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);                     \
    EXPECT_STREQ(value, expected);                                             \
    EXPECT_STREQ(value, cast);                                                 \
    EXPECT_EQ(ind, (SQLINTEGER)strlen(expected));                              \
  }

AS_CHAR_TEST(smallint, "SMALLINT", "-12", "-12")
AS_CHAR_TEST(integer, "INTEGER", "-1234", "-1234")
AS_CHAR_TEST(bigint, "BIGINT", "1234567890123", "1234567890123")
AS_CHAR_TEST(numeric, "NUMERIC(5, 2)", "-12.5", "-12.50")
AS_CHAR_TEST(decimal, "DECIMAL(5, 2)", "12.5", "12.50")
AS_CHAR_TEST(real, "REAL", "4.56e0", "4.56E0")
AS_CHAR_TEST(real_one, "REAL", "1e0", "1.0E0")
AS_CHAR_TEST(double, "DOUBLE PRECISION", "4.56e0", "4.56E0")
AS_CHAR_TEST(double_negative, "DOUBLE PRECISION", "-123e0", "-1.23E2")
AS_CHAR_TEST(double_digits, "DOUBLE PRECISION", "0.1e0 + 0.2e0",
             "3.0000000000000004E-1")
AS_CHAR_TEST(double_zero, "DOUBLE PRECISION", "-0e0", "0E0")
AS_CHAR_TEST(character, "CHARACTER(5)", "'ab'", "ab   ")
AS_CHAR_TEST(varchar, "VARCHAR(5)", "'ab '", "ab ")
AS_CHAR_TEST(boolean_true, "BOOLEAN", "TRUE", "TRUE")
AS_CHAR_TEST(boolean_false, "BOOLEAN", "FALSE", "FALSE")
AS_CHAR_TEST(date, "DATE", "DATE '2022-06-30'", "DATE '2022-06-30'")
AS_CHAR_TEST(time, "TIME(0) WITHOUT TIME ZONE", "TIME '12:34:56'",
             "TIME '12:34:56'")
AS_CHAR_TEST(time_zone, "TIME(0) WITH TIME ZONE", "TIME '12:34:56+05:00'",
             "TIME '12:34:56+05:00'")
AS_CHAR_TEST(timestamp, "TIMESTAMP(2) WITHOUT TIME ZONE",
             "TIMESTAMP '2022-06-30 12:34:56.25'",
             "TIMESTAMP '2022-06-30 12:34:56.25'")
AS_CHAR_TEST(timestamp_zone, "TIMESTAMP(0) WITH TIME ZONE",
             "TIMESTAMP '2022-06-30 12:34:56+05:00'",
             "TIMESTAMP '2022-06-30 12:34:56+05:00'")

/* A value that doesn't fit is retrieved from the cast in pieces. */
UTEST_F(db, 6_30_get_data_as_char_pieces) {
  char buf[10];
  SQLINTEGER ind;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES DATE '2022-06-30'"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, buf, sizeof(buf), &ind),
      SQL_SUCCESS_WITH_INFO);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "01004");
  EXPECT_STREQ(buf, "DATE '202");
  EXPECT_EQ(ind, 17);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, buf, sizeof(buf), &ind),
      SQL_SUCCESS);
  EXPECT_STREQ(buf, "2-06-30'");
  EXPECT_EQ(ind, 8);
}

UTEST_F(db, 5_8_implicit_fetch_as_char_truncated) {
  char buf[5];
  SQLINTEGER ind;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 4.56e0"), SQL_SUCCESS);
  EXPECT_EQ(
      SQLBindCol(utest_fixture->stmt, 1, SQL_CHAR, buf, sizeof(buf), &ind),
      SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS_WITH_INFO);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "01004");
  EXPECT_STREQ(buf, "4.56");
  EXPECT_EQ(ind, 6);
}

/* A null value isn't cast. */
UTEST_F(db, 6_30_get_data_as_char_null) {
  char buf[10];
  SQLINTEGER ind;

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES CAST(NULL AS DATE)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(
      SQLGetData(utest_fixture->stmt, 1, SQL_CHAR, buf, sizeof(buf), &ind),
      SQL_SUCCESS);
  EXPECT_EQ(ind, SQL_NULL_DATA);
}
