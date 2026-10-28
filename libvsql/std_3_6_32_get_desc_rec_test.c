#include "test.h"

/* 6.32 GetDescRec */

UTEST_F(row, 6_32_get_desc_rec) {
  SQLHDESC ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);
  SQLCHAR name[32];
  SQLSMALLINT name_length, type, sub_type, precision, scale, nullable;
  SQLINTEGER length;

  EXPECT_EQ(SQLGetDescRec(ird, COL_VARCHAR, name, sizeof(name), &name_length,
                          &type, &sub_type, &length, &precision, &scale,
                          &nullable),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)name, "COL2");
  EXPECT_EQ(name_length, 4);
  EXPECT_EQ(type, SQL_VARCHAR);
  EXPECT_EQ(sub_type, 0);
  EXPECT_EQ(length, 80);
  EXPECT_EQ(nullable, SQL_NULLABLE);

  EXPECT_EQ(SQLGetDescRec(ird, COL_DATE, NULL, 0, NULL, &type, &sub_type, NULL,
                          &precision, NULL, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(type, SQL_DATETIME);
  EXPECT_EQ(sub_type, SQL_CODE_DATE);

  EXPECT_EQ(SQLGetDescRec(ird, COL_NUMERIC, NULL, 0, NULL, NULL, NULL, NULL,
                          &precision, &scale, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(precision, 5);
  EXPECT_EQ(scale, 2);
}

UTEST_F(row, 6_32_get_desc_rec_record_number) {
  SQLHDESC ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);

  EXPECT_EQ(
      SQLGetDescRec(ird, 0, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ird, "07009");
  EXPECT_EQ(
      SQLGetDescRec(ird, 7, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
      SQL_NO_DATA);
}

UTEST_F(db, 6_32_get_desc_rec_not_executed) {
  SQLHDESC ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  ASSERT_EQ(SQLFreeStmt(utest_fixture->stmt, SQL_REALLOCATE), SQL_SUCCESS);
  EXPECT_EQ(
      SQLGetDescRec(ird, 1, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
      SQL_NO_DATA);
}
