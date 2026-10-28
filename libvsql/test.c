/*
 * test.c has the helpers that are shared by the libvsql unit tests (see
 * test.h), and runs them all. Build and run them with "make libvsql-test". It
 * uses utest.h (https://github.com/sheredom/utest.h).
 */

#include "test.h"

const char *sqlstate(SQLSMALLINT type, SQLINTEGER handle) {
  static SQLCHAR state[6];

  if (SQLGetDiagRec(type, handle, 1, state, NULL, NULL, 0, NULL) !=
      SQL_SUCCESS) {
    return "";
  }

  return (const char *)state;
}

SQLRETURN run_sql(SQLHSTMT stmt, const char *sql) {
  return SQLExecDirect(stmt, (SQLCHAR *)sql, SQL_NTS);
}

/* connect_default connects to the default server (an empty ServerName). */
SQLRETURN connect_default(SQLHDBC dbc) {
  return SQLConnect(dbc, NULL, 0, NULL, 0, NULL, 0);
}

SQLRETURN connect_memory(SQLHDBC dbc) {
  return SQLConnect(dbc, (SQLCHAR *)":memory:", SQL_NTS, NULL, 0, NULL, 0);
}

/* diag_int reads an SQLINTEGER header field. */
SQLINTEGER diag_int(SQLSMALLINT type, SQLINTEGER handle, SQLSMALLINT field) {
  SQLINTEGER value = -123;

  if (SQLGetDiagField(type, handle, 0, field, &value, 0, NULL) != SQL_SUCCESS) {
    return -456;
  }

  return value;
}

/* diag_string reads a string field of the first record (or a header field). */
const char *diag_string(SQLSMALLINT type, SQLINTEGER handle,
                        SQLSMALLINT field) {
  static SQLCHAR value[100];

  if (SQLGetDiagField(type, handle, 1, field, value, sizeof(value), NULL) !=
      SQL_SUCCESS) {
    return "(error)";
  }

  return (const char *)value;
}

/* stmt_desc returns a descriptor of a statement, such as
 * SQL_ATTR_IMP_ROW_DESC. */
SQLHDESC stmt_desc(SQLHSTMT stmt, SQLINTEGER attribute) {
  SQLHDESC desc = SQL_NULL_HANDLE;

  SQLGetStmtAttr(stmt, attribute, &desc, 0, NULL);

  return desc;
}

/* desc_int reads an SQLINTEGER field of a descriptor. */
SQLINTEGER desc_int(SQLHDESC desc, SQLSMALLINT rn, SQLSMALLINT field) {
  SQLINTEGER value = -123;

  if (SQLGetDescField(desc, rn, field, &value, 0, NULL) != SQL_SUCCESS) {
    return -456;
  }

  return value;
}

/* desc_short reads an SQLSMALLINT field of a descriptor. */
SQLSMALLINT desc_short(SQLHDESC desc, SQLSMALLINT rn, SQLSMALLINT field) {
  SQLSMALLINT value = -123;

  if (SQLGetDescField(desc, rn, field, &value, 0, NULL) != SQL_SUCCESS) {
    return -456;
  }

  return value;
}

/* desc_string reads a string field of a descriptor. */
const char *desc_string(SQLHDESC desc, SQLSMALLINT rn, SQLSMALLINT field) {
  static SQLCHAR value[100];

  if (SQLGetDescField(desc, rn, field, value, sizeof(value), NULL) !=
      SQL_SUCCESS) {
    return "(error)";
  }

  return (const char *)value;
}

/* fetch_strings fetches every row of the cursor and joins the string value of
 * a column of each row with ",", then closes the cursor. A NULL is "NULL". */
const char *fetch_strings(SQLHSTMT stmt, SQLSMALLINT column) {
  static char result[2000];
  char value[200];
  SQLINTEGER ind;

  result[0] = 0;
  while (SQLFetch(stmt) == SQL_SUCCESS) {
    if (SQLGetData(stmt, column, SQL_CHAR, value, sizeof(value), &ind) !=
        SQL_SUCCESS) {
      strcpy(value, "(error)");
    } else if (ind == SQL_NULL_DATA) {
      strcpy(value, "NULL");
    }
    if (result[0]) {
      strcat(result, ",");
    }
    strcat(result, value);
  }
  SQLCloseCursor(stmt);

  return result;
}

/* The handles are freed even if the test already freed some of them, so the
 * return values are ignored. */
void free_handles(SQLHENV env, SQLHDBC dbc, SQLHSTMT stmt) {
  if (stmt != SQL_NULL_HANDLE) {
    SQLFreeHandle(SQL_HANDLE_STMT, stmt);
  }
  SQLEndTran(SQL_HANDLE_DBC, dbc, SQL_ROLLBACK);
  SQLDisconnect(dbc);
  SQLFreeHandle(SQL_HANDLE_DBC, dbc);
  SQLFreeHandle(SQL_HANDLE_ENV, env);
}

void env_setup(int *utest_result, struct env *utest_fixture) {
  ASSERT_EQ(
      SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &utest_fixture->env),
      SQL_SUCCESS);
  ASSERT_EQ(
      SQLAllocHandle(SQL_HANDLE_DBC, utest_fixture->env, &utest_fixture->dbc),
      SQL_SUCCESS);
}

void env_teardown(int *utest_result, struct env *utest_fixture) {
  (void)utest_result;
  free_handles(utest_fixture->env, utest_fixture->dbc, SQL_NULL_HANDLE);
}

void db_setup(int *utest_result, struct db *utest_fixture) {
  ASSERT_EQ(
      SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &utest_fixture->env),
      SQL_SUCCESS);
  ASSERT_EQ(
      SQLAllocHandle(SQL_HANDLE_DBC, utest_fixture->env, &utest_fixture->dbc),
      SQL_SUCCESS);
  ASSERT_EQ(connect_memory(utest_fixture->dbc), SQL_SUCCESS);
  ASSERT_EQ(
      SQLAllocHandle(SQL_HANDLE_STMT, utest_fixture->dbc, &utest_fixture->stmt),
      SQL_SUCCESS);
}

void db_teardown(int *utest_result, struct db *utest_fixture) {
  (void)utest_result;
  free_handles(utest_fixture->env, utest_fixture->dbc, utest_fixture->stmt);
}

void row_setup(int *utest_result, struct row *utest_fixture) {
  ASSERT_EQ(
      SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &utest_fixture->env),
      SQL_SUCCESS);
  ASSERT_EQ(
      SQLAllocHandle(SQL_HANDLE_DBC, utest_fixture->env, &utest_fixture->dbc),
      SQL_SUCCESS);
  ASSERT_EQ(connect_memory(utest_fixture->dbc), SQL_SUCCESS);
  ASSERT_EQ(
      SQLAllocHandle(SQL_HANDLE_STMT, utest_fixture->dbc, &utest_fixture->stmt),
      SQL_SUCCESS);
  ASSERT_EQ(run_sql(utest_fixture->stmt, ROW_SQL), SQL_SUCCESS);
  ASSERT_EQ(SQLFetch(utest_fixture->stmt), SQL_SUCCESS);
}

void row_teardown(int *utest_result, struct row *utest_fixture) {
  (void)utest_result;
  free_handles(utest_fixture->env, utest_fixture->dbc, utest_fixture->stmt);
}

SQLRETURN describe(SQLHSTMT stmt, SQLSMALLINT n, struct column *col) {
  return SQLDescribeCol(stmt, n, col->name, sizeof(col->name),
                        &col->name_length, &col->type, &col->size, &col->digits,
                        &col->nullable);
}

UTEST_MAIN()
