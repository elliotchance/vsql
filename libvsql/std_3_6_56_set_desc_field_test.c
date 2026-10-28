#include "test.h"

/* 6.56 SetDescField */

/* Setting a field of a record after the last one adds records. */
UTEST_F(db, 6_56_set_desc_field) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);

  EXPECT_EQ(
      SQLSetDescField(ard, 2, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_INTEGER), 0),
      SQL_SUCCESS);
  EXPECT_EQ(desc_short(ard, 0, SQL_DESC_COUNT), 2);
  EXPECT_EQ(desc_short(ard, 1, SQL_DESC_TYPE), SQL_DEFAULT);
  EXPECT_EQ(desc_short(ard, 2, SQL_DESC_TYPE), SQL_INTEGER);
  EXPECT_EQ(desc_short(ard, 2, SQL_DESC_PRECISION), 32);
  EXPECT_EQ(desc_short(ard, 2, SQL_DESC_SCALE), 0);
}

UTEST_F(db, 6_56_set_desc_field_count) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLINTEGER i;

  EXPECT_EQ(SQLSetDescField(ard, 0, SQL_DESC_COUNT, SMALLINT_VALUE(3), 0),
            SQL_SUCCESS);
  EXPECT_EQ(desc_short(ard, 3, SQL_DESC_TYPE), SQL_DEFAULT);
  EXPECT_EQ(SQLSetDescField(ard, 0, SQL_DESC_COUNT, SMALLINT_VALUE(1), 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetDescField(ard, 2, SQL_DESC_TYPE, &i, 0, NULL), SQL_NO_DATA);
  EXPECT_EQ(SQLSetDescField(ard, 0, SQL_DESC_COUNT, SMALLINT_VALUE(-1), 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "07008");
}

UTEST_F(db, 6_56_set_desc_field_array_size) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);

  EXPECT_EQ(SQLSetDescField(ard, 0, SQL_DESC_ARRAY_SIZE, INTEGER_VALUE(5), 0),
            SQL_SUCCESS);
  EXPECT_EQ(desc_int(ard, 0, SQL_DESC_ARRAY_SIZE), 5);
  EXPECT_EQ(SQLSetDescField(ard, 0, SQL_DESC_ARRAY_SIZE, INTEGER_VALUE(0), 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "HY024");
}

/* Only the fields in Table 21 can be set for each type of descriptor. */
UTEST_F(row, 6_56_set_desc_field_not_settable) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLHDESC ird = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_ROW_DESC);
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);
  SQLSMALLINT statuses[1];

  EXPECT_EQ(
      SQLSetDescField(ird, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_INTEGER), 0),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ird, "HY091");
  EXPECT_EQ(SQLSetDescField(ird, 0, SQL_DESC_ARRAY_STATUS_POINTER, statuses, 0),
            SQL_SUCCESS);
  EXPECT_EQ(
      SQLSetDescField(ard, 1, SQL_DESC_PARAMETER_MODE, SMALLINT_VALUE(1), 0),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "HY091");
  EXPECT_EQ(
      SQLSetDescField(ipd, 1, SQL_DESC_PARAMETER_MODE, SMALLINT_VALUE(1), 0),
      SQL_SUCCESS);
  EXPECT_EQ(SQLSetDescField(ard, 0, SQL_DESC_ALLOC_TYPE, SMALLINT_VALUE(2), 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "HY091");
  EXPECT_EQ(SQLSetDescField(ard, 1, 9999, SMALLINT_VALUE(1), 0), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "HY091");
}

UTEST_F(db, 6_56_set_desc_field_record_zero) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);

  EXPECT_EQ(
      SQLSetDescField(ard, 0, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_INTEGER), 0),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "07009");
}

/* There are no ROW types, so the LEVEL is always 0. */
UTEST_F(db, 6_56_set_desc_field_level) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);

  EXPECT_EQ(SQLSetDescField(ard, 1, SQL_DESC_LEVEL, INTEGER_VALUE(0), 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLSetDescField(ard, 2, SQL_DESC_LEVEL, INTEGER_VALUE(1), 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "0700E");
}

/* An application descriptor has the types from Table 7, and an
 * implementation descriptor has the types from Table 6. */
UTEST_F(db, 6_56_set_desc_field_type) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);

  EXPECT_EQ(
      SQLSetDescField(ard, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_VARCHAR), 0),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "HY004");
  EXPECT_EQ(SQLSetDescField(ard, 1, SQL_DESC_TYPE, SMALLINT_VALUE(999), 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "HY004");
  EXPECT_EQ(SQLSetDescField(ard, 1, SQL_DESC_TYPE, SMALLINT_VALUE(30), 0),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "HYC00");

  /* The descriptor is unchanged by an error. */
  EXPECT_EQ(desc_short(ard, 0, SQL_DESC_COUNT), 0);

  EXPECT_EQ(
      SQLSetDescField(ipd, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_VARCHAR), 0),
      SQL_SUCCESS);
  EXPECT_EQ(desc_int(ipd, 1, SQL_DESC_LENGTH), 10485760);
  EXPECT_STREQ(desc_string(ipd, 1, SQL_DESC_CHARACTER_SET_NAME), "UTF8");
  EXPECT_EQ(
      SQLSetDescField(ipd, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_DEFAULT), 0),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ipd, "HY004");
}

