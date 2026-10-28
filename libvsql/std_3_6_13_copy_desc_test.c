#include "test.h"

/* 6.13 CopyDesc */

UTEST_F(row, 6_13_copy_desc) {
  SQLHDESC desc;

  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_DESC, utest_fixture->dbc, &desc),
            SQL_SUCCESS);
  EXPECT_EQ(
      SQLCopyDesc(stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC), desc),
      SQL_SUCCESS);
  EXPECT_EQ(desc_short(desc, 0, SQL_DESC_COUNT), 6);
  EXPECT_EQ(desc_short(desc, COL_DOUBLE, SQL_DESC_TYPE), SQL_DOUBLE);
  EXPECT_STREQ(desc_string(desc, COL_VARCHAR, SQL_DESC_NAME), "COL2");
  EXPECT_EQ(desc_short(desc, 0, SQL_DESC_ALLOC_TYPE), SQL_DESC_ALLOC_USER);
  EXPECT_EQ(SQLFreeHandle(SQL_HANDLE_DESC, desc), SQL_SUCCESS);
}

/* The target replaces all of its records. */
UTEST_F(db, 6_13_copy_desc_replaces) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLHDESC desc;

  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_DESC, utest_fixture->dbc, &desc),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetDescField(desc, 3, SQL_DESC_TYPE, (SQLPOINTER)SQL_INTEGER, 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLCopyDesc(ard, desc), SQL_SUCCESS);
  EXPECT_EQ(desc_short(desc, 0, SQL_DESC_COUNT), 0);
  EXPECT_EQ(desc_short(ard, 0, SQL_DESC_ALLOC_TYPE), SQL_DESC_ALLOC_AUTO);
}

UTEST_F(row, 6_13_copy_desc_to_ird) {
  SQLHDESC ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);

  EXPECT_EQ(
      SQLCopyDesc(stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC), ird),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ird, "HY016");
}

UTEST_F(db, 6_13_copy_desc_invalid_handle) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);

  EXPECT_EQ(SQLCopyDesc(utest_fixture->stmt, ard), SQL_INVALID_HANDLE);
  EXPECT_EQ(SQLCopyDesc(ard, utest_fixture->stmt), SQL_INVALID_HANDLE);
}
