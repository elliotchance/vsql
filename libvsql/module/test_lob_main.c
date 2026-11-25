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
 *
 * In an SQL descriptor area, a CLOB is TYPE 40 and a BLOB is TYPE 30. The
 * LENGTH of a CLOB is in characters, and of a BLOB is in octets.
 *
 * ISO/IEC 9075-2:2023, 20.1, Description of SQL descriptor areas, Syntax
 * Rules, 6.a, 6.c, 7.b and 7.e
 * ISO/IEC 9075-2:2023, 20.5, <set descriptor statement>, General Rules,
 * 4.c.iii.1 and 4.c.iii.3
 * ISO/IEC 9075-2:2023, 20.10, <describe statement>, General Rules, 7.d.i and
 * 7.d.ii
 */

#include <stdio.h>
#include <string.h>

#include "test_lob.h"

/* The values of TYPE. */
#define CLOB 40
#define BLOB 30

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
  char sqlstate[6];
  struct {
    long data_reserved;
    unsigned long data_length;
    char data_data[5 * 4];
  } out_c;
  struct {
    long data_reserved;
    unsigned long data_length;
    char data_data[1 * 4];
  } out_c1;
  struct {
    long data_reserved;
    unsigned long data_length;
    char data_data[6];
  } out_b;
  struct {
    long data_reserved;
    unsigned long data_length;
    char data_data[4 * 4];
  } in_c;
  struct {
    long data_reserved;
    unsigned long data_length;
    char data_data[4];
  } in_b;
  long n, type, length, octet_length, returned;

  allocate_out(sqlstate);
  expect("ALLOCATE out_d", sqlstate, "00000");
  allocate_in(sqlstate);
  expect("ALLOCATE in_d", sqlstate, "00000");

  /* DESCRIBE sets the LENGTH of a CLOB in characters (and its OCTET_LENGTH in
   * octets), and of a BLOB in octets. */
  prepare("SELECT CAST(? AS CLOB(5)), CAST(? AS BLOB(6)) "
          "FROM (VALUES 1) AS t (x)");
  describe_output(sqlstate);
  expect("DESCRIBE OUTPUT", sqlstate, "00000");
  n = 1;
  get_out(sqlstate, &n, &type, &length, &octet_length);
  check("TYPE of CLOB(5)", type, CLOB);
  check("LENGTH of CLOB(5)", length, 5);
  check("OCTET_LENGTH of CLOB(5)", octet_length, 20);
  n = 2;
  get_out(sqlstate, &n, &type, &length, &octet_length);
  check("TYPE of BLOB(6)", type, BLOB);
  check("LENGTH of BLOB(6)", length, 6);
  check("OCTET_LENGTH of BLOB(6)", octet_length, 6);
  describe_input(sqlstate);
  expect("DESCRIBE INPUT", sqlstate, "00000");
  n = 1;
  get_in(sqlstate, &n, &type, &length);
  check("TYPE of ?1", type, CLOB);
  check("LENGTH of ?1", length, 5);
  n = 2;
  get_in(sqlstate, &n, &type, &length);
  check("TYPE of ?2", type, BLOB);

  /* Setting TYPE sets LENGTH to 1. */
  n = 1;
  type = CLOB;
  set_in_type(sqlstate, &n, &type);
  expect("SET TYPE CLOB", sqlstate, "00000");
  get_in(sqlstate, &n, &type, &length);
  check("LENGTH after TYPE CLOB", length, 1);
  n = 2;
  type = BLOB;
  set_in_type(sqlstate, &n, &type);
  expect("SET TYPE BLOB", sqlstate, "00000");
  get_in(sqlstate, &n, &type, &length);
  check("LENGTH after TYPE BLOB", length, 1);

  /* DATA must match the type: a CLOB(4) or BLOB(4) matches LENGTH 4. */
  n = 1;
  length = 4;
  set_in_length(sqlstate, &n, &length);
  n = 2;
  set_in_length(sqlstate, &n, &length);
  in_c.data_length = 3;
  memcpy(in_c.data_data, "h\xc3\xa9yz", 5);
  set_in_clob(sqlstate, &in_c);
  expect("SET DATA to a CLOB(4)", sqlstate, "00000");
  in_b.data_length = 2;
  memcpy(in_b.data_data, "\x00\xff", 2);
  set_in_varbinary(sqlstate, &in_b);
  expect("SET DATA to a VARBINARY(4)", sqlstate, "22005");
  set_in_blob(sqlstate, &in_b);
  expect("SET DATA to a BLOB(4)", sqlstate, "00000");
  set_in_count(sqlstate);
  expect("SET COUNT", sqlstate, "00000");
  execute_s(sqlstate);
  expect("EXECUTE", sqlstate, "00000");

  memset(&out_c, 9, sizeof(out_c));
  get_out_clob(sqlstate, &out_c, &returned);
  expect("GET DATA of CLOB(5)", sqlstate, "00000");
  check("length of CLOB DATA", (long)out_c.data_length, 3);
  check_octets("CLOB DATA", out_c.data_data, "h\xc3\xa9y", 4);
  check("RETURNED_LENGTH of CLOB", returned, 3);
  memset(&out_b, 9, sizeof(out_b));
  get_out_blob(sqlstate, &out_b, &returned);
  expect("GET DATA of BLOB(6)", sqlstate, "00000");
  check("length of BLOB DATA", (long)out_b.data_length, 2);
  check_octets("BLOB DATA", out_b.data_data, "\x00\xff", 2);
  check("RETURNED_LENGTH of BLOB", returned, 2);

  /* The target must be at least as long as LENGTH. */
  get_out_short_clob(sqlstate, &out_c1);
  expect("GET DATA of CLOB(5) into CLOB(1)", sqlstate, "22005");

  /* A LENGTH of 0 isn't valid. */
  n = 1;
  length = 0;
  set_in_length(sqlstate, &n, &length);
  execute_s(sqlstate);
  expect("EXECUTE with LENGTH 0", sqlstate, "07001");
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
  descriptors();

  if (failures > 0) {
    return 1;
  }
  printf("OK\n");
  return 0;
}
