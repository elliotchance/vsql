#include "test.h"

/* 6.31 GetDescField */

UTEST_F(row, 6_31_get_desc_field_ird) {
  SQLHDESC ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);

  EXPECT_EQ(desc_short(ird, 0, SQL_DESC_COUNT), 6);
  EXPECT_EQ(desc_short(ird, 0, SQL_DESC_TOP_LEVEL_COUNT), 6);
  EXPECT_EQ(desc_short(ird, 0, SQL_DESC_ALLOC_TYPE), SQL_DESC_ALLOC_AUTO);
  EXPECT_EQ(desc_short(ird, 0, SQL_DESC_KEY_TYPE), 0);
  EXPECT_STREQ(desc_string(ird, 0, SQL_DESC_DYNAMIC_FUNCTION), "SELECT CURSOR");
  EXPECT_EQ(desc_int(ird, 0, SQL_DESC_DYNAMIC_FUNCTION_CODE),
            SQL_DIAG_SELECT_CURSOR);

  EXPECT_EQ(desc_short(ird, COL_VARCHAR, SQL_DESC_TYPE), SQL_VARCHAR);
  EXPECT_EQ(desc_int(ird, COL_VARCHAR, SQL_DESC_LENGTH), 20);
  EXPECT_EQ(desc_int(ird, COL_VARCHAR, SQL_DESC_OCTET_LENGTH), 80);
  EXPECT_STREQ(desc_string(ird, COL_VARCHAR, SQL_DESC_NAME), "COL2");
  EXPECT_EQ(desc_short(ird, COL_VARCHAR, SQL_DESC_UNNAMED), SQL_NAMED);
  EXPECT_EQ(desc_short(ird, COL_VARCHAR, SQL_DESC_NULLABLE), SQL_NULLABLE);
  EXPECT_EQ(desc_int(ird, COL_VARCHAR, SQL_DESC_LEVEL), 0);
  EXPECT_EQ(desc_short(ird, COL_VARCHAR, SQL_DESC_KEY_MEMBER), 0);
  EXPECT_STREQ(desc_string(ird, COL_VARCHAR, SQL_DESC_CHARACTER_SET_CATALOG),
               ":memory:");
  EXPECT_STREQ(desc_string(ird, COL_VARCHAR, SQL_DESC_CHARACTER_SET_SCHEMA),
               "INFORMATION_SCHEMA");
  EXPECT_STREQ(desc_string(ird, COL_VARCHAR, SQL_DESC_CHARACTER_SET_NAME),
               "UTF8");
  EXPECT_STREQ(desc_string(ird, COL_VARCHAR, SQL_DESC_COLLATION_NAME), "");

  EXPECT_EQ(desc_short(ird, COL_NUMERIC, SQL_DESC_TYPE), SQL_NUMERIC);
  EXPECT_EQ(desc_short(ird, COL_NUMERIC, SQL_DESC_PRECISION), 5);
  EXPECT_EQ(desc_short(ird, COL_NUMERIC, SQL_DESC_SCALE), 2);
  EXPECT_EQ(desc_short(ird, COL_NULL, SQL_DESC_PRECISION), 32);
  EXPECT_EQ(desc_short(ird, COL_DOUBLE, SQL_DESC_PRECISION), 53);

  EXPECT_EQ(desc_short(ird, COL_DATE, SQL_DESC_TYPE), SQL_DATETIME);
  EXPECT_EQ(desc_short(ird, COL_DATE, SQL_DESC_DATETIME_INTERVAL_CODE),
            SQL_CODE_DATE);
  EXPECT_EQ(desc_int(ird, COL_DATE, SQL_DESC_LENGTH), 10);
  EXPECT_EQ(desc_short(ird, COL_DATE, SQL_DESC_PRECISION), 0);
}

/* Only the fields in Table 22 can be retrieved from the IRD, and only after a
 * statement is executed. */
