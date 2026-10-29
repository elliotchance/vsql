/*
 * test_main.c tests the C that "vsql module" generates for test.mod (and
 * test_other.mod). Run it with "make module-test".
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "test.h"
#include "test_other.h"

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

/* The statement information items of GET DIAGNOSTICS. */
struct statement {
  long number, committed, rolled_back, active;
  char more[2], function[31], dynamic[3];
  short code;
  long long dynamic_code, rows;
};

static void get_st(char *sqlstate, struct statement *st) {
  get_statement(sqlstate, &st->number, st->more, st->function, &st->code,
                st->dynamic, &st->dynamic_code, &st->rows, &st->committed,
                &st->rolled_back, &st->active);
}

/* The condition information items of GET DIAGNOSTICS for condition n. */
struct condition {
  long long number;
  long length, octet_length;
  char state[6], message[101], class_origin[11], subclass_origin[11],
      connection[51], server[51], table[11];
};

static void get_co(char *sqlstate, long n, struct condition *co) {
  get_condition(sqlstate, &n, &co->number, co->state, co->message, &co->length,
                &co->octet_length, co->class_origin, co->subclass_origin,
                co->connection, co->server, co->table);
}

#define CHECK(condition)                                                       \
  do {                                                                         \
    if (!(condition)) {                                                        \
      fprintf(stderr, "%s:%d: %s\n", __FILE__, __LINE__, #condition);          \
      failures++;                                                              \
    }                                                                          \
  } while (0)

int main(void) {
  char sqlstate[6];
  char server[51], name[51], user[51], c[6], v[11], c3[4], v3[4];
  short s = 1, s_ind = 0;
  long i = 2, f = 1, v_null = -1, x;
  long long b = 3, unused = 0, rows, c_ind = 0;
  float r = 4.5f;
  double d = 5.5;
  struct statement st;
  struct condition co;
  char sql[101], function[31];
  long min, max, count, n, type, length, nullable, indicator, returned, code;
  short top;
  long long key;

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

  /* 23.1: A condition raised by the C runtime. */
  EXPECT(get_co(sqlstate, 1, &co), "00000");
  CHECK(co.number == 1);
  CHECK(strcmp(co.state, "22024") == 0);
  CHECK(strcmp(co.message, "data exception: unterminated C string") == 0);
  CHECK(co.length == 37 && co.octet_length == 37);
  CHECK(strcmp(co.class_origin, "ISO 9075") == 0);
  CHECK(strcmp(co.subclass_origin, "ISO 9075") == 0);
  CHECK(strcmp(co.connection, "DEFAULT") == 0);
  CHECK(strcmp(co.server, "DEFAULT") == 0);
  CHECK(strcmp(co.table, "") == 0);

  /* An error from libvsql. */
  EXPECT(missing_table(sqlstate), "42P01");

  /* 23.1: A condition from libvsql. */
  EXPECT(get_st(sqlstate, &st), "00000");
  CHECK(st.number == 1);
  CHECK(strcmp(st.more, "N") == 0);
  CHECK(strcmp(st.function, "DELETE WHERE") == 0 && st.code == 19);
  CHECK(strcmp(st.dynamic, "  ") == 0 && st.dynamic_code == 0);
  CHECK(st.active == 1);
  EXPECT(get_co(sqlstate, 1, &co), "00000");
  CHECK(strcmp(co.state, "42P01") == 0);
  CHECK(co.length > 0 && co.length == (long)strlen(co.message));
  CHECK(strcmp(co.class_origin, "ISO 9075") == 0);
  CHECK(strcmp(co.subclass_origin, "vsql") == 0);

  /* GR 3: invalid condition number. GET DIAGNOSTICS doesn't empty the
   * diagnostics area. */
  EXPECT(get_co(sqlstate, 0, &co), "35000");
  EXPECT(get_co(sqlstate, 2, &co), "35000");
  EXPECT(get_short_message(sqlstate, c3), "01004");
  CHECK(strlen(c3) == 3);
  EXPECT(get_st(sqlstate, &st), "00000");
  CHECK(st.number == 1);

  /* 18.1 GR 1: An active transaction blocks a connection statement. */
  EXPECT(connect_literal(sqlstate), "0A001");
  EXPECT(set_connection_default(sqlstate), "0A001");
  EXPECT(disconnect_all(sqlstate), "25001");
  EXPECT(commit_work(sqlstate), "00000");
  EXPECT(get_st(sqlstate, &st), "00000");
  CHECK(st.number == 0 && st.committed == 1 && st.rolled_back == 0);
  CHECK(strcmp(st.function, "COMMIT WORK") == 0 && st.code == 11);
  CHECK(st.active == 0);

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
  EXPECT(get_st(sqlstate, &st), "00000");
  CHECK(st.rows == 1 && strcmp(st.function, "INSERT") == 0 && st.code == 50);
  EXPECT(rollback_work(sqlstate), "00000");
  EXPECT(get_st(sqlstate, &st), "00000");
  CHECK(st.committed == 0 && st.rolled_back == 1);
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

  /* 14.1 <declare cursor>: A cursor that has never been opened isn't open. */
  EXPECT(create_cur(sqlstate), "00000");
  x = 1;
  strcpy(v, "one");
  EXPECT(insert_cur(sqlstate, &x, v), "00000");
  x = 2;
  strcpy(v, "two");
  EXPECT(insert_cur(sqlstate, &x, v), "00000");
  x = 3;
  strcpy(v, "three");
  EXPECT(insert_cur(sqlstate, &x, v), "00000");
  EXPECT(fetch_c1(sqlstate, &x, v3, &i), "24000");
  EXPECT(close_c1(sqlstate), "24000");

  /* 14.4 <open statement> with the host parameter of the procedure. */
  x = 2;
  EXPECT(open_c1(sqlstate, &x), "00000");
  EXPECT(get_st(sqlstate, &st), "00000");
  CHECK(strcmp(st.function, "OPEN") == 0 && st.code == 53);
  EXPECT(open_c1(sqlstate, &x), "24000");

  /* 14.5 <fetch statement>, and positioned UPDATE and DELETE. */
  EXPECT(delete_c1(sqlstate), "24000");
  EXPECT(fetch_c1(sqlstate, &x, v3, &i), "00000");
  CHECK(x == 2 && strcmp(v3, "two") == 0 && i == 3);
  strcpy(v, "TWO");
  EXPECT(update_c1(sqlstate, v), "00000");
  EXPECT(get_st(sqlstate, &st), "00000");
  CHECK(strcmp(st.function, "UPDATE CURSOR") == 0 && st.code == 81);
  CHECK(st.rows == 1);
  EXPECT(fetch_c1(sqlstate, &x, v3, &i), "01004");
  CHECK(x == 3 && strcmp(v3, "thr") == 0 && i == 5);
  EXPECT(delete_c1(sqlstate), "00000");
  EXPECT(get_st(sqlstate, &st), "00000");
  CHECK(strcmp(st.function, "DELETE CURSOR") == 0 && st.code == 18);
  EXPECT(delete_c1(sqlstate), "24000");
  EXPECT(fetch_c1(sqlstate, &x, v3, &i), "02000");
  EXPECT(get_st(sqlstate, &st), "00000");
  CHECK(strcmp(st.function, "FETCH") == 0 && st.code == 45);

  /* 14.6 <close statement>. The cursor can be opened again. */
  EXPECT(close_c1(sqlstate), "00000");
  EXPECT(close_c1(sqlstate), "24000");
  x = 0;
  EXPECT(open_c1(sqlstate, &x), "00000");
  EXPECT(fetch_c1(sqlstate, &x, v3, &i), "00000");
  CHECK(x == 1);

  /* A commit closes a cursor that isn't holdable. */
  EXPECT(commit_work(sqlstate), "00000");
  EXPECT(fetch_c1(sqlstate, &x, v3, &i), "24000");

  /* A holdable cursor stays open, but must be fetched again before its row
   * can be changed. A rollback closes it. */
  EXPECT(open_held(sqlstate), "00000");
  EXPECT(fetch_held(sqlstate, &x), "00000");
  CHECK(x == 1);
  EXPECT(commit_work(sqlstate), "00000");
  EXPECT(delete_held(sqlstate), "24000");
  EXPECT(fetch_held(sqlstate, &x), "00000");
  CHECK(x == 2);
  EXPECT(delete_held(sqlstate), "00000");
  EXPECT(rollback_work(sqlstate), "00000");
  EXPECT(fetch_held(sqlstate, &x), "24000");

  /* The number of columns of SELECT * is checked when it's fetched. */
  EXPECT(open_all(sqlstate), "00000");
  EXPECT(fetch_all(sqlstate, &x), "07002");
  EXPECT(rollback_work(sqlstate), "00000");

  /*
   * Feature F181, "Multiple module support": test_other.mod has the same
   * SQL-connections, SQL-transactions and first diagnostics area, but the
   * schema of the module is the default schema of its statements, and it has
   * its own cursors.
   */
  EXPECT(create_schema(sqlstate), "00000");
  EXPECT(commit_work(sqlstate), "00000");
  EXPECT(other_create(sqlstate), "00000");
  EXPECT(other_count(sqlstate, &rows), "00000");
  x = 10;
  strcpy(v, "ten");
  EXPECT(insert_cur(sqlstate, &x, v), "00000");
  EXPECT(other_count(sqlstate, &b), "00000");
  CHECK(b == rows + 1);
  EXPECT(other_count_own(sqlstate, &b), "00000");
  CHECK(b == 0);
  EXPECT(rollback_work(sqlstate), "00000");
  EXPECT(other_count(sqlstate, &b), "00000");
  CHECK(b == rows);

  EXPECT(other_missing(sqlstate), "42P01");
  EXPECT(get_st(sqlstate, &st), "00000");
  CHECK(st.number == 1 && strcmp(st.function, "DELETE WHERE") == 0);

  x = 0;
  EXPECT(open_c1(sqlstate, &x), "00000");
  EXPECT(other_open(sqlstate), "00000");
  EXPECT(other_fetch(sqlstate, &x), "00000");
  EXPECT(other_close(sqlstate), "00000");
  EXPECT(other_close(sqlstate), "24000");
  EXPECT(fetch_c1(sqlstate, &x, v3, &i), "00000");
  EXPECT(close_c1(sqlstate), "00000");

  /* A connection statement of one module is for both of them. */
  EXPECT(other_disconnect(sqlstate), "25001");
  EXPECT(rollback_work(sqlstate), "00000");
  EXPECT(other_disconnect(sqlstate), "00000");
  EXPECT(create_table(sqlstate), "08003");

  /* Feature B031, "Basic dynamic SQL". */
  EXPECT(connect_default(sqlstate), "00000");
  strcpy(sql, "CREATE TABLE dyn (x INTEGER, y VARCHAR(10))");
  EXPECT(execute_immediate(sqlstate, sql), "00000");
  EXPECT(get_st(sqlstate, &st), "01004");
  CHECK(st.code == 43 && strcmp(st.dynamic, "CR") == 0 &&
        st.dynamic_code == 77);
  EXPECT(create_schema(sqlstate), "00000");
  EXPECT(commit_work(sqlstate), "00000");
  strcpy(sql, "SELECT x FROM dyn");
  EXPECT(execute_immediate(sqlstate, sql), "42000");
  strcpy(sql, "DELETE FROM dyn WHERE x = ?");
  EXPECT(execute_immediate(sqlstate, sql), "42000");

  /* 20.13 <execute statement>, with host parameters. */
  strcpy(sql, "INSERT INTO dyn (x, y) VALUES (?, ?)");
  EXPECT(prepare_s1(sqlstate, sql), "00000");
  EXPECT(execute_s1(sqlstate), "07004");
  EXPECT(execute_s1_into(sqlstate, &x, v, &i, &x), "07002");
  x = 1;
  i = 0;
  strcpy(v, "one");
  EXPECT(execute_s1_using(sqlstate, &x, v, &i), "00000");
  EXPECT(get_st(sqlstate, &st), "01004");
  CHECK(st.code == 44 && strcmp(st.function, "EXECUTE") == 0 &&
        st.dynamic_code == 50 && st.rows == 1);
  x = 2;
  i = -1;
  EXPECT(execute_s1_using(sqlstate, &x, v, &i), "00000");

  /* 20.21 <dynamic single row select statement>. */
  strcpy(sql, "SELECT x, y FROM dyn WHERE x = ?");
  EXPECT(prepare_s1(sqlstate, sql), "00000");
  EXPECT(execute_s1(sqlstate), "07007");
  min = 1;
  EXPECT(execute_s1_into(sqlstate, &x, v, &i, &min), "00000");
  CHECK(x == 1 && strcmp(v, "one") == 0 && i >= 0);
  min = 2;
  EXPECT(execute_s1_into(sqlstate, &x, v, &i, &min), "00000");
  CHECK(x == 2 && i == -1);
  EXPECT(get_st(sqlstate, &st), "01004");
  CHECK(strcmp(st.dynamic, "SE") == 0 && st.dynamic_code == 41);
  min = 3;
  EXPECT(execute_s1_into(sqlstate, &x, v, &i, &min), "02000");
  strcpy(sql, "SELECT x, y FROM dyn WHERE x > ?");
  EXPECT(prepare_s1(sqlstate, sql), "00000");
  min = 0;
  EXPECT(execute_s1_into(sqlstate, &x, v, &i, &min), "21000");
  strcpy(sql, "SELECT x, y FROM dyn WHERE x > ? ORDER BY x");
  EXPECT(prepare_s1(sqlstate, sql), "00000");
  EXPECT(execute_s1_into(sqlstate, &x, v, &i, &min), "07003");
  EXPECT(deallocate_s1(sqlstate), "00000");
  EXPECT(deallocate_s1(sqlstate), "26000");
  EXPECT(execute_s1(sqlstate), "26000");
  strcpy(sql, "COMMIT");
  EXPECT(prepare_s1(sqlstate, sql), "42000");
  strcpy(sql, "DELETE FROM missing");
  EXPECT(prepare_s1(sqlstate, sql), "00000");
  EXPECT(execute_s1(sqlstate), "42P01");

  /* 20.2 to 20.5, and 20.10 <describe statement>. */
  max = 0;
  EXPECT(allocate_d(sqlstate, &max), "07009");
  max = 1;
  EXPECT(allocate_d(sqlstate, &max), "00000");
  EXPECT(allocate_d(sqlstate, &max), "33000");
  strcpy(sql, "SELECT x, y FROM dyn WHERE x > ?");
  EXPECT(prepare_s1(sqlstate, sql), "00000");
  EXPECT(describe_s1(sqlstate), "01005");
  EXPECT(get_header(sqlstate, &count, &top, &key, function, &code), "00000");
  CHECK(count == 2 && top == 2);
  EXPECT(deallocate_d(sqlstate), "00000");
  EXPECT(deallocate_d(sqlstate), "33000");
  EXPECT(describe_s1(sqlstate), "33000");
  max = 2;
  EXPECT(allocate_d(sqlstate, &max), "00000");
  EXPECT(describe_s1(sqlstate), "00000");
  EXPECT(get_header(sqlstate, &count, &top, &key, function, &code), "00000");
  CHECK(count == 2 && top == 2 && key == 0 &&
        strcmp(function, "SELECT CURSOR") == 0 && code == 85);
  n = 1;
  EXPECT(get_item(sqlstate, &n, &type, &length, name, &nullable, &indicator,
                  &returned),
         "00000");
  CHECK(type == 4 && strcmp(name, "X") == 0 && nullable == 1);
  n = 2;
  EXPECT(get_item(sqlstate, &n, &type, &length, name, &nullable, &indicator,
                  &returned),
         "00000");
  CHECK(type == 12 && length == 10 && strcmp(name, "Y") == 0);
  n = 3;
  EXPECT(get_item(sqlstate, &n, &type, &length, name, &nullable, &indicator,
                  &returned),
         "07009");

  /* 20.15 <dynamic declare cursor>, with an SQL descriptor area. */
  EXPECT(open_dc_descriptor(sqlstate), "26000");
  EXPECT(prepare_s2(sqlstate), "00000");
  EXPECT(open_dc_descriptor(sqlstate), "07001");
  count = 1;
  EXPECT(set_count(sqlstate, &count), "00000");
  n = 2;
  EXPECT(get_int(sqlstate, &n, &x, &i), "02000");
  n = 1;
  x = 1;
  EXPECT(set_int(sqlstate, &n, &x), "00000");
  EXPECT(open_dc_descriptor(sqlstate), "00000");
  EXPECT(deallocate_s2(sqlstate), "24000");
  EXPECT(prepare_s2(sqlstate), "24000");
  EXPECT(describe_s1(sqlstate), "00000");
  EXPECT(fetch_dc_descriptor(sqlstate), "00000");
  n = 1;
  EXPECT(get_int(sqlstate, &n, &x, &i), "00000");
  CHECK(x == 2 && i == 0);
  EXPECT(get_varchar(sqlstate, &n, v), "22005");
  n = 2;
  EXPECT(get_varchar(sqlstate, &n, v), "22002");
  EXPECT(get_item(sqlstate, &n, &type, &length, name, &nullable, &indicator,
                  &returned),
         "00000");
  CHECK(indicator == -1);
  EXPECT(fetch_dc_descriptor(sqlstate), "02000");
  EXPECT(close_dc(sqlstate), "00000");
  EXPECT(get_st(sqlstate, &st), "00000");
  CHECK(st.code == 37 && strcmp(st.function, "DYNAMIC CLOSE") == 0);

  /* A dynamic cursor with host parameters, and a positioned UPDATE. */
  min = 0;
  EXPECT(open_dc(sqlstate, &min), "00000");
  EXPECT(fetch_dc(sqlstate, &x, v), "00000");
  CHECK(x == 1 && strcmp(v, "one") == 0);
  strcpy(v, "uno");
  EXPECT(update_dc(sqlstate, v), "00000");
  EXPECT(get_st(sqlstate, &st), "00000");
  CHECK(st.code == 42 && st.rows == 1);
  EXPECT(fetch_dc(sqlstate, &x, v), "22002");
  EXPECT(delete_dc(sqlstate), "00000");
  EXPECT(close_dc(sqlstate), "00000");
  EXPECT(deallocate_s2(sqlstate), "00000");
  EXPECT(open_dc(sqlstate, &min), "26000");

  /* Setting the components of an item descriptor area. */
  n = 2;
  strcpy(v, "two");
  EXPECT(set_varchar(sqlstate, &n, v), "00000");
  count = 2;
  EXPECT(set_count(sqlstate, &count), "00000");
  strcpy(v, "");
  EXPECT(get_varchar(sqlstate, &n, v), "00000");
  CHECK(strcmp(v, "two") == 0);
  EXPECT(set_null(sqlstate, &n), "00000");
  EXPECT(get_item(sqlstate, &n, &type, &length, name, &nullable, &indicator,
                  &returned),
         "00000");
  CHECK(type == 12 && length == 10 && indicator == -1);
  x = 1;
  EXPECT(set_level(sqlstate, &x), "0700E");
  x = 0;
  EXPECT(set_level(sqlstate, &x), "00000");
  code = 3;
  EXPECT(set_code(sqlstate, &code), "00000");
  code = 7;
  EXPECT(set_code(sqlstate, &code), "0700F");
  count = 5;
  EXPECT(set_count(sqlstate, &count), "00000");
  EXPECT(prepare_s2(sqlstate), "00000");
  EXPECT(open_dc_descriptor(sqlstate), "07008");

  /* EXECUTE with an SQL descriptor area for the input and the output. */
  EXPECT(allocate_in(sqlstate), "00000");
  x = 1;
  EXPECT(set_in(sqlstate, &x), "00000");
  EXPECT(set_in_count(sqlstate), "00000");
  strcpy(sql, "SELECT x, y FROM dyn WHERE x = ?");
  EXPECT(prepare_s1(sqlstate, sql), "00000");
  EXPECT(describe_s1(sqlstate), "00000");
  EXPECT(execute_s1_descriptor(sqlstate), "00000");
  n = 1;
  EXPECT(get_int(sqlstate, &n, &x, &i), "00000");
  CHECK(x == 1);
  n = 2;
  EXPECT(get_varchar(sqlstate, &n, v), "00000");
  CHECK(strcmp(v, "uno") == 0);

  /* The positioned DELETE deleted the row where x is 2. */
  x = 2;
  EXPECT(set_in(sqlstate, &x), "00000");
  EXPECT(execute_s1_descriptor(sqlstate), "02000");

  /* A GLOBAL SQL descriptor area is in every module. */
  EXPECT(allocate_global(sqlstate), "00000");
  EXPECT(other_global(sqlstate, &count), "00000");
  CHECK(count == 0);
  EXPECT(other_local(sqlstate, &count), "33000");
  EXPECT(rollback_work(sqlstate), "00000");

  /* 13.1 GR 4: The transaction is rolled back at exit. */
  if (failures > 0) {
    return 1;
  }
  printf("OK\n");
  return 0;
}
