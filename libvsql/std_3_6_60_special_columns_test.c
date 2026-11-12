#include "test.h"

/* 6.60 SpecialColumns */

UTEST_F(db, 6_60_special_columns) {
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE t (a INT, b VARCHAR(10), c INT, PRIMARY KEY "
                    "(b, a))"),
            SQL_SUCCESS);

#define SPECIAL(column, scope)                                                 \
  (SQLSpecialColumns(utest_fixture->stmt, SQL_BEST_ROWID, NULL, 0, NULL, 0,    \
                     (SQLCHAR *)"T", SQL_NTS, scope,                           \
                     SQL_NO_NULLS) == SQL_SUCCESS                              \
       ? fetch_strings(utest_fixture->stmt, column)                            \
       : "(error)")

  EXPECT_STREQ(SPECIAL(1, SQL_SCOPE_CURROW), "2,2");
  EXPECT_STREQ(SPECIAL(2, SQL_SCOPE_CURROW), "B,A");
  EXPECT_STREQ(SPECIAL(3, SQL_SCOPE_CURROW), "12,4");
  EXPECT_STREQ(SPECIAL(4, SQL_SCOPE_CURROW), "CHARACTER VARYING,INTEGER");
  EXPECT_STREQ(SPECIAL(5, SQL_SCOPE_CURROW), "10,10");
  EXPECT_STREQ(SPECIAL(8, SQL_SCOPE_CURROW), "1,1");
  EXPECT_STREQ(SPECIAL(2, SQL_SCOPE_SESSION), "B,A");
#undef SPECIAL
}

/* A UNIQUE column that allows nulls can't identify a row. */
UTEST_F(db, 6_60_special_columns_no_key) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (a INT UNIQUE)"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSpecialColumns(utest_fixture->stmt, SQL_BEST_ROWID, NULL, 0,
                              NULL, 0, (SQLCHAR *)"T", SQL_NTS,
                              SQL_SCOPE_CURROW, SQL_NULLABLE),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 2), "");
}

#define BEST_ROWID(table)                                                      \
  (SQLSpecialColumns(utest_fixture->stmt, SQL_BEST_ROWID, NULL, 0, NULL, 0,    \
                     (SQLCHAR *)table, SQL_NTS, SQL_SCOPE_CURROW,              \
                     SQL_NULLABLE) == SQL_SUCCESS                              \
       ? fetch_strings(utest_fixture->stmt, 2)                                 \
       : "(error)")

/* Without a PRIMARY KEY, the UNIQUE constraint with the fewest columns (then
 * the first by name) whose columns are all NOT NULL. */
UTEST_F(db, 6_60_special_columns_unique) {
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE t (a INT NOT NULL, b INT NOT NULL, c INT, "
                    "d INT NOT NULL, CONSTRAINT zz UNIQUE (a), "
                    "CONSTRAINT yy UNIQUE (d), CONSTRAINT xx UNIQUE (c), "
                    "CONSTRAINT ww UNIQUE (a, b))"),
            SQL_SUCCESS);
  EXPECT_STREQ(BEST_ROWID("T"), "D");

  /* The columns are in the order of the constraint. */
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE u (a INT NOT NULL, b INT NOT NULL, c INT, "
                    "UNIQUE (b, a), UNIQUE (a, c))"),
            SQL_SUCCESS);
  EXPECT_STREQ(BEST_ROWID("U"), "B,A");

  /* Every UNIQUE constraint has a column that allows nulls. */
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE v (a INT NOT NULL, b INT, UNIQUE (a, b))"),
            SQL_SUCCESS);
  EXPECT_STREQ(BEST_ROWID("V"), "");
}

/* The PRIMARY KEY comes first, even when a UNIQUE constraint has fewer
 * columns. */
UTEST_F(db, 6_60_special_columns_primary_key_first) {
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE t (a INT NOT NULL UNIQUE, b INT, c INT, "
                    "CONSTRAINT aa PRIMARY KEY (b, c))"),
            SQL_SUCCESS);
  EXPECT_STREQ(BEST_ROWID("T"), "B,C");
}

/* Each table has its own key (A1 of T2 comes before the constraints of T1). */
UTEST_F(db, 6_60_special_columns_unique_each_table) {
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE t1 (a INT NOT NULL UNIQUE, b INT NOT NULL "
                    "UNIQUE)"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE t2 (a INT NOT NULL, b INT NOT NULL, "
                    "CONSTRAINT a1 UNIQUE (b))"),
            SQL_SUCCESS);
  EXPECT_STREQ(BEST_ROWID("T1"), "A");
  EXPECT_STREQ(BEST_ROWID("T2"), "B");
}
#undef BEST_ROWID

UTEST_F(db, 6_60_special_columns_invalid) {
  EXPECT_EQ(SQLSpecialColumns(utest_fixture->stmt, 2, NULL, 0, NULL, 0,
                              (SQLCHAR *)"T", SQL_NTS, SQL_SCOPE_CURROW,
                              SQL_NULLABLE),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY097");
  EXPECT_EQ(SQLSpecialColumns(utest_fixture->stmt, SQL_BEST_ROWID, NULL, 0,
                              NULL, 0, (SQLCHAR *)"T", SQL_NTS, 3,
                              SQL_NULLABLE),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY098");
  EXPECT_EQ(SQLSpecialColumns(utest_fixture->stmt, SQL_BEST_ROWID, NULL, 0,
                              NULL, 0, (SQLCHAR *)"T", SQL_NTS,
                              SQL_SCOPE_CURROW, 2),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY099");
  EXPECT_EQ(SQLSpecialColumns(utest_fixture->stmt, SQL_BEST_ROWID, NULL, 0,
                              NULL, 0, NULL, 0, SQL_SCOPE_CURROW, SQL_NULLABLE),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
}

/* The null pointers are checked before any length is read. */
UTEST_F(db, 6_60_special_columns_null_pointer_before_length) {
  EXPECT_EQ(SQLSpecialColumns(utest_fixture->stmt, SQL_BEST_ROWID, NULL, 0,
                              (SQLCHAR *)"A", -5, NULL, 0, SQL_SCOPE_CURROW,
                              SQL_NO_NULLS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");

  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_METADATA_ID,
                           INTEGER_VALUE(SQL_TRUE), 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLSpecialColumns(utest_fixture->stmt, SQL_BEST_ROWID, NULL, 0,
                              (SQLCHAR *)"A", -5, (SQLCHAR *)"T", SQL_NTS,
                              SQL_SCOPE_CURROW, SQL_NO_NULLS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
}
