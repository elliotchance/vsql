#include "test.h"

/* 6.59 SetStmtAttr */

/* The ARD and APD can be descriptors allocated by the application. */
UTEST_F(db, 6_59_set_stmt_attr_descriptors) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLHDESC desc;

  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_DESC, utest_fixture->dbc, &desc),
            SQL_SUCCESS);
  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC,
                           HANDLE_VALUE(desc), 0),
            SQL_SUCCESS);
  EXPECT_EQ(stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC), desc);
  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC,
                           HANDLE_VALUE(ard), 0),
            SQL_SUCCESS);
  EXPECT_EQ(stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC), ard);
}

/* A descriptor allocated on another connection can be used (the standard
 * doesn't restrict it). When that connection is disconnected, the statement
 * goes back to its own descriptor. */
UTEST_F(db, 6_59_set_stmt_attr_descriptor_of_another_connection) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLHDBC dbc2;
  SQLHDESC desc;

  ASSERT_EQ(SQLAllocConnect(utest_fixture->env, &dbc2), SQL_SUCCESS);
  ASSERT_EQ(connect_memory(dbc2), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_DESC, dbc2, &desc), SQL_SUCCESS);
  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC,
                           HANDLE_VALUE(desc), 0),
            SQL_SUCCESS);
  EXPECT_EQ(stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC), desc);

  EXPECT_EQ(SQLDisconnect(dbc2), SQL_SUCCESS);
  EXPECT_EQ(stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC), ard);
  EXPECT_EQ(SQLFreeConnect(dbc2), SQL_SUCCESS);
}

/* Another statement's descriptor can't be used. */
UTEST_F(db, 6_59_set_stmt_attr_automatic_descriptor) {
  SQLHSTMT stmt2;

  ASSERT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt2), SQL_SUCCESS);
  EXPECT_EQ(
      SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC,
                     HANDLE_VALUE(stmt_desc(stmt2, SQL_ATTR_APP_ROW_DESC)), 0),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY017");
  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_APP_PARAM_DESC,
                           HANDLE_VALUE(stmt2), 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY024");
  EXPECT_EQ(
      SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC,
                     HANDLE_VALUE(stmt_desc(stmt2, SQL_ATTR_IMP_ROW_DESC)), 0),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY092");
}

UTEST_F(db, 6_59_set_stmt_attr_cursor_scrollable) {
  SQLINTEGER v;

  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_SCROLLABLE,
                           (SQLPOINTER)SQL_SCROLLABLE, 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_SCROLLABLE, &v,
                           0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(v, SQL_SCROLLABLE);
  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_SCROLLABLE,
                           (SQLPOINTER)2, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY024");
}

/* The cursor attributes can't be changed while a cursor is open. */
UTEST_F(db, 6_59_set_stmt_attr_open_cursor) {
  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_HOLDABLE,
                           (SQLPOINTER)SQL_NONHOLDABLE, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY011");
  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_SENSITIVITY,
                           (SQLPOINTER)SQL_INSENSITIVE, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY011");
  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_SCROLLABLE,
                           (SQLPOINTER)SQL_SCROLLABLE, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY011");
}

/* A cursor is a copy of the result, so it can't be sensitive. */
UTEST_F(db, 6_59_set_stmt_attr_cursor_sensitivity) {
  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_SENSITIVITY,
                           (SQLPOINTER)SQL_SENSITIVE, 0),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "36001");

  /* A statement that isn't a query doesn't open a cursor. */
  EXPECT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);

  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURSOR_SENSITIVITY,
                           (SQLPOINTER)SQL_INSENSITIVE, 0),
            SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
}

UTEST_F(db, 6_59_set_stmt_attr_metadata_id) {
  SQLINTEGER v;

  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_METADATA_ID,
                           (SQLPOINTER)SQL_TRUE, 0),
            SQL_SUCCESS);
  EXPECT_EQ(
      SQLGetStmtAttr(utest_fixture->stmt, SQL_ATTR_METADATA_ID, &v, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(v, SQL_TRUE);
  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_METADATA_ID,
                           (SQLPOINTER)5, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY024");
}

/* NEST DESCRIPTOR can't be changed after the statement is executed. */
UTEST_F(db, 6_59_set_stmt_attr_nest_descriptor) {
  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_NEST_DESCRIPTOR,
                           (SQLPOINTER)SQL_TRUE, 0),
            SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_NEST_DESCRIPTOR,
                           (SQLPOINTER)SQL_FALSE, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY010");
}

UTEST_F(db, 6_59_set_stmt_attr_current_of_position) {
  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURRENT_OF_POSITION,
                           (SQLPOINTER)1, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURRENT_OF_POSITION,
                           (SQLPOINTER)2, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY107");
  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->stmt, SQL_ATTR_CURRENT_OF_POSITION,
                           (SQLPOINTER)1, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HY109");
}

UTEST_F(db, 6_59_set_stmt_attr_invalid_handle) {
  EXPECT_EQ(SQLSetStmtAttr(utest_fixture->dbc, SQL_ATTR_METADATA_ID,
                           (SQLPOINTER)SQL_TRUE, 0),
            SQL_INVALID_HANDLE);
}
