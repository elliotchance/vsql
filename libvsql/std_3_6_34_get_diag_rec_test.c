#include "test.h"

/* 6.34 GetDiagRec */

/* There are no diagnostics after a success. */
UTEST_F(db, 6_34_get_diag_rec_no_diagnostics) {
  SQLCHAR state[6];

  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_STMT, utest_fixture->stmt, 1, state, NULL,
                          NULL, 0, NULL),
            SQL_NO_DATA);
}

UTEST_F(db, 6_34_get_diag_rec_invalid_handle) {
  SQLCHAR state[6];

  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_STMT, utest_fixture->stmt + 1000, 1, state,
                          NULL, NULL, 0, NULL),
            SQL_INVALID_HANDLE);
  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_DBC, utest_fixture->stmt, 1, state, NULL,
                          NULL, 0, NULL),
            SQL_INVALID_HANDLE);
  EXPECT_EQ(
      SQLGetDiagRec(7, utest_fixture->stmt, 1, state, NULL, NULL, 0, NULL),
      SQL_INVALID_HANDLE);
}

UTEST_F(db, 6_34_get_diag_rec) {
  SQLCHAR state[6], msg[8];
  SQLINTEGER native = 123;
  SQLSMALLINT msg_length;

  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_ERROR);
  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_STMT, utest_fixture->stmt, 1, state,
                          &native, msg, sizeof(msg), &msg_length),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)state, "24000");
  EXPECT_EQ(native, 0);
  EXPECT_STREQ((char *)msg, "invalid");
  EXPECT_EQ(msg_length, 20);
}

/* GetDiagRec doesn't change the diagnostics, even when it fails. */
UTEST_F(db, 6_34_get_diag_rec_errors) {
  SQLCHAR state[6], msg[8];

  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_ERROR);
  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_STMT, utest_fixture->stmt, 2, state, NULL,
                          NULL, 0, NULL),
            SQL_NO_DATA);
  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_STMT, utest_fixture->stmt, 0, state, NULL,
                          NULL, 0, NULL),
            SQL_ERROR);
  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_STMT, utest_fixture->stmt, 1, state, NULL,
                          msg, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_STMT, utest_fixture->stmt, "24000");
}

UTEST_F(db, 6_34_get_diag_rec_null_pointers) {
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_ERROR);
  EXPECT_EQ(SQLGetDiagRec(SQL_HANDLE_STMT, utest_fixture->stmt, 1, NULL, NULL,
                          NULL, 0, NULL),
            SQL_SUCCESS);
}
