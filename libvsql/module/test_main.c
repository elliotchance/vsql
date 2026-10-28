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
  char server[51], name[51], user[51], c[6], v[11];
  short s = 1;
  long i = 2, f = 1, v_null = -1;
  long long b = 3, unused = 0, rows;
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
