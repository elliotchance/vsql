#include "test.h"

/* 6.41 GetPosition */

UTEST_F(db, 6_41_get_position) {
  SQLINTEGER located_at, indicator;

  EXPECT_EQ(SQLGetPosition(utest_fixture->stmt, 0, 1, 0, (SQLCHAR *)"a", 1, 1,
                           &located_at, &indicator),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HYC00");
  EXPECT_EQ(SQLGetPosition(-1, 0, 1, 0, (SQLCHAR *)"a", 1, 1, &located_at,
                           &indicator),
            SQL_INVALID_HANDLE);
}
