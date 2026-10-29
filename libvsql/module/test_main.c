/*
 * test_main.c tests the C that "vsql module" generates for test.mod. Run it
 * with "make module-test".
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "test.h"

static int failures = 0;

#define EXPECT(call, expected)                                                 \
  do {                                                                         \
    call;                                                                      \
    if (strcmp(sqlstate, expected) != 0) {                                     \
      fprintf(stderr, "%s:%d: %s: expected %s, got %s\n", __FILE__, __LINE__,  \
              #call, expected, sqlstate);                                      \
      failures++;                                                              \
    }                                                                          \
  } while (0)

int main(void) {
  char sqlstate[6];
  char server[51], name[51], user[51], c[6], v[11], c3[4], v3[4];
  short s = 1, s_ind = 0;
  long i = 2, f = 1, v_null = -1;
  long long b = 3, unused = 0, rows, c_ind = 0;
  float r = 4.5f;
  double d = 5.5;

  /* 13.4 GR 7.a: The first statement connects to DEFAULT. */
  EXPECT(create_table(sqlstate), "00000");
  strcpy(c, "ab");
  strcpy(v, "ignored");
  EXPECT(insert_row(sqlstate, &s, &i, &b, &r, &d, c, v, &f, &v_null, &unused),
         "00000");
  EXPECT(check_row(sqlstate, c, &f), "00000");
  rows = 2;
  EXPECT(count_rows(sqlstate, &rows), "22012");

  /* 14.7 <select statement: single row>. */
  s = 0;
  b = 0;
  r = 0;
  d = 0;
  f = 0;
  strcpy(c, "xxxxx");
  strcpy(v, "xxxxx");
  EXPECT(select_row(sqlstate, &s, &i, &b, &r, &d, c, v, &s_ind, &f), "00000");
  if (s != 1 || i != 2 || b != 3 || r != 4.5f || d != 5.5 ||
      strcmp(c, "ab   ") != 0 || s_ind != -1 || f != 1) {
    fprintf(stderr, "select_row: %d %ld %lld %f %f '%s' %d %ld\n", s, i, b, r,
            d, c, s_ind, f);
    failures++;
  }
  i = 3;
  EXPECT(select_row(sqlstate, &s, &i, &b, &r, &d, c, v, &s_ind, &f), "02000");
  i = 2;
  EXPECT(select_s(sqlstate, &s, &i), "21000");
  EXPECT(select_null(sqlstate, &b), "22002");
  EXPECT(select_all(sqlstate, &s), "07002");

  /* 9.1: A truncated string has the length in its indicator, and a CHARACTER
   * is padded with spaces. */
  EXPECT(select_strings(sqlstate, c3, &c_ind, v3, &i, &b), "01004");
  if (strcmp(c3, "int") != 0 || c_ind != 4 || i != -1 || b != 2) {
    fprintf(stderr, "select_strings: '%s' %lld %ld %lld\n", c3, c_ind, i, b);
    failures++;
  }
  i = 2;
  b = 3;

  /* 9.3 GR 5.b.iii: unterminated C string. */
  memset(c, 'x', sizeof(c));
  EXPECT(check_row(sqlstate, c, &f), "22024");

  /* An error from libvsql. */
  EXPECT(missing_table(sqlstate), "42P01");

  /* 18.1 GR 1: An active transaction blocks a connection statement. */
  EXPECT(connect_literal(sqlstate), "0A001");
  EXPECT(set_connection_default(sqlstate), "0A001");
  EXPECT(disconnect_all(sqlstate), "25001");
  EXPECT(commit_work(sqlstate), "00000");

  /* The changes were committed. */
  EXPECT(count_rows(sqlstate, &rows), "22012");
  EXPECT(rollback_work(sqlstate), "00000");

  /* START TRANSACTION and ROLLBACK. */
  EXPECT(start_transaction(sqlstate), "00000");
  EXPECT(insert_row(sqlstate, &s, &i, &b, &r, &d, c, v, &f, &v_null, &unused),
         "22024");
  strcpy(c, "ab");
  EXPECT(insert_row(sqlstate, &s, &i, &b, &r, &d, c, v, &f, &v_null, &unused),
         "00000");
  EXPECT(rollback_work(sqlstate), "00000");
  EXPECT(count_rows(sqlstate, &rows), "22012");
  EXPECT(rollback_work(sqlstate), "00000");

  /* 18.1: CONNECT TO. */
  EXPECT(connect_default(sqlstate), "08002");
  strcpy(server, ":memory:");
  strcpy(name, " other ");
  EXPECT(connect_to(server, name, sqlstate), "00000");
  strcpy(name, "OTHER");
  EXPECT(connect_to(server, name, sqlstate), "08002");
  strcpy(name, "\"other\"");
  EXPECT(connect_to(server, name, sqlstate), "00000");
  strcpy(name, "not valid");
  EXPECT(connect_to(server, name, sqlstate), "2E000");
  strcpy(name, "\"\"");
  EXPECT(connect_to(server, name, sqlstate), "2E000");
  strcpy(name, "\"a\"b\"");
  EXPECT(connect_to(server, name, sqlstate), "2E000");
  strcpy(name, "\"a\"\"b\"");
  EXPECT(connect_to(server, name, sqlstate), "00000");
  strcpy(name, "u");
  strcpy(user, "1user");
  EXPECT(connect_user(sqlstate, name, user), "28000");
  strcpy(user, "elliot");
  EXPECT(connect_user(sqlstate, name, user), "00000");
  strcpy(server, "/no/such/folder/x.vsql");
  strcpy(name, "bad");
  EXPECT(connect_to(server, name, sqlstate), "08001");
  EXPECT(connect_literal(sqlstate), "00000");

  /* The current connection is a new database. */
  EXPECT(missing_table(sqlstate), "42P01");
  EXPECT(rollback_work(sqlstate), "00000");
  EXPECT(create_table(sqlstate), "00000");
  EXPECT(commit_work(sqlstate), "00000");

  /* 18.2: SET CONNECTION. */
  strcpy(name, "missing");
  EXPECT(set_connection(sqlstate, name), "08003");
  strcpy(name, "1");
  EXPECT(set_connection(sqlstate, name), "2E000");
  strcpy(name, "other");
  EXPECT(set_connection(sqlstate, name), "00000");
  EXPECT(missing_table(sqlstate), "42P01");
  EXPECT(rollback_work(sqlstate), "00000");
  EXPECT(set_connection_default(sqlstate), "00000");
  EXPECT(count_rows(sqlstate, &rows), "22012");
  EXPECT(rollback_work(sqlstate), "00000");

  /* 18.3: DISCONNECT. */
  strcpy(name, "missing");
  EXPECT(disconnect(sqlstate, name), "08003");
  strcpy(name, "\"");
  EXPECT(disconnect(sqlstate, name), "2E000");
  strcpy(name, "other");
  EXPECT(disconnect(sqlstate, name), "00000");
  EXPECT(set_connection(sqlstate, name), "08003");
  EXPECT(disconnect_default(sqlstate), "00000");
  EXPECT(disconnect_default(sqlstate), "08003");

  /* 13.4 GR 7.c: There's no current connection after it's disconnected. */
  EXPECT(create_table(sqlstate), "08003");
  EXPECT(disconnect_current(sqlstate), "08003");
  strcpy(name, "literal");
  EXPECT(set_connection(sqlstate, name), "00000");
  EXPECT(disconnect_current(sqlstate), "00000");
  EXPECT(disconnect_all(sqlstate), "00000");
  EXPECT(disconnect_all(sqlstate), "00000");

  /* A new DEFAULT connection is a new database. */
  EXPECT(connect_default(sqlstate), "00000");
  EXPECT(create_table(sqlstate), "00000");

  /* 13.1 GR 4: The transaction is rolled back at exit. */
  if (failures > 0) {
    return 1;
  }
  printf("OK\n");
  return 0;
}
