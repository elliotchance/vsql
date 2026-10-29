#include "test.h"

/* 6.44 GetSubString */

UTEST_F(db, 6_44_get_sub_string) {
  SQLCHAR value[32];
  SQLINTEGER length, indicator;

  EXPECT_EQ(SQLGetSubString(utest_fixture->stmt, 0, 1, 1, 1, SQL_CHAR, value,
                            sizeof(value), &length, &indicator),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HYC00");
  EXPECT_EQ(SQLGetSubString(-1, 0, 1, 1, 1, SQL_CHAR, value, sizeof(value),
                            &length, &indicator),
            SQL_INVALID_HANDLE);
}
