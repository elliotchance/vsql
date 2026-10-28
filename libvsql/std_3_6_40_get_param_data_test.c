#include "test.h"

/* 6.40 GetParamData */

UTEST_F(db, 6_40_get_param_data) {
  SQLINTEGER value, indicator;

  EXPECT_EQ(SQLGetParamData(utest_fixture->stmt, 1, SQL_INTEGER, &value, 0,
                            &indicator),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HYC00");
  EXPECT_EQ(SQLGetParamData(-1, 1, SQL_INTEGER, &value, 0, &indicator),
            SQL_INVALID_HANDLE);
}
