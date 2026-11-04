#include "test.h"

/* 6.38 GetInfo */

UTEST_F(db, 6_38_get_info_string) {
  SQLCHAR value[100];
  SQLSMALLINT length;

  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_DBMS_NAME, value, sizeof(value),
                       &length),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)value, "vsql");
  EXPECT_EQ(length, 4);
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_SERVER_NAME, value,
                       sizeof(value), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)value, ":memory:");
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_SEARCH_PATTERN_ESCAPE, value,
                       sizeof(value), NULL),
            SQL_SUCCESS);
  EXPECT_STREQ((char *)value, "\\");

  /* The version is "00.00.0000" until set_version.sh sets it, so only the
   * format is checked. */
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_DBMS_VERSION, value,
                       sizeof(value), NULL),
            SQL_SUCCESS);
  EXPECT_GE(strlen((char *)value), (size_t)10);
  EXPECT_EQ(value[2], '.');
  EXPECT_EQ(value[5], '.');
}

UTEST_F(db, 6_38_get_info_truncated) {
  SQLCHAR value[3];
  SQLSMALLINT length;

  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_DBMS_NAME, value, sizeof(value),
                       &length),
            SQL_SUCCESS_WITH_INFO);
  EXPECT_STREQ((char *)value, "vs");
  EXPECT_EQ(length, 4);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "01004");
}

