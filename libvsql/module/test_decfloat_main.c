/*
 * test_decfloat_main.c tests DECFLOAT in SQL descriptor areas: its TYPE is
 * DECFLOAT (26), and its PRECISION is the precision in decimal digits, which
 * is 16 or 34.
 *
 * ISO/IEC 9075-2:2023, 20.1, Description of SQL descriptor areas, Syntax
 * Rules, 6.h ISO/IEC 9075-2:2023, 20.5, <set descriptor statement>, General
 * Rules, 4.c.iii.8 ISO/IEC 9075-2:2023, 20.10, <describe statement>, General
 * Rules, 7.d.v
 */

#include <stdio.h>
#include <string.h>

#include "test_decfloat.h"

/* The values of TYPE. */
#define CHARACTER_VARYING 12
#define DECFLOAT 26

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

/* trimmed removes the spaces that pad a CHARACTER VARYING host parameter. */
static char *trimmed(char *s) {
  size_t n;

  for (n = strlen(s); n > 0 && s[n - 1] == ' '; n--) {
    s[n - 1] = '\0';
  }

  return s;
}

static void prepare(const char *sql) {
  char sqlstate[6], buffer[(200 + 1) * 4];

  strcpy(buffer, sql);
  prepare_s(sqlstate, buffer);
  expect(sql, sqlstate, "00000");
}

int main(void) {
  char sqlstate[6], data[(50 + 1) * 4];
  long n, type, precision, scale;
  double d;

  allocate_out(sqlstate);
  expect("ALLOCATE out_d", sqlstate, "00000");
  allocate_in(sqlstate);
  expect("ALLOCATE in_d", sqlstate, "00000");

  /* DESCRIBE sets the PRECISION of a DECFLOAT to its precision, and its SCALE
   * isn't used (it's 0). */
  prepare("SELECT CAST(1.5 AS DECFLOAT(16)), CAST(2 AS DECFLOAT), "
          "CAST(? AS DECFLOAT(16)) FROM (VALUES 1) AS t (x)");
  describe_output(sqlstate);
  expect("DESCRIBE OUTPUT", sqlstate, "00000");
  n = 1;
  get_out(sqlstate, &n, &type, &precision, &scale);
  expect("GET DESCRIPTOR VALUE 1", sqlstate, "00000");
  check("TYPE of DECFLOAT(16)", type, DECFLOAT);
  check("PRECISION of DECFLOAT(16)", precision, 16);
  check("SCALE of DECFLOAT(16)", scale, 0);
  n = 2;
  get_out(sqlstate, &n, &type, &precision, &scale);
  check("TYPE of DECFLOAT", type, DECFLOAT);
  check("PRECISION of DECFLOAT", precision, 34);

  /* A dynamic parameter can be a DECFLOAT too. */
  describe_input(sqlstate);
  expect("DESCRIBE INPUT", sqlstate, "00000");
  get_in(sqlstate, &type, &precision);
  check("TYPE of the parameter", type, DECFLOAT);
  check("PRECISION of the parameter", precision, 16);

  /* Setting TYPE to DECFLOAT sets PRECISION to the default (34). */
  type = CHARACTER_VARYING;
  set_in_type(sqlstate, &type);
  type = DECFLOAT;
  set_in_type(sqlstate, &type);
  expect("SET TYPE", sqlstate, "00000");
  get_in(sqlstate, &type, &precision);
  check("TYPE after SET", type, DECFLOAT);
  check("PRECISION after SET", precision, 34);

  /* DATA of a DECFLOAT is a character string, which is cast to the DECFLOAT. A
   * DECFLOAT is only valid with a PRECISION of 16 or 34. */
  prepare("SELECT CAST(? AS DECFLOAT) + 1 FROM (VALUES 1) AS t (x)");
  strcpy(data, "1.25");
  set_in_data(sqlstate, data);
  expect("SET DATA", sqlstate, "00000");
  set_in_count(sqlstate);
  describe_output(sqlstate);
  execute_s(sqlstate);
  expect("EXECUTE", sqlstate, "00000");
  n = 1;
  get_out(sqlstate, &n, &type, &precision, &scale);
  check("TYPE of the result", type, DECFLOAT);
  check("PRECISION of the result", precision, 34);
  get_out_data(sqlstate, data);
  expect("GET DATA", sqlstate, "00000");
  if (strcmp(trimmed(data), "2.25") != 0) {
    fprintf(stderr, "DATA is '%s', expected '2.25'\n", data);
    failures++;
  }

  /* A DOUBLE PRECISION target doesn't match a DECFLOAT. */
  get_out_double(sqlstate, &d);
  expect("GET DATA as DOUBLE PRECISION", sqlstate, "22005");

  precision = 20;
  set_in_precision(sqlstate, &precision);
  strcpy(data, "1.25");
  set_in_data(sqlstate, data);
  execute_s(sqlstate);
  expect("EXECUTE with PRECISION 20", sqlstate, "07001");
  precision = 16;
  set_in_precision(sqlstate, &precision);
  set_in_data(sqlstate, data);
  execute_s(sqlstate);
  expect("EXECUTE with PRECISION 16", sqlstate, "00000");

  if (failures > 0) {
    fprintf(stderr, "%d failures\n", failures);
    return 1;
  }
  printf("OK\n");

  return 0;
}
