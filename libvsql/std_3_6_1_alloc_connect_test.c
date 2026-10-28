#include "test.h"

/* 6.1 AllocConnect */

UTEST_F(env, 6_1_alloc_connect) {
  SQLHDBC dbc;

  EXPECT_EQ(SQLAllocConnect(utest_fixture->env, &dbc), SQL_SUCCESS);
  EXPECT_NE(dbc, utest_fixture->dbc);
  EXPECT_EQ(connect_memory(dbc), SQL_SUCCESS);
  EXPECT_EQ(SQLDisconnect(dbc), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeConnect(dbc), SQL_SUCCESS);
}

UTEST_F(env, 6_1_alloc_connect_invalid_handle) {
  SQLHDBC dbc = 123;

  EXPECT_EQ(SQLAllocConnect(utest_fixture->dbc, &dbc), SQL_INVALID_HANDLE);
  EXPECT_EQ(dbc, 0);
}
