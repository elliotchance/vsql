#include "test.h"

/* 6.23 ForeignKeys */

static SQLRETURN create_foreign_keys(SQLHSTMT stmt) {
  SQLRETURN rc =
      run_sql(stmt, "CREATE TABLE parent (id INT PRIMARY KEY, u INT UNIQUE)");

  return rc == SQL_SUCCESS
             ? run_sql(stmt, "CREATE TABLE child (x INT REFERENCES parent ON "
                             "DELETE CASCADE, y INT REFERENCES parent (u))")
             : rc;
}

/* The foreign keys of a table. */
UTEST_F(db, 6_23_foreign_keys_fk) {
  ASSERT_EQ(create_foreign_keys(utest_fixture->stmt), SQL_SUCCESS);

#define FKS(column)                                                            \
  (SQLForeignKeys(utest_fixture->stmt, NULL, 0, NULL, 0, NULL, 0, NULL, 0,     \
                  NULL, 0, (SQLCHAR *)"CHILD", SQL_NTS) == SQL_SUCCESS         \
       ? fetch_strings(utest_fixture->stmt, column)                            \
       : "(error)")

  EXPECT_STREQ(FKS(3), "PARENT,PARENT");
  EXPECT_STREQ(FKS(4), "ID,U");
  EXPECT_STREQ(FKS(7), "CHILD,CHILD");
  EXPECT_STREQ(FKS(8), "X,Y");
  EXPECT_STREQ(FKS(9), "1,1");
  EXPECT_STREQ(FKS(10), "3,3");
  EXPECT_STREQ(FKS(11), "0,3");
  EXPECT_STREQ(FKS(12), "CHILD_FOREIGN_KEY_1,CHILD_FOREIGN_KEY_2");
  EXPECT_STREQ(FKS(13), "PARENT_PRIMARY_KEY,PARENT_UNIQUE_1");
  EXPECT_STREQ(FKS(14), "7,7");
  EXPECT_STREQ(FKS(15), "PRIMARY,UNIQUE ");
#undef FKS
}

/* The foreign keys that reference the PRIMARY KEY of a table. */
UTEST_F(db, 6_23_foreign_keys_pk) {
  ASSERT_EQ(create_foreign_keys(utest_fixture->stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLForeignKeys(utest_fixture->stmt, NULL, 0, NULL, 0,
                           (SQLCHAR *)"PARENT", SQL_NTS, NULL, 0, NULL, 0, NULL,
                           0),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 8), "X");
}

/* With both tables (or neither), the foreign keys between them. */
UTEST_F(db, 6_23_foreign_keys_both) {
  ASSERT_EQ(create_foreign_keys(utest_fixture->stmt), SQL_SUCCESS);
  ASSERT_EQ(SQLForeignKeys(utest_fixture->stmt, NULL, 0, NULL, 0,
                           (SQLCHAR *)"PARENT", SQL_NTS, NULL, 0,
                           (SQLCHAR *)"PUBLIC", SQL_NTS, (SQLCHAR *)"CHILD",
                           SQL_NTS),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 8), "X,Y");
  ASSERT_EQ(SQLForeignKeys(utest_fixture->stmt, NULL, 0, NULL, 0,
                           (SQLCHAR *)"CHILD", SQL_NTS, NULL, 0, NULL, 0,
                           (SQLCHAR *)"PARENT", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 8), "");
  ASSERT_EQ(SQLForeignKeys(utest_fixture->stmt, NULL, 0, NULL, 0, NULL, 0, NULL,
                           0, NULL, 0, NULL, 0),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 8), "X,Y");
}

/* A multi-column foreign key, which references the columns of a UNIQUE in a
 * different order. */
UTEST_F(db, 6_23_foreign_keys_columns) {
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE p (a INT, b INT, UNIQUE (a, b))"),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "CREATE TABLE c (x INT, y INT, FOREIGN KEY (x, y) "
                    "REFERENCES p (b, a))"),
            SQL_SUCCESS);
  ASSERT_EQ(SQLForeignKeys(utest_fixture->stmt, NULL, 0, NULL, 0, NULL, 0, NULL,
                           0, NULL, 0, (SQLCHAR *)"C", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_STREQ(fetch_strings(utest_fixture->stmt, 4), "B,A");
}
