/*
 * test_interval_main.c tests intervals in SQL descriptor areas. An interval
 * is TYPE 10 (INTERVAL), with its DATETIME_INTERVAL_CODE (Table 32), its
 * leading field precision in DATETIME_INTERVAL_PRECISION, its fractional
 * seconds precision in PRECISION and its length in positions in LENGTH. An
 * interval has no C data type, so its DATA is a character string.
 *
 * ISO/IEC 9075-2:2023, 20.1, Description of SQL descriptor areas, Syntax
 * Rules, 6.l
 * ISO/IEC 9075-2:2023, 20.1, Description of SQL descriptor areas, General
 * Rules, 3
 * ISO/IEC 9075-2:2023, 20.5, <set descriptor statement>, General Rules,
 * 4.c.iii.6 and 4.d.ii
 * ISO/IEC 9075-2:2023, 20.10, <describe statement>, General Rules, 7.d.vii
 */

#include <stdio.h>
#include <string.h>

#include "test_interval.h"

/* The values of TYPE and DATETIME_INTERVAL_CODE. */
#define INTERVAL 10
#define YEAR_TO_MONTH 7
#define DAY_TO_SECOND 10
#define HOUR_TO_SECOND 12
#define MONTH 2

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

/* check_string checks a string that's padded with spaces. */
static void check_string(const char *what, const char *got,
                         const char *expected) {
  size_t n = strlen(expected);

  if (strncmp(got, expected, n) != 0 || got[n + strspn(got + n, " ")] != '\0') {
    fprintf(stderr, "%s: \"%s\", expected \"%s\"\n", what, got, expected);
    failures++;
  }
}

static void prepare(const char *sql) {
  char sqlstate[6], buffer[(200 + 1) * 4];

  strcpy(buffer, sql);
  prepare_s(sqlstate, buffer);
  expect(sql, sqlstate, "00000");
}

int main(void) {
  char sqlstate[6], data[(60 + 1) * 4];
  long n, type, code, leading, precision, length;

  allocate_out(sqlstate);
  expect("ALLOCATE out_d", sqlstate, "00000");
  allocate_in(sqlstate);
  expect("ALLOCATE in_d", sqlstate, "00000");

  /* DESCRIBE sets the code, the precisions and the length in positions. */
  prepare("SELECT CAST(? AS INTERVAL DAY(3) TO SECOND(2)), "
          "INTERVAL '1-2' YEAR TO MONTH FROM (VALUES 1) AS t (x)");
  describe_output(sqlstate);
  expect("DESCRIBE OUTPUT", sqlstate, "00000");
  n = 1;
  get_out(sqlstate, &n, &type, &code, &leading, &precision, &length);
  check("TYPE of DAY TO SECOND", type, INTERVAL);
  check("DATETIME_INTERVAL_CODE of DAY TO SECOND", code, DAY_TO_SECOND);
  check("DATETIME_INTERVAL_PRECISION of DAY TO SECOND", leading, 3);
  check("PRECISION of DAY TO SECOND", precision, 2);
  check("LENGTH of DAY TO SECOND", length, 16);
  n = 2;
  get_out(sqlstate, &n, &type, &code, &leading, &precision, &length);
  check("TYPE of YEAR TO MONTH", type, INTERVAL);
  check("DATETIME_INTERVAL_CODE of YEAR TO MONTH", code, YEAR_TO_MONTH);
  check("DATETIME_INTERVAL_PRECISION of YEAR TO MONTH", leading, 2);
  check("LENGTH of YEAR TO MONTH", length, 6);
  describe_input(sqlstate);
  expect("DESCRIBE INPUT", sqlstate, "00000");
  get_in(sqlstate, &type, &code, &leading, &precision);
  check("TYPE of ?", type, INTERVAL);
  check("DATETIME_INTERVAL_CODE of ?", code, DAY_TO_SECOND);
  check("DATETIME_INTERVAL_PRECISION of ?", leading, 3);
  check("PRECISION of ?", precision, 2);

  /* Setting TYPE sets the DATETIME_INTERVAL_PRECISION to 2, and so does
   * setting the DATETIME_INTERVAL_CODE, which also sets the PRECISION to 6 (or
   * 0 without seconds). */
  type = INTERVAL;
  set_in_type(sqlstate, &type);
  expect("SET TYPE", sqlstate, "00000");
  get_in(sqlstate, &type, &code, &leading, &precision);
  check("DATETIME_INTERVAL_PRECISION after TYPE", leading, 2);
  leading = 5;
  set_in_leading(sqlstate, &leading);
  code = HOUR_TO_SECOND;
  set_in_code(sqlstate, &code);
  expect("SET DATETIME_INTERVAL_CODE", sqlstate, "00000");
  get_in(sqlstate, &type, &code, &leading, &precision);
  check("DATETIME_INTERVAL_PRECISION after CODE", leading, 2);
  check("PRECISION after HOUR TO SECOND", precision, 6);
  code = MONTH;
  set_in_code(sqlstate, &code);
  get_in(sqlstate, &type, &code, &leading, &precision);
  check("PRECISION after MONTH", precision, 0);
  code = 14;
  set_in_code(sqlstate, &code);
  expect("SET DATETIME_INTERVAL_CODE 14", sqlstate, "0700F");

  /* DATA is a character string, which is cast to the interval. */
  code = DAY_TO_SECOND;
  set_in_code(sqlstate, &code);
  leading = 3;
  set_in_leading(sqlstate, &leading);
  precision = 2;
  set_in_precision(sqlstate, &precision);
  strcpy(data, "3 04:05:06.7");
  set_in_data(sqlstate, data);
  expect("SET DATA", sqlstate, "00000");
  set_in_count(sqlstate);
  execute_s(sqlstate);
  expect("EXECUTE", sqlstate, "00000");
  n = 1;
  get_out_data(sqlstate, &n, data);
  expect("GET DATA 1", sqlstate, "00000");
  check_string("DATA 1", data, "INTERVAL '3 04:05:06.70' DAY(3) TO SECOND(2)");
  n = 2;
  get_out_data(sqlstate, &n, data);
  check_string("DATA 2", data, "INTERVAL '1-02' YEAR(2) TO MONTH");

  /* A value with a sign. */
  strcpy(data, "-3 04:05:06.7");
  set_in_data(sqlstate, data);
  execute_s(sqlstate);
  expect("EXECUTE with a sign", sqlstate, "00000");
  n = 1;
  get_out_data(sqlstate, &n, data);
  check_string("DATA with a sign", data,
               "INTERVAL '-3 04:05:06.70' DAY(3) TO SECOND(2)");

  /* The leading field precision must be 1 to 8. */
  leading = 9;
  set_in_leading(sqlstate, &leading);
  execute_s(sqlstate);
  expect("EXECUTE with DATETIME_INTERVAL_PRECISION 9", sqlstate, "07001");

  if (failures > 0) {
    return 1;
  }
  printf("OK\n");
  return 0;
}
