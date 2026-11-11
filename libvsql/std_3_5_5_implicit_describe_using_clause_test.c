#include "test.h"

/* 5.5 Implicit DESCRIBE USING clause */

/* key_member is the KEY_MEMBER of a column, from ColAttribute. */
static SQLINTEGER key_member(SQLHSTMT stmt, SQLSMALLINT column) {
  SQLINTEGER value = -1;

  SQLColAttribute(stmt, column, SQL_DESC_KEY_MEMBER, NULL, 0, NULL, &value);
  return value;
}

/* KEY_TYPE is 1 (one) when the select list contains the primary key of the
 * result, and each column of it has a KEY_MEMBER of 1 (one). It's known once
 * the statement is prepared. */
UTEST_F(db, 5_5_implicit_describe_key_type_primary_key) {
  SQLHSTMT stmt = utest_fixture->stmt;
  SQLHDESC ird = stmt_desc(stmt, SQL_ATTR_IMP_ROW_DESC);

  ASSERT_EQ(run_sql(stmt, "CREATE TABLE t (a INT, b INT NOT NULL, "
                          "c VARCHAR(10), PRIMARY KEY (c, a), UNIQUE (b))"),
            SQL_SUCCESS);

  ASSERT_EQ(SQLPrepare(stmt, (SQLCHAR *)"SELECT * FROM t WHERE b > 0", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(desc_short(ird, 0, SQL_DESC_KEY_TYPE), 1);
  EXPECT_EQ(key_member(stmt, 1), 1);
  EXPECT_EQ(key_member(stmt, 2), 0);
  EXPECT_EQ(key_member(stmt, 3), 1);
  EXPECT_EQ(desc_short(ird, 3, SQL_DESC_KEY_MEMBER), 1);

  /* Only the first reference to a column is part of the key. */
  ASSERT_EQ(run_sql(stmt, "SELECT a, c, a + 1, a FROM t AS x"), SQL_SUCCESS);
  EXPECT_EQ(desc_short(ird, 0, SQL_DESC_KEY_TYPE), 1);
  EXPECT_EQ(key_member(stmt, 1), 1);
  EXPECT_EQ(key_member(stmt, 2), 1);
  EXPECT_EQ(key_member(stmt, 3), 0);
  EXPECT_EQ(key_member(stmt, 4), 0);
}

/* Without the primary key, a UNIQUE whose columns are NOT NULL is the
 * preferred key (2). */
UTEST_F(db, 5_5_implicit_describe_key_type_preferred_key) {
  SQLHSTMT stmt = utest_fixture->stmt;
  SQLHDESC ird = stmt_desc(stmt, SQL_ATTR_IMP_ROW_DESC);

  ASSERT_EQ(run_sql(stmt, "CREATE TABLE t (a INT PRIMARY KEY, b INT NOT NULL, "
                          "c INT, UNIQUE (b), UNIQUE (c))"),
            SQL_SUCCESS);

  ASSERT_EQ(run_sql(stmt, "SELECT c, b FROM t"), SQL_SUCCESS);
  EXPECT_EQ(desc_short(ird, 0, SQL_DESC_KEY_TYPE), 2);
  EXPECT_EQ(key_member(stmt, 1), 0);
  EXPECT_EQ(key_member(stmt, 2), 1);
}

/* A key isn't known for a join, a grouped query, or a column that can be
 * NULL. */
UTEST_F(db, 5_5_implicit_describe_key_type_none) {
  SQLHSTMT stmt = utest_fixture->stmt;
  SQLHDESC ird = stmt_desc(stmt, SQL_ATTR_IMP_ROW_DESC);

  ASSERT_EQ(
      run_sql(stmt, "CREATE TABLE t (a INT PRIMARY KEY, c INT, UNIQUE (c))"),
      SQL_SUCCESS);

  ASSERT_EQ(run_sql(stmt, "SELECT c FROM t"), SQL_SUCCESS);
  EXPECT_EQ(desc_short(ird, 0, SQL_DESC_KEY_TYPE), 0);
  EXPECT_EQ(key_member(stmt, 1), 0);

  ASSERT_EQ(SQLCloseCursor(stmt), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt, "SELECT a FROM t GROUP BY a"), SQL_SUCCESS);
  EXPECT_EQ(desc_short(ird, 0, SQL_DESC_KEY_TYPE), 0);
  EXPECT_EQ(key_member(stmt, 1), 0);

  ASSERT_EQ(SQLCloseCursor(stmt), SQL_SUCCESS);
  ASSERT_EQ(run_sql(stmt, "SELECT x.a, y.a FROM t AS x JOIN t AS y ON TRUE"),
            SQL_SUCCESS);
  EXPECT_EQ(desc_short(ird, 0, SQL_DESC_KEY_TYPE), 0);
  EXPECT_EQ(key_member(stmt, 1), 0);
  EXPECT_EQ(key_member(stmt, 2), 0);
}
