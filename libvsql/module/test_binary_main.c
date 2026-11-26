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
 *
 * In an SQL descriptor area, a BINARY is TYPE 60 and a BINARY VARYING is TYPE
 * 61, and their LENGTH is in octets.
 *
 * ISO/IEC 9075-2:2023, 20.1, Description of SQL descriptor areas, Syntax
 * Rules, 6.c, 7.d and 7.e
 * ISO/IEC 9075-2:2023, 20.5, <set descriptor statement>, General Rules,
 * 4.c.iii.3
 * ISO/IEC 9075-2:2023, 20.10, <describe statement>, General Rules, 7.d.ii
 */

#include <stdio.h>
#include <string.h>

#include "test_binary.h"

/* The values of TYPE. */
#define BINARY 60
#define BINARY_VARYING 61

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

static void prepare(const char *sql) {
  char sqlstate[6], buffer[(200 + 1) * 4];

  strcpy(buffer, sql);
  prepare_s(sqlstate, buffer);
  expect(sql, sqlstate, "00000");
}

static void descriptors(void) {
  char sqlstate[6], b[3], c[(3 + 1) * 4], b4[4];
  struct {
    long data_reserved;
    unsigned long data_length;
    char data_data[6];
  } out;
  struct {
    long data_reserved;
    unsigned long data_length;
    char data_data[4];
  } in;
  long n, type, length, octet_length, returned;

  allocate_out(sqlstate);
  expect("ALLOCATE out_d", sqlstate, "00000");
  allocate_in(sqlstate);
  expect("ALLOCATE in_d", sqlstate, "00000");

  /* DESCRIBE sets the LENGTH and OCTET_LENGTH of a binary string to its
   * (maximum) length in octets. */
  prepare("SELECT CAST(X'0A' AS BINARY(3)), CAST(? AS VARBINARY(5)) "
          "FROM (VALUES 1) AS t (x)");
  describe_output(sqlstate);
  expect("DESCRIBE OUTPUT", sqlstate, "00000");
  n = 1;
  get_out(sqlstate, &n, &type, &length, &octet_length);
  check("TYPE of BINARY(3)", type, BINARY);
  check("LENGTH of BINARY(3)", length, 3);
  check("OCTET_LENGTH of BINARY(3)", octet_length, 3);
  n = 2;
  get_out(sqlstate, &n, &type, &length, &octet_length);
  check("TYPE of VARBINARY(5)", type, BINARY_VARYING);
  check("LENGTH of VARBINARY(5)", length, 5);
  check("OCTET_LENGTH of VARBINARY(5)", octet_length, 5);
  describe_input(sqlstate);
  expect("DESCRIBE INPUT", sqlstate, "00000");
  get_in(sqlstate, &type, &length);
  check("TYPE of ?", type, BINARY_VARYING);
  check("LENGTH of ?", length, 5);

  /* Setting TYPE sets LENGTH to 1. */
  type = BINARY_VARYING;
  set_in_type(sqlstate, &type);
  expect("SET TYPE", sqlstate, "00000");
  get_in(sqlstate, &type, &length);
  check("LENGTH after TYPE", length, 1);

  /* DATA must match the type: a BINARY VARYING(4) matches LENGTH 4. */
  length = 4;
  set_in_length(sqlstate, &length);
  in.data_length = 2;
  memcpy(in.data_data, "\x00\xff", 2);
  set_in_binary(sqlstate, b4);
  expect("SET DATA to a BINARY(4)", sqlstate, "22005");
  set_in_varbinary(sqlstate, &in);
  expect("SET DATA", sqlstate, "00000");
  set_in_count(sqlstate);
  expect("SET COUNT", sqlstate, "00000");
  execute_s(sqlstate);
  expect("EXECUTE", sqlstate, "00000");

  memset(b, 9, sizeof(b));
  get_out_binary(sqlstate, b);
  expect("GET DATA of BINARY(3)", sqlstate, "00000");
  check_octets("DATA of BINARY(3)", b, "\x0a\x00\x00", 3);
  memset(&out, 9, sizeof(out));
  get_out_varbinary(sqlstate, &out, &returned);
  expect("GET DATA of VARBINARY(5)", sqlstate, "00000");
  check("length of DATA", (long)out.data_length, 2);
  check_octets("DATA of VARBINARY(5)", out.data_data, "\x00\xff", 2);
  check("RETURNED_LENGTH", returned, 2);
  get_out_char(sqlstate, c);
  expect("GET DATA of BINARY(3) into CHAR(3)", sqlstate, "22005");

  /* A value that's longer than LENGTH is cut, with a warning. */
  length = 1;
  set_out_varbinary(sqlstate, &length);
  execute_s(sqlstate);
  expect("EXECUTE into VARBINARY(1)", sqlstate, "01004");
  get_out_varbinary(sqlstate, &out, &returned);
  check("length of cut DATA", (long)out.data_length, 1);
  check("RETURNED_LENGTH of cut DATA", returned, 1);

  /* A LENGTH of 0 isn't valid. */
  length = 0;
  set_in_length(sqlstate, &length);
  execute_s(sqlstate);
  expect("EXECUTE with LENGTH 0", sqlstate, "07001");
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
  descriptors();

  if (failures > 0) {
    return 1;
  }
  printf("OK\n");
  return 0;
}
