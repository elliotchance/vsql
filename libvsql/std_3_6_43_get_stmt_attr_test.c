#include "test.h"

/* 6.43 GetStmtAttr */

UTEST_F(db, 6_43_get_stmt_attr_descriptors) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLHDESC apd = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_PARAM_DESC);
  SQLHDESC ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);

  EXPECT_NE(ard, SQL_NULL_HANDLE);
  EXPECT_NE(apd, SQL_NULL_HANDLE);
  EXPECT_NE(ird, SQL_NULL_HANDLE);
  EXPECT_NE(ipd, SQL_NULL_HANDLE);
  EXPECT_NE(ard, apd);
  EXPECT_NE(ird, ipd);
  EXPECT_NE(ard, ird);
}

UTEST_F(db, 6_43_get_stmt_attr_defaults) {
  SQLINTEGER v;

  EXPECT_EQ(SQLGetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_SCROLLABLE, &v,
                           0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(v, SQL_NONSCROLLABLE);
  EXPECT_EQ(SQLGetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_SENSITIVITY, &v,
                           0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(v, SQL_ASENSITIVE);
  EXPECT_EQ(SQLGetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_HOLDABLE, &v, 0,
                           NULL),
            SQL_SUCCESS);
  EXPECT_EQ(v, SQL_HOLDABLE);
  EXPECT_EQ(
      SQLGetStmtAttr(utest_fixture->stmt, SQL_ATTR_METADATA_ID, &v, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(v, SQL_FALSE);
  EXPECT_EQ(SQLGetStmtAttr(utest_fixture->stmt, SQL_ATTR_NEST_DESCRIPTOR, &v, 0,
                           NULL),
            SQL_SUCCESS);
  EXPECT_EQ(v, SQL_FALSE);
}

UTEST_F(db, 6_43_get_stmt_attr_current_of_position) {
  SQLINTEGER v = 0;

  EXPECT_EQ(SQLGetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURRENT_OF_POSITION,
                           &v, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
  EXPECT_EQ(SQLGetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURRENT_OF_POSITION,
                           &v, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(v, 1);
}

UTEST_F(db, 6_43_get_stmt_attr_invalid) {
  SQLINTEGER v;

  EXPECT_EQ(SQLGetStmtAttr(utest_fixture->stmt, 123, &v, 0, NULL), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY092");
  EXPECT_EQ(
      SQLGetStmtAttr(utest_fixture->stmt, SQL_ATTR_METADATA_ID, NULL, 0, NULL),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY009");
  EXPECT_EQ(
      SQLGetStmtAttr(utest_fixture->dbc, SQL_ATTR_METADATA_ID, &v, 0, NULL),
      SQL_INVALID_HANDLE);
}
