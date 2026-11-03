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

/* The PRECISION of an IPD's datetime must be valid. It's 0 (zero) to 6, other
 * than a DATE which is always 0 (zero). */
UTEST_F(db, 6_57_set_desc_rec_datetime_precision) {
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);
  SQLDOUBLE d;
  SQLSMALLINT codes[] = {SQL_CODE_TIME, SQL_CODE_TIMESTAMP, SQL_CODE_TIME_ZONE,
                         SQL_CODE_TIMESTAMP_ZONE};
  SQLSMALLINT invalid[] = {-1, 7, 100};
  size_t i, j;

  for (i = 0; i < sizeof(codes) / sizeof(codes[0]); i++) {
    for (j = 0; j < sizeof(invalid) / sizeof(invalid[0]); j++) {
      EXPECT_EQ(SQLSetDescRec(ipd, 1, SQL_DATETIME, codes[i], 0, invalid[j], 0,
                              &d, NULL, NULL),
                SQL_ERROR);
      EXPECT_STATE(SQL_HANDLE_DESC, ipd, "HY021");
    }
    EXPECT_EQ(desc_short(ipd, 0, SQL_DESC_COUNT), 0);

    EXPECT_EQ(SQLSetDescRec(ipd, 1, SQL_DATETIME, codes[i], 0, 0, 0, &d, NULL,
                            NULL),
              SQL_SUCCESS);
    EXPECT_EQ(SQLSetDescRec(ipd, 1, SQL_DATETIME, codes[i], 0, 6, 0, &d, NULL,
                            NULL),
              SQL_SUCCESS);
    ASSERT_EQ(SQLSetDescField(ipd, 0, SQL_DESC_COUNT, SMALLINT_VALUE(0), 0),
              SQL_SUCCESS);
  }

  EXPECT_EQ(SQLSetDescRec(ipd, 1, SQL_DATETIME, SQL_CODE_DATE, 0, 1, 0, &d,
                          NULL, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ipd, "HY021");
  EXPECT_EQ(SQLSetDescRec(ipd, 1, SQL_DATETIME, SQL_CODE_DATE, 0, 0, 0, &d,
                          NULL, NULL),
            SQL_SUCCESS);

  /* The DATETIME_INTERVAL_CODE must still be valid. */
  EXPECT_EQ(SQLSetDescRec(ipd, 1, SQL_DATETIME, 99, 0, 0, 0, &d, NULL, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ipd, "HY021");
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
