/*
 * test.h is included by each of the libvsql unit tests (the std_..._test.c
 * files). The shared helpers are implemented in test.c, which is linked with
 * them.
 *
 * Each test checks one case, and is named after the Subclause of ISO/IEC
 * 9075-3 for the routine being tested (such as 6_30_get_data_... for 6.30,
 * GetData), in the file named after the V file for that Subclause. A fixture
 * gives each test its own handles:
 *
 *   env  An environment and a connection that isn't connected yet.
 *   db   An environment, a connection to a new in-memory database and a
 *        statement.
 *   row  The same as db, with the row from ROW_SQL fetched.
 *
 * utest.h makes each fixture's setup and teardown static, so they're defined
 * here (in every test file) and call the shared implementations.
 */

#ifndef LIBVSQL_TEST_H
#define LIBVSQL_TEST_H

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "libvsql.h"

/* utest.h isn't pedantic C99 on Windows (it uses an unnamed struct). */
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpedantic"
#include "utest.h"
#pragma GCC diagnostic pop

/* HANDLE_VALUE passes a handle as the Value of SQLSetStmtAttr. */
#define HANDLE_VALUE(h) ((SQLPOINTER)(intptr_t)(h))

/* EXPECT_STATE checks the SQLSTATE of the first diagnostic record. */
#define EXPECT_STATE(type, handle, expected)                                   \
  EXPECT_STREQ(sqlstate(type, handle), expected)

const char *sqlstate(SQLSMALLINT type, SQLINTEGER handle);

SQLRETURN run_sql(SQLHSTMT stmt, const char *sql);

SQLRETURN connect_memory(SQLHDBC dbc);

/* diag_int reads an SQLINTEGER header field. */
SQLINTEGER diag_int(SQLSMALLINT type, SQLINTEGER handle, SQLSMALLINT field);

/* diag_string reads a string field of the first record (or a header field). */
const char *diag_string(SQLSMALLINT type, SQLINTEGER handle, SQLSMALLINT field);

/* stmt_desc returns a descriptor of a statement, such as
 * SQL_ATTR_IMP_ROW_DESC. */
SQLHDESC stmt_desc(SQLHSTMT stmt, SQLINTEGER attribute);

/* desc_int reads an SQLINTEGER field of a descriptor. */
SQLINTEGER desc_int(SQLHDESC desc, SQLSMALLINT rn, SQLSMALLINT field);

/* desc_short reads an SQLSMALLINT field of a descriptor. */
SQLSMALLINT desc_short(SQLHDESC desc, SQLSMALLINT rn, SQLSMALLINT field);

/* desc_string reads a string field of a descriptor. */
const char *desc_string(SQLHDESC desc, SQLSMALLINT rn, SQLSMALLINT field);

/* fetch_strings fetches every row of the cursor and joins the string value of
 * a column of each row with ",", then closes the cursor. A NULL is "NULL". */
const char *fetch_strings(SQLHSTMT stmt, SQLSMALLINT column);

/* The handles are freed even if the test already freed some of them, so the
 * return values are ignored. */
void free_handles(SQLHENV env, SQLHDBC dbc, SQLHSTMT stmt);

struct env {
  SQLHENV env;
  SQLHDBC dbc;
};

void env_setup(int *utest_result, struct env *utest_fixture);
UTEST_UNUSED UTEST_F_SETUP(env) { env_setup(utest_result, utest_fixture); }

void env_teardown(int *utest_result, struct env *utest_fixture);
UTEST_UNUSED UTEST_F_TEARDOWN(env) {
  env_teardown(utest_result, utest_fixture);
}

struct db {
  SQLHENV env;
  SQLHDBC dbc;
  SQLHSTMT stmt;
};

void db_setup(int *utest_result, struct db *utest_fixture);
UTEST_UNUSED UTEST_F_SETUP(db) { db_setup(utest_result, utest_fixture); }

void db_teardown(int *utest_result, struct db *utest_fixture);
UTEST_UNUSED UTEST_F_TEARDOWN(db) { db_teardown(utest_result, utest_fixture); }

/* The columns of ROW_SQL. */
#define COL_NULL 1    /* INT, NULL */
#define COL_VARCHAR 2 /* VARCHAR(20), 'hello world' */
#define COL_DOUBLE 3  /* DOUBLE PRECISION, 4.56 */
#define COL_DATE 4    /* DATE, 2026-10-25 */
#define COL_BIGINT 5  /* BIGINT, 100000 */
#define COL_NUMERIC 6 /* NUMERIC(5, 2), 12.5 */
#define ROW_SQL                                                                \
  "SELECT CAST(NULL AS INT), CAST('hello world' AS VARCHAR(20)), "             \
  "CAST(4.56 AS DOUBLE PRECISION), DATE '2026-10-25', CAST(100000 AS "         \
  "BIGINT), CAST(12.5 AS NUMERIC(5, 2)) FROM (VALUES 1) AS t (x)"

struct row {
  SQLHENV env;
  SQLHDBC dbc;
  SQLHSTMT stmt;
};

void row_setup(int *utest_result, struct row *utest_fixture);
UTEST_UNUSED UTEST_F_SETUP(row) { row_setup(utest_result, utest_fixture); }

void row_teardown(int *utest_result, struct row *utest_fixture);
UTEST_UNUSED UTEST_F_TEARDOWN(row) {
  row_teardown(utest_result, utest_fixture);
}

/* column is what SQLDescribeCol returns for a column, see describe. */
struct column {
  SQLCHAR name[32];
  SQLSMALLINT name_length, type, digits, nullable;
  SQLINTEGER size;
};

/* describe calls SQLDescribeCol for column n. */
SQLRETURN describe(SQLHSTMT stmt, SQLSMALLINT n, struct column *col);

#endif
