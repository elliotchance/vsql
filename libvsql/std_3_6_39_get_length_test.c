#include "test.h"

/* 6.39 GetLength */

UTEST_F(db, 6_39_get_length) {
  SQLINTEGER length, indicator;

  EXPECT_EQ(SQLGetLength(utest_fixture->stmt, 0, 1, &length, &indicator),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HYC00");
  EXPECT_EQ(SQLGetLength(-1, 0, 1, &length, &indicator), SQL_INVALID_HANDLE);
}
