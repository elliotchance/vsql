#include "test.h"

/* 6.24 FreeConnect */

UTEST(libvsql, 6_24_free_connect) {
  SQLHENV env;
  SQLHDBC dbc;

  ASSERT_EQ(SQLAllocEnv(&env), SQL_SUCCESS);
  ASSERT_EQ(SQLAllocConnect(env, &dbc), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeConnect(dbc), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeConnect(dbc), SQL_INVALID_HANDLE);
  EXPECT_EQ(SQLFreeEnv(env), SQL_SUCCESS);
}

UTEST_F(db, 6_24_free_connect_connected) {
  EXPECT_EQ(SQLFreeConnect(utest_fixture->dbc), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY010");
}
