/*
 * test_returned_length_main.c tests RETURNED_LENGTH and RETURNED_OCTET_LENGTH
 * after an <output using clause> sets an item descriptor area.
 *
 * ISO/IEC 9075-2:2016(E), 20.12, <output using clause>, General Rules, 5.e.i.2.B.III
 */

#include <stdio.h>
#include <string.h>

#include "test_returned_length.h"

/* The values of TYPE. */
#define CHARACTER 1
#define INTEGER 4
#define CHARACTER_VARYING 12

static int failures = 0;

/*
 * run prepares and executes a statement into the item, and checks the SQLSTATE,
 * lengths and INDICATOR. If describe is 0 the SQL descriptor area isn't
 * described or set again, so the item keeps its other values.
 */
static void run(const char *statement, int describe, long type, long length,
                const char *state, long n, long o, long indicator) {
  char sqlstate[6], buffer[(1000 + 1) * 4];
  long got_n = -1, got_o = -1, got_indicator = 0;

  strcpy(buffer, statement);
  prepare_s(sqlstate, buffer);
  if (describe) {
    describe_s(sqlstate);
    set_type(sqlstate, &type, &length);
  }
  execute_s(sqlstate);
  if (strcmp(sqlstate, state) != 0) {
    fprintf(stderr, "%s: SQLSTATE %s, expected %s\n", statement, sqlstate,
            state);
    failures++;
  }
  get_lengths(sqlstate, &got_n, &got_o, &got_indicator);
  if (got_n != n || got_o != o || got_indicator != indicator) {
    fprintf(stderr, "%s: %ld, %ld, %ld, expected %ld, %ld, %ld\n", statement,
            got_n, got_o, got_indicator, n, o, indicator);
    failures++;
  }
}

int main(void) {
  char sqlstate[6], statement[(1000 + 1) * 4], data[(1 + 1) * 4];
  long integer = 0;
  int i;

  allocate_d(sqlstate);

  /* III.1: TYPE is CHARACTER VARYING, so it's the length of TV. */
  run("SELECT CAST('a\xC3\xA9' AS VARCHAR(5)) FROM (VALUES 1) AS t(x)", 1,
      CHARACTER_VARYING, 5, "00000", 2, 3, 0);
  run("SELECT CAST('ab' AS CHAR(3)) FROM (VALUES 1) AS t(x)", 1,
      CHARACTER_VARYING, 5, "00000", 3, 3, 0);

  /* III.2: The column is CHARACTER VARYING, so it's the length of SV. */
  run("SELECT CAST('a\xC3\xA9' AS VARCHAR(5)) FROM (VALUES 1) AS t(x)", 1,
      CHARACTER, 5, "00000", 2, 3, 0);
  run("SELECT CAST('12' AS VARCHAR(5)) FROM (VALUES 1) AS t(x)", 1, INTEGER, 0,
      "00000", 2, 2, 0);
  get_integer(sqlstate, &integer);
  if (integer != 12) {
    fprintf(stderr, "DATA is %ld, expected 12\n", integer);
    failures++;
  }

  /* SV doesn't fit, and DATA is still the start of it. */
  run("SELECT CAST('abcdefghij' AS VARCHAR(10)) FROM (VALUES 1) AS t(x)", 1,
      CHARACTER, 1, "01004", 10, 10, 0);
  get_char(sqlstate, data);
  if (strcmp(data, "a") != 0) {
    fprintf(stderr, "DATA is '%s', expected 'a'\n", data);
    failures++;
  }

  /* SV is read in pieces, and a piece can end inside of a character. */
  strcpy(statement, "SELECT CAST('");
  strcat(statement, "a");
  for (i = 0; i < 300; i++) {
    strcat(statement, "\xC3\xA9");
  }
  strcat(statement, "' AS VARCHAR(301)) FROM (VALUES 1) AS t(x)");
  run(statement, 1, CHARACTER, 1, "01004", 301, 601, 0);

  /* Otherwise, they're unchanged: Neither is a CHARACTER VARYING. */
  run("SELECT CAST('ab' AS CHAR(3)) FROM (VALUES 1) AS t(x)", 1, CHARACTER, 5,
      "00000", 0, 0, 0);
  run("SELECT 12 FROM (VALUES 1) AS t(x)", 1, INTEGER, 0, "00000", 0, 0, 0);

  /* A null value only sets INDICATOR. */
  run("SELECT CAST('ab' AS VARCHAR(5)) FROM (VALUES 1) AS t(x)", 1, CHARACTER,
      5, "00000", 2, 2, 0);
  run("SELECT CAST(NULL AS VARCHAR(5)) FROM (VALUES 1) AS t(x)", 0, 0, 0,
      "00000", 2, 2, -1);

  if (failures > 0) {
    fprintf(stderr, "%d failures\n", failures);
    return 1;
  }
  printf("OK\n");

  return 0;
}
