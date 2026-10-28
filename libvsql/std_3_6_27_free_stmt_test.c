#include "test.h"

/* 6.27 FreeStmt */

UTEST_F(db, 6_27_free_stmt_close_cursor) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_CLOSE_CURSOR), SQL_SUCCESS);
  EXPECT_EQ(SQLFetch(utest_fixture->stmt), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 2"), SQL_SUCCESS);
}

/* Unlike CloseCursor, there doesn't need to be an open cursor. */
UTEST_F(db, 6_27_free_stmt_close_no_cursor) {
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_CLOSE), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_CLOSE), SQL_SUCCESS);
}

UTEST_F(db, 6_27_free_stmt_free_handle) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_FREE_HANDLE), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_CLOSE), SQL_INVALID_HANDLE);
}

UTEST_F(db, 6_27_free_stmt_unbind) {
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_UNBIND_COLUMNS), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_UNBIND_PARAMETERS),
            SQL_SUCCESS);
}

/* REALLOCATE forgets the executed statement. */
UTEST_F(db, 6_27_free_stmt_reallocate) {
  SQLINTEGER rows;

  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_REALLOCATE), SQL_SUCCESS);
  EXPECT_EQ(SQLRowCount(utest_fixture->stmt, &rows), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 2"), SQL_SUCCESS);
}

UTEST_F(db, 6_27_free_stmt_invalid_option) {
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, 5), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY092");
}

UTEST_F(db, 6_27_free_stmt_invalid_handle) {
  EXPECT_EQ(SQLFreeStmt(utest_fixture->dbc, SQL_CLOSE), SQL_INVALID_HANDLE);
}

UTEST_F(db, 6_27_free_stmt_unbind_columns) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLINTEGER i;
  SQLPOINTER p = &i;

  ASSERT_EQ(SQLSetDescField(ard, 2, SQL_DESC_TYPE, (SQLPOINTER)SQL_INTEGER, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetDescField(ard, 2, SQL_DESC_DATA_POINTER, &i, 0), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_UNBIND), SQL_SUCCESS);
  EXPECT_EQ(SQLGetDescField(ard, 2, SQL_DESC_DATA_POINTER, &p, 0, NULL),
            SQL_SUCCESS);
  EXPECT_TRUE(p == NULL);
  EXPECT_EQ(desc_short(ard, 2, SQL_DESC_TYPE), SQL_INTEGER);
}

/* REALLOCATE puts back the statement's own descriptors, with their default
 * values. */
UTEST_F(db, 6_27_free_stmt_reallocate_descriptors) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLHDESC desc;

  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_DESC, utest_fixture->dbc, &desc),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetDescField(ard, 2, SQL_DESC_TYPE, (SQLPOINTER)SQL_INTEGER, 0),
            SQL_SUCCESS);
  ASSERT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC,
                           HANDLE_VALUE(desc), 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_REALLOCATE), SQL_SUCCESS);
  EXPECT_EQ(stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC), ard);
  EXPECT_EQ(desc_short(ard, 0, SQL_DESC_COUNT), 0);
}
