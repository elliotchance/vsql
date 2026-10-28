#include "test.h"

/* 6.10 ColumnPrivileges */

UTEST_F(db, 6_10_column_privileges) {
  EXPECT_EQ(SQLColumnPrivileges(utest_fixture->stmt, NULL, 0, NULL, 0,
                                (SQLCHAR *)"T", SQL_NTS, NULL, 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HYC00");
  EXPECT_EQ(SQLColumnPrivileges(-1, NULL, 0, NULL, 0, NULL, 0, NULL, 0),
            SQL_INVALID_HANDLE);
}