UTEST_F(db, 6_31_get_desc_field_ird_not_executed) {
  SQLHDESC ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);
  SQLSMALLINT count;
  SQLPOINTER p;

  EXPECT_EQ(SQLGetDescField(ird, 0, SQL_DESC_COUNT, &count, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ird, "HY007");

  ASSERT_EQ(run_sql(utest_fixture->stmt, "VALUES 1"), SQL_SUCCESS);
  EXPECT_EQ(SQLGetDescField(ird, 1, SQL_DESC_DATA_POINTER, &p, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ird, "HY091");
  EXPECT_EQ(SQLGetDescField(ird, 0, SQL_DESC_ARRAY_SIZE, &count, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ird, "HY091");
}

/* A statement that isn't a query has no columns. */
UTEST_F(db, 6_31_get_desc_field_ird_not_a_query) {
  SQLHDESC ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);

  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_EQ(desc_short(ird, 0, SQL_DESC_COUNT), 0);
  EXPECT_STREQ(desc_string(ird, 0, SQL_DESC_DYNAMIC_FUNCTION), "CREATE TABLE");
}

/* The defaults from Table 23 for an ARD. */
UTEST_F(db, 6_31_get_desc_field_ard_defaults) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLPOINTER p = &p;
  SQLINTEGER i;

  EXPECT_EQ(desc_short(ard, 0, SQL_DESC_ALLOC_TYPE), SQL_DESC_ALLOC_AUTO);
  EXPECT_EQ(desc_int(ard, 0, SQL_DESC_ARRAY_SIZE), 1);
  EXPECT_EQ(desc_short(ard, 0, SQL_DESC_COUNT), 0);
  EXPECT_EQ(desc_short(ard, 0, SQL_DESC_TOP_LEVEL_COUNT), 0);
  EXPECT_EQ(SQLGetDescField(ard, 0, SQL_DESC_ARRAY_STATUS_POINTER, &p, 0, NULL),
            SQL_SUCCESS);
  EXPECT_TRUE(p == NULL);

  /* A record that doesn't exist yet. */
  EXPECT_EQ(SQLGetDescField(ard, 1, SQL_DESC_TYPE, &i, 0, NULL), SQL_NO_DATA);

  /* A new record has the defaults. */
  ASSERT_EQ(SQLSetDescField(ard, 0, SQL_DESC_COUNT, SMALLINT_VALUE(1), 0),
            SQL_SUCCESS);
  EXPECT_EQ(desc_short(ard, 1, SQL_DESC_TYPE), SQL_DEFAULT);
  EXPECT_EQ(desc_int(ard, 1, SQL_DESC_LEVEL), 0);
  EXPECT_EQ(SQLGetDescField(ard, 1, SQL_DESC_INDICATOR_POINTER, &p, 0, NULL),
            SQL_SUCCESS);
  EXPECT_TRUE(p == NULL);
}

/* A field that was never set is undefined. */
UTEST_F(db, 6_31_get_desc_field_undefined) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);
  SQLINTEGER i;

  ASSERT_EQ(SQLSetDescField(ard, 0, SQL_DESC_COUNT, SMALLINT_VALUE(1), 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetDescField(ard, 1, SQL_DESC_LENGTH, &i, 0, NULL), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "HY091");

  ASSERT_EQ(SQLSetDescField(ipd, 1, SQL_DESC_NAME, (SQLPOINTER) "p", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_STREQ(desc_string(ipd, 1, SQL_DESC_NAME), "p");
  EXPECT_EQ(SQLGetDescField(ipd, 1, SQL_DESC_TYPE, &i, 0, NULL), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ipd, "HY091");
}

UTEST_F(db, 6_31_get_desc_field_dynamic_function) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);

  ASSERT_EQ(run_sql(utest_fixture->stmt, "CREATE TABLE t (x INT)"),
            SQL_SUCCESS);
  EXPECT_STREQ(desc_string(ipd, 0, SQL_DESC_DYNAMIC_FUNCTION), "CREATE TABLE");
  EXPECT_STREQ(desc_string(ard, 0, SQL_DESC_DYNAMIC_FUNCTION), "(error)");
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "HY091");
}

UTEST_F(row, 6_31_get_desc_field_invalid) {
  SQLHDESC ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);
  SQLINTEGER i;

  EXPECT_EQ(SQLGetDescField(ird, 1, 9999, &i, 0, NULL), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ird, "HY091");
  EXPECT_EQ(SQLGetDescField(ird, 0, SQL_DESC_TYPE, &i, 0, NULL), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ird, "07009");
  EXPECT_EQ(SQLGetDescField(ird, 7, SQL_DESC_TYPE, &i, 0, NULL), SQL_NO_DATA);
  EXPECT_EQ(SQLGetDescField(ird, 1, SQL_DESC_TYPE, NULL, 0, NULL), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ird, "HY009");
  EXPECT_EQ(SQLGetDescField(utest_fixture->stmt, 1, SQL_DESC_TYPE, &i, 0, NULL),
            SQL_INVALID_HANDLE);
}

UTEST_F(row, 6_31_get_desc_field_truncated) {
  SQLHDESC ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);
  SQLCHAR name[3];
  SQLINTEGER len;

  EXPECT_EQ(SQLGetDescField(ird, COL_VARCHAR, SQL_DESC_NAME, name, sizeof(name),
                            &len),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_STATE(SQL_HANDLE_DESC, ird, "01004");
  EXPECT_STREQ((char *)name, "CO");
  EXPECT_EQ(len, 4);
}
