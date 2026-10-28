#include "test.h"

/* 6.62 TablePrivileges */

UTEST_F(db, 6_62_table_privileges) {
  EXPECT_EQ(SQLTablePrivileges(utest_fixture->stmt, NULL, 0, NULL, 0,
                               (SQLCHAR *)"T", SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "HYC00");
  EXPECT_EQ(SQLTablePrivileges(-1, NULL, 0, NULL, 0, NULL, 0),
            SQL_INVALID_HANDLE);
}
