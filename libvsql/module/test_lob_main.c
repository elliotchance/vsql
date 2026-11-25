/*
 * test_lob_main.c tests CHARACTER LARGE OBJECT(L) and BINARY LARGE OBJECT(L)
 * host parameters. Each is a struct with a length portion and a data portion.
 * The length of a CLOB(L) is in characters, and its data portion has L*4
 * octets (without a null character). The length of a BLOB(L) is in octets, and
 * its data portion has L octets.
 *
 * ISO/IEC 9075-2:2023, 9.1, Retrieval assignment, General Rules, 7.f, 7.g,
 * 7.m and 7.n
 * ISO/IEC 9075-2:2023, 9.3, Passing a value from a host language to the
 * SQL-server, General Rules, 5.f
 * ISO/IEC 9075-2:2023, 9.4, Passing a value from the SQL-server to a host
 * language, General Rules, 5.h
 * ISO/IEC 9075-2:2023, 13.5, Data type correspondences, Table 22
 */

#include <stdio.h>
#include <string.h>

#include "test_lob.h"

static int failures = 0;

static void expect(const char *what, const char *sqlstate,
                   const char *expected) {
  if (strcmp(sqlstate, expected) != 0) {
    fprintf(stderr, "%s: SQLSTATE %s, expected %s\n", what, sqlstate, expected);
    failures++;
  }
}

static void check(const char *what, long got, long expected) {
  if (got != expected) {
    fprintf(stderr, "%s: %ld, expected %ld\n", what, got, expected);
    failures++;
  }
}

static void check_octets(const char *what, const char *got,
                         const char *expected, size_t n) {
  if (memcmp(got, expected, n) != 0) {
    fprintf(stderr, "%s: wrong octets\n", what);
    failures++;
  }
}

int main(void) {
  char sqlstate[6];
  struct {
    long c_reserved;
    unsigned long c_length;
    char c_data[4 * 4];
  } c;
  struct {
    long c2_reserved;
    unsigned long c2_length;
    char c2_data[2 * 4];
  } c2;
  struct {
    long b_reserved;
    unsigned long b_length;
    char b_data[6];
  } b;
  struct {
    long b1_reserved;
    unsigned long b1_length;
    char b1_data[1];
  } b1;
  long id, ci, bi;
  short bi_in;

  create_t(sqlstate);
  expect("CREATE TABLE", sqlstate, "00000");

  /* A CLOB is the first c_length characters of its data (the rest isn't
   * used), and a BLOB is the first b_length octets of its data. */
  id = 1;
  memcpy(c.c_data, "h\xc3\xa9llo", 6);
  c.c_length = 3;
  memcpy(b.b_data, "\xca\x00\xfe\xff", 4);
  b.b_length = 3;
  bi_in = 0;
  insert_t(sqlstate, &id, &c, &b, &bi_in);
  expect("INSERT 1", sqlstate, "00000");

  /* An empty CLOB, and a NULL. */
  id = 2;
  c.c_length = 0;
  bi_in = -1;
  insert_t(sqlstate, &id, &c, &b, &bi_in);
  expect("INSERT 2", sqlstate, "00000");

  id = 1;
  memset(&c, 9, sizeof(c));
  memset(&b, 9, sizeof(b));
  ci = 9;
  bi = 9;
  select_t(sqlstate, &id, &c, &ci, &b, &bi);
  expect("SELECT 1", sqlstate, "00000");
  check("length of CLOB(4)", (long)c.c_length, 3);
  check_octets("CLOB(4)", c.c_data, "h\xc3\xa9l", 4);
  check("indicator of CLOB(4)", ci, 0);
  check("length of BLOB(6)", (long)b.b_length, 3);
  check_octets("BLOB(6)", b.b_data, "\xca\x00\xfe", 3);
  check("indicator of BLOB(6)", bi, 0);

  id = 2;
  select_t(sqlstate, &id, &c, &ci, &b, &bi);
  expect("SELECT 2", sqlstate, "00000");
  check("length of empty CLOB(4)", (long)c.c_length, 0);
  check("indicator of empty CLOB(4)", ci, 0);
  check("indicator of NULL BLOB(6)", bi, -1);

  /* A value that's too long is cut to the first L characters (or octets),
   * with a warning, and the indicator is its length. */
  id = 1;
  select_short(sqlstate, &id, &c2, &ci, &b1, &bi);
  expect("SELECT short", sqlstate, "01004");
  check("length of CLOB(2)", (long)c2.c2_length, 2);
  check_octets("CLOB(2)", c2.c2_data, "h\xc3\xa9", 3);
  check("indicator of CLOB(2)", ci, 3);
  check("length of BLOB(1)", (long)b1.b1_length, 1);
  check_octets("BLOB(1)", b1.b1_data, "\xca", 1);
  check("indicator of BLOB(1)", bi, 3);

  /* A NULL without an indicator parameter. */
  id = 2;
  select_no_indicator(sqlstate, &id, &b);
  expect("SELECT NULL", sqlstate, "22002");

  rollback_t(sqlstate);

  if (failures > 0) {
    return 1;
  }
  printf("OK\n");
  return 0;
}