/* The PRECISION of a datetime depends on its DATETIME_INTERVAL_CODE. */
UTEST_F(db, 6_56_set_desc_field_datetime_interval_code) {
  SQLHDESC ipd = stmt_desc(utest_fixture->stmt, SQL_ATTR_IMP_PARAM_DESC);

  ASSERT_EQ(
      SQLSetDescField(ipd, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_DATETIME), 0),
      SQL_SUCCESS);
  EXPECT_EQ(desc_short(ipd, 1, SQL_DESC_PRECISION), 0);
  ASSERT_EQ(SQLSetDescField(ipd, 1, SQL_DESC_DATETIME_INTERVAL_CODE,
                            SMALLINT_VALUE(SQL_CODE_TIMESTAMP), 0),
            SQL_SUCCESS);
  EXPECT_EQ(desc_short(ipd, 1, SQL_DESC_PRECISION), 6);
}

/* A DATA_POINTER needs a TYPE that has a C type, and it's unset when the TYPE
 * changes. */
UTEST_F(db, 6_56_set_desc_field_data_pointer) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);
  SQLDOUBLE d;
  SQLPOINTER p;

  ASSERT_EQ(
      SQLSetDescField(ard, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_NUMERIC), 0),
      SQL_SUCCESS);
  EXPECT_EQ(SQLSetDescField(ard, 1, SQL_DESC_DATA_POINTER, &d, 0), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "HY021");

  ASSERT_EQ(
      SQLSetDescField(ard, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_DOUBLE), 0),
      SQL_SUCCESS);
  EXPECT_EQ(SQLSetDescField(ard, 1, SQL_DESC_DATA_POINTER, &d, 0), SQL_SUCCESS);
  EXPECT_EQ(SQLGetDescField(ard, 1, SQL_DESC_DATA_POINTER, &p, 0, NULL),
            SQL_SUCCESS);
  EXPECT_TRUE(p == &d);

  ASSERT_EQ(SQLSetDescField(ard, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_REAL), 0),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetDescField(ard, 1, SQL_DESC_DATA_POINTER, &p, 0, NULL),
            SQL_SUCCESS);
  EXPECT_TRUE(p == NULL);
}

/* The character set fields are identifiers. */
UTEST_F(db, 6_56_set_desc_field_character_set) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);

  EXPECT_EQ(SQLSetDescField(ard, 1, SQL_DESC_CHARACTER_SET_NAME,
                            (SQLPOINTER) "  utf8  ", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_STREQ(desc_string(ard, 1, SQL_DESC_CHARACTER_SET_NAME), "utf8");
  EXPECT_EQ(SQLSetDescField(ard, 1, SQL_DESC_CHARACTER_SET_NAME,
                            (SQLPOINTER) "1abc", SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "2C000");
  EXPECT_EQ(SQLSetDescField(ard, 1, SQL_DESC_CHARACTER_SET_SCHEMA,
                            (SQLPOINTER) "a b", SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "3F000");
  EXPECT_EQ(SQLSetDescField(ard, 1, SQL_DESC_CHARACTER_SET_CATALOG,
                            (SQLPOINTER) "\"a b\"", SQL_NTS),
            SQL_SUCCESS);
  EXPECT_EQ(SQLSetDescField(ard, 1, SQL_DESC_CHARACTER_SET_CATALOG,
                            (SQLPOINTER) "", SQL_NTS),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "HY090");
}

UTEST_F(db, 6_56_set_desc_field_name) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);

  EXPECT_EQ(SQLSetDescField(ard, 1, SQL_DESC_NAME, (SQLPOINTER) "abcdef", 3),
            SQL_SUCCESS);
  EXPECT_STREQ(desc_string(ard, 1, SQL_DESC_NAME), "abc");
  EXPECT_EQ(SQLSetDescField(ard, 1, SQL_DESC_NAME, (SQLPOINTER) "abc", -5),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "HY090");
}

/* A descriptor allocated by the application is the same as an ARD. */
UTEST_F(db, 6_56_set_desc_field_user) {
  SQLHDESC desc;

  ASSERT_EQ(SQLAllocHandle(SQL_HANDLE_DESC, utest_fixture->dbc, &desc),
            SQL_SUCCESS);
  EXPECT_EQ(desc_int(desc, 0, SQL_DESC_ARRAY_SIZE), 1);
  EXPECT_EQ(
      SQLSetDescField(desc, 1, SQL_DESC_TYPE, SMALLINT_VALUE(SQL_SMALLINT), 0),
      SQL_SUCCESS);
  EXPECT_EQ(desc_short(desc, 1, SQL_DESC_PRECISION), 16);
  EXPECT_EQ(
      SQLSetDescField(desc, 1, SQL_DESC_PARAMETER_MODE, SMALLINT_VALUE(1), 0),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, desc, "HY091");
}

/* Value points to an INTEGER or SMALLINT field, so it can't be a null
 * pointer. A pointer field can be. */
UTEST_F(db, 6_56_set_desc_field_null_value) {
  SQLHDESC ard = stmt_desc(utest_fixture->stmt, SQL_ATTR_APP_ROW_DESC);

  EXPECT_EQ(SQLSetDescField(ard, 0, SQL_DESC_COUNT, NULL, 0), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "HY009");
  EXPECT_EQ(SQLSetDescField(ard, 0, SQL_DESC_ARRAY_SIZE, NULL, 0), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DESC, ard, "HY009");
  EXPECT_EQ(SQLSetDescField(ard, 0, SQL_DESC_ARRAY_STATUS_POINTER, NULL, 0),
            SQL_SUCCESS);
}
