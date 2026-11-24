/*
 * test_binary_main.c tests BINARY(L) and BINARY VARYING(L) host parameters. A
 * BINARY(L) is a char array of L octets, and a BINARY VARYING(L) is a struct
 * with a length portion and a data portion of L octets.
 *
 * ISO/IEC 9075-2:2023, 9.1, Retrieval assignment, General Rules, 7.h to 7.l
 * ISO/IEC 9075-2:2023, 9.3, Passing a value from a host language to the
 * SQL-server, General Rules, 5.h
 * ISO/IEC 9075-2:2023, 9.4, Passing a value from the SQL-server to a host
 * language, General Rules, 5.i and 5.j
 * ISO/IEC 9075-2:2023, 13.5, Data type correspondences, Table 22
 */

#include <stdio.h>
#include <string.h>

#include "test_binary.h"

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
  char sqlstate[6], b[4], b2[2];
  struct {
    long v_reserved;
    unsigned long v_length;
    char v_data[6];
  } v;
  struct {
    long v3_reserved;
    unsigned long v3_length;
    char v3_data[3];
  } v3;
  long id, bi, vi;
  short vi_in;

  create_t(sqlstate);
  expect("CREATE TABLE", sqlstate, "00000");

  /* A BINARY(L) is all L octets (including X'00'), and a BINARY VARYING(L)
   * is the first hvn_length octets of its data. */
  id = 1;
  memcpy(b, "\x01\x00\x02\x00", 4);
  memcpy(v.v_data, "\xca\xfe\x00\xff", 4);
  v.v_length = 3;
  vi_in = 0;
  insert_t(sqlstate, &id, b, &v, &vi_in);
  expect("INSERT 1", sqlstate, "00000");

  /* A NULL. */
  id = 2;
  vi_in = -1;
  insert_t(sqlstate, &id, b, &v, &vi_in);
  expect("INSERT 2", sqlstate, "00000");

  id = 1;
  memset(b, 9, sizeof(b));
  memset(&v, 9, sizeof(v));
  bi = 9;
  vi = 9;
  select_t(sqlstate, &id, b, &bi, &v, &vi);
  expect("SELECT 1", sqlstate, "00000");
  check_octets("BINARY(4)", b, "\x01\x00\x02\x00", 4);
  check("indicator of BINARY(4)", bi, 0);
  check("length of VARBINARY(6)", (long)v.v_length, 3);
  check_octets("VARBINARY(6)", v.v_data, "\xca\xfe\x00", 3);
  check("indicator of VARBINARY(6)", vi, 0);

  /* A value that's too long is truncated (with a warning), and the indicator
   * is its length in octets. */
  select_short(sqlstate, &id, b2, &bi, &v3, &vi);
  expect("SELECT short", sqlstate, "01004");
  check_octets("BINARY(2)", b2, "\x01\x00", 2);
  check("indicator of BINARY(2)", bi, 4);
  check("length of VARBINARY(3)", (long)v3.v3_length, 3);
  check_octets("VARBINARY(3)", v3.v3_data, "\xca\xfe\x00", 3);
  check("indicator of VARBINARY(3)", vi, 0);

  /* A NULL sets the indicator, and is an exception without one. */
  id = 2;
  select_t(sqlstate, &id, b, &bi, &v, &vi);
  expect("SELECT 2", sqlstate, "00000");
  check("indicator of NULL", vi, -1);
  select_no_indicator(sqlstate, &id, &v);
  expect("SELECT NULL without an indicator", sqlstate, "22002");

  /* A character string isn't a binary string. */
  select_char(sqlstate, b);
  expect("SELECT 'a'", sqlstate, "07006");

  rollback_t(sqlstate);

  if (failures > 0) {
    return 1;
  }
  printf("OK\n");
  return 0;
}
