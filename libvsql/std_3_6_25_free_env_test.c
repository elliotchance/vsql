#include "test.h"

/* 6.25 FreeEnv */

UTEST(libvsql, 6_25_free_env) {
  SQLHENV env;

  ASSERT_EQ(SQLAllocEnv(&env), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeEnv(env), SQL_SUCCESS);
  EXPECT_EQ(SQLFreeEnv(env), SQL_INVALID_HANDLE);
}

UTEST_F(env, 6_25_free_env_with_connections) {
  EXPECT_EQ(SQLFreeEnv(utest_fixture->env), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_ENV, utest_fixture->env, "HY010");
}
