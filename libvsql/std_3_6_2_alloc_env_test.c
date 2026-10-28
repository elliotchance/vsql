#include "test.h"

/* 6.2 AllocEnv */

UTEST(libvsql, 6_2_alloc_env) {
  SQLHENV env;

  EXPECT_EQ(SQLAllocEnv(&env), SQL_SUCCESS);
  EXPECT_NE(env, SQL_NULL_HANDLE);
  EXPECT_EQ(SQLFreeEnv(env), SQL_SUCCESS);
}

UTEST(libvsql, 6_2_alloc_env_null_output_handle) {
  EXPECT_EQ(SQLAllocEnv(NULL), SQL_ERROR);
}
