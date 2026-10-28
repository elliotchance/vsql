#include "test.h"

/* 6.4 AllocStmt */

UTEST_F(db, 6_4_alloc_stmt) {
  SQLHSTMT stmt;

  EXPECT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt), SQL_SUCCESS);
  EXPECT_NE(stmt, utest_fixture->stmt);
  EXPECT_EQ(run_sql(stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeStmt(stmt, SQL_DROP), SQL_SUCCESS);
}

UTEST_F(env, 6_4_alloc_stmt_not_connected) {
  SQLHSTMT stmt = 123;

  EXPECT_EQ(SQLAllocStmt(utest_fixture->dbc, &stmt), SQL_ERROR);
  EXPECT_EQ(stmt, 0);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "08003");
}
