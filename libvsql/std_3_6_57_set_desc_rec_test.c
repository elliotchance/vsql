#include "test.h"

/* 6.57 SetDescRec */

UTEST_F(db, 6_57_set_desc_rec) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLDOUBLE d;
  SQLINTEGER len, ind;
  SQLPOINTER p;

  EXPECT_EQ(
      SQLSetDescRec(ard, 2, SQL_DOUBLE, 0, sizeof(d), 0, 0, &d, &len, &ind),
      SQL_SUCCESS);
  EXPECT_EQ(desc_short(ard, 0, SQL_DESC_COUNT), 2);
  EXPECT_EQ(desc_short(ard, 2, SQL_DESC_TYPE), SQL_DOUBLE);
  EXPECT_EQ(desc_int(ard, 2, SQL_DESC_OCTET_LENGTH), (SQLINTEGER)sizeof(d));
  EXPECT_EQ(SQLGetDescField(ard, 2, SQL_DESC_DATA_POINTER, &p, 0, NULL),
            SQL_SUCCESS);
  EXPECT_TRUE(p == &d);
  EXPECT_EQ(SQLGetDescField(ard, 2, SQL_DESC_OCTET_LENGTH_POINTER, &p, 0, NULL),
            SQL_SUCCESS);
  EXPECT_TRUE(p == &len);
  EXPECT_EQ(SQLGetDescField(ard, 2, SQL_DESC_INDICATOR_POINTER, &p, 0, NULL),
            SQL_SUCCESS);
  EXPECT_TRUE(p == &ind);

  /* A null StringLength and Indicator don't change them. */
  EXPECT_EQ(
      SQLSetDescRec(ard, 2, SQL_DOUBLE, 0, sizeof(d), 0, 0, &d, NULL, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(SQLGetDescField(ard, 2, SQL_DESC_INDICATOR_POINTER, &p, 0, NULL),
            SQL_SUCCESS);
  EXPECT_TRUE(p == &ind);
}

/* The Length of an IPD is in characters. */
UTEST_F(db, 6_57_set_desc_rec_ipd) {
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);

  EXPECT_EQ(SQLSetDescRec(ipd, 1, SQL_VARCHAR, 0, 10, 0, 0, NULL, NULL, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(desc_int(ipd, 1, SQL_DESC_LENGTH), 10);
}

UTEST_F(db, 6_57_set_desc_rec_inconsistent) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLDOUBLE d;

  EXPECT_EQ(SQLSetDescRec(ard, 1, SQL_NUMERIC, 0, 8, 10, 2, &d, NULL, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "HY021");
  EXPECT_EQ(desc_short(ard, 0, SQL_DESC_COUNT), 0);
}

UTEST_F(row, 6_57_set_desc_rec_ird) {
  SQLHDESC ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);

  EXPECT_EQ(SQLSetDescRec(ird, 1, SQL_INTEGER, 0, 4, 0, 0, NULL, NULL, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ird, "HY016");
}

UTEST_F(db, 6_57_set_desc_rec_record_zero) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);

  EXPECT_EQ(SQLSetDescRec(ard, 0, SQL_INTEGER, 0, 4, 0, 0, NULL, NULL, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "07009");
}