UTEST_F(db, 6_38_get_info_smallint) {
  SQLSMALLINT value = -1;

  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_MAXIMUM_TABLE_NAME_LENGTH,
                       &value, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(value, 128);
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_MAXIMUM_COLUMNS_IN_TABLE, &value,
                       0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(value, 1600);
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_MAXIMUM_COLUMNS_IN_SELECT,
                       &value, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(value, 0);
  EXPECT_EQ(
      SQLGetInfo(utest_fixture->dbc, SQL_IDENTIFIER_CASE, &value, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(value, SQL_IC_UPPER);
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_NULL_COLLATION, &value, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(value, SQL_NC_LOW);
  EXPECT_EQ(
      SQLGetInfo(utest_fixture->dbc, SQL_TRANSACTION_CAPABLE, &value, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(value, SQL_TC_ALL);
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_CURSOR_COMMIT_BEHAVIOR, &value,
                       0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(value, SQL_CB_PRESERVE);
}

UTEST_F(db, 6_38_get_info_integer) {
  SQLINTEGER value = -1;

  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_DEFAULT_TRANSACTION_ISOLATION,
                       &value, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(value, SQL_TRANSACTION_SERIALIZABLE);
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_TRANSACTION_ISOLATION_OPTION,
                       &value, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(value, SQL_TRANSACTION_READ_UNCOMMITTED |
                       SQL_TRANSACTION_READ_COMMITTED |
                       SQL_TRANSACTION_REPEATABLE_READ |
                       SQL_TRANSACTION_SERIALIZABLE);
  EXPECT_EQ(
      SQLGetInfo(utest_fixture->dbc, SQL_FETCH_DIRECTION, &value, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(value, SQL_FD_FETCH_NEXT | SQL_FD_FETCH_FIRST | SQL_FD_FETCH_LAST |
                       SQL_FD_FETCH_PRIOR | SQL_FD_FETCH_ABSOLUTE |
                       SQL_FD_FETCH_RELATIVE);
  EXPECT_EQ(
      SQLGetInfo(utest_fixture->dbc, SQL_CURSOR_SENSITIVITY, &value, 0, NULL),
      SQL_SUCCESS);
  EXPECT_EQ(value, SQL_INSENSITIVE);
}

UTEST_F(db, 6_38_get_info_invalid) {
  SQLINTEGER value;

  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, 9999, &value, 0, NULL), SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY096");
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_DBMS_NAME, NULL, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY009");
}

UTEST_F(env, 6_38_get_info_not_connected) {
  SQLCHAR value[100];

  EXPECT_EQ(
      SQLGetInfo(utest_fixture->dbc, SQL_DBMS_NAME, value, sizeof(value), NULL),
      SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "08003");
}

/* The sizes and the implementation information are the rows of the SQL_SIZING
 * and SQL_IMPLEMENTATION_INFO views, with the same answers as before they were
 * read from the views. */
UTEST_F(db, 6_38_get_info_views) {
  static const struct {
    SQLSMALLINT code;
    SQLSMALLINT value;
  } smallints[] = {
      {SQL_MAXIMUM_DRIVER_CONNECTIONS, 0},
      {SQL_MAXIMUM_CONCURRENT_ACTIVITIES, 0},
      {SQL_MAXIMUM_COLUMN_NAME_LENGTH, 128},
      {SQL_MAXIMUM_CURSOR_NAME_LENGTH, 128},
      {SQL_MAXIMUM_SCHEMA_NAME_LENGTH, 128},
      {SQL_MAXIMUM_CATALOG_NAME_LENGTH, 128},
      {SQL_MAXIMUM_TABLE_NAME_LENGTH, 128},
      {SQL_MAXIMUM_COLUMNS_IN_GROUP_BY, 0},
      {SQL_MAXIMUM_COLUMNS_IN_ORDER_BY, 0},
      {SQL_MAXIMUM_COLUMNS_IN_SELECT, 0},
      {SQL_MAXIMUM_COLUMNS_IN_TABLE, 1600},
      {SQL_MAXIMUM_TABLES_IN_SELECT, 0},
      {SQL_MAXIMUM_USER_NAME_LENGTH, 0},
      {SQL_MAXIMUM_IDENTIFIER_LENGTH, 128},
      {SQL_MAXIMUM_STMT_OCTETS, 0},
      {SQL_MAXIMUM_STMT_OCTETS_DATA, 0},
      {SQL_MAXIMUM_STMT_OCTETS_SCHEMA, 0},
      {SQL_CURSOR_COMMIT_BEHAVIOR, SQL_CB_PRESERVE},
      {SQL_IDENTIFIER_CASE, SQL_IC_UPPER},
      {SQL_NULL_COLLATION, SQL_NC_LOW},
      {SQL_TRANSACTION_CAPABLE, SQL_TC_ALL},
  };
  static const struct {
    SQLSMALLINT code;
    const char *value;
  } strings[] = {
      {SQL_DATA_SOURCE_NAME, ":memory:"},
      {SQL_SERVER_NAME, ":memory:"},
      {SQL_SEARCH_PATTERN_ESCAPE, "\\"},
      {SQL_DBMS_NAME, "vsql"},
      {SQL_SPECIAL_CHARACTERS, ""},
      {SQL_CATALOG_NAME, "Y"},
      {SQL_COLLATING_SEQUENCE, ""},
  };
  size_t i;
  SQLSMALLINT smallint;
  SQLINTEGER integer = -1;
  SQLCHAR value[100];

  for (i = 0; i < sizeof(smallints) / sizeof(smallints[0]); i++) {
    smallint = -1;
    EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, smallints[i].code, &smallint, 0,
                         NULL),
              SQL_SUCCESS);
    EXPECT_EQ(smallint, smallints[i].value);
  }
  for (i = 0; i < sizeof(strings) / sizeof(strings[0]); i++) {
    EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, strings[i].code, value,
                         sizeof(value), NULL),
              SQL_SUCCESS);
    EXPECT_STREQ((char *)value, strings[i].value);
  }
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_DEFAULT_TRANSACTION_ISOLATION,
                       &integer, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(integer, SQL_TRANSACTION_SERIALIZABLE);

  /* The sizing items that SQL/CLI doesn't have an information type for aren't
   * one. */
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, 25000, &integer, 0, NULL),
            SQL_ERROR);
  EXPECT_STATE(SQL_HANDLE_DBC, utest_fixture->dbc, "HY096");

  /* The views are read without an implicit ExecDirect, so there's still no
   * SQL-transaction. */
  EXPECT_EQ(
      diag_int(SQL_HANDLE_DBC, utest_fixture->dbc, SQL_DIAG_TRANSACTION_ACTIVE),
      0);
}

/* SET SESSION CHARACTERISTICS changes the default isolation level. */
UTEST_F(db, 6_38_get_info_session_isolation) {
  SQLINTEGER level = 0;
  ASSERT_EQ(run_sql(utest_fixture->stmt,
                    "SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION "
                    "LEVEL READ COMMITTED"),
            SQL_SUCCESS);
  EXPECT_EQ(SQLGetInfo(utest_fixture->dbc, SQL_DEFAULT_TRANSACTION_ISOLATION,
                       &level, 0, NULL),
            SQL_SUCCESS);
  EXPECT_EQ(level, SQL_TRANSACTION_READ_COMMITTED);
}
