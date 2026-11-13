/* The tests of GET DIAGNOSTICS MORE (test_more.mod). See test_main.c. */

#include <stdio.h>
#include <string.h>

#include "test_more.h"

static int failures = 0;

#define CHECK(condition)                                                       \
  do {                                                                         \
    if (!(condition)) {                                                        \
      fprintf(stderr, "%s:%d: failed: %s\n", __FILE__, __LINE__, #condition);  \
      failures++;                                                              \
    }                                                                          \
  } while (0)

#define EXPECT(call, expected)                                                 \
  do {                                                                         \
    call;                                                                      \
    if (strcmp(sqlstate, expected) != 0) {                                     \
      fprintf(stderr, "%s:%d: %s: expected %s, got %s\n", __FILE__, __LINE__,  \
              #call, expected, sqlstate);                                      \
      failures++;                                                              \
    }                                                                          \
  } while (0)

static char sqlstate[6];
static char a[8], b[8];

/* Checks the NUMBER and MORE of the last statement. */
static void check_more(int line, long expected_number, const char *expected) {
  char more[8];
  long number = 0, active = 0;

  get_more(sqlstate, &number, more, &active);
  if (number != expected_number || strcmp(more, expected) != 0) {
    fprintf(stderr, "%s:%d: expected %ld, %s, got %ld, %s\n", __FILE__, line,
            expected_number, expected, number, more);
    failures++;
  }
}

int main(void) {
  char more[8];
  long number = 0, active = 0, a_ind = 0, b_ind = 0;

  /* It doesn't initiate an SQL-transaction, so it can be the first statement.
   */
  EXPECT(set_size_1(sqlstate), "00000");
  EXPECT(get_more(sqlstate, &number, more, &active), "00000");
  CHECK(number == 0 && strcmp(more, "N") == 0 && active == 0);

  /* 23.1 GR 2.b: One of the conditions is dropped. */
  EXPECT(select_two_warnings(sqlstate, a, b), "01004");
  check_more(__LINE__, 1, "Y");
  CHECK(strcmp(a, "a") == 0 && strcmp(b, "x") == 0);
  EXPECT(get_more(sqlstate, &number, more, &active), "00000");
  CHECK(active == 1);

  /* Every condition of the next statement is kept. */
  EXPECT(select_ok(sqlstate, a), "00000");
  check_more(__LINE__, 0, "N");

  /* A statement with a dropped condition, executed dynamically. */
  EXPECT(prepare_two_warnings(sqlstate), "00000");
  EXPECT(execute_two_warnings(sqlstate, a, &a_ind, b, &b_ind), "01004");
  check_more(__LINE__, 1, "Y");
  EXPECT(commit_work(sqlstate), "00000");
  check_more(__LINE__, 0, "N");

  /* The limit was only for that SQL-transaction. */
  EXPECT(select_two_warnings(sqlstate, a, b), "01004");
  check_more(__LINE__, 2, "N");
  EXPECT(select_truncated(sqlstate, a, b), "01004");
  check_more(__LINE__, 2, "N");
  EXPECT(commit_work(sqlstate), "00000");

  /* 17.1 GR 2.b and 4: START TRANSACTION has its own DIAGNOSTICS SIZE. */
  EXPECT(start_size_1(sqlstate), "00000");
  EXPECT(get_more(sqlstate, &number, more, &active), "00000");
  CHECK(active == 1);
  EXPECT(start_plain(sqlstate), "25001");
  EXPECT(select_two_warnings(sqlstate, a, b), "01004");
  check_more(__LINE__, 1, "Y");
  EXPECT(rollback_work(sqlstate), "00000");

  /* 17.1 GR 3: The size must be at least 1. */
  EXPECT(start_size_0(sqlstate), "35000");
  EXPECT(get_more(sqlstate, &number, more, &active), "00000");
  CHECK(active == 0);

  /* 17.2 GR 3: A size over the most conditions is a warning. */
  EXPECT(start_size_200(sqlstate), "01012");
  EXPECT(get_more(sqlstate, &number, more, &active), "00000");
  CHECK(active == 1);
  EXPECT(select_two_warnings(sqlstate, a, b), "01004");
  check_more(__LINE__, 2, "N");
  EXPECT(rollback_work(sqlstate), "00000");

  /* NOTE 710: A SET TRANSACTION doesn't change a START TRANSACTION. */
  EXPECT(set_size_1(sqlstate), "00000");
  EXPECT(start_plain(sqlstate), "00000");
  EXPECT(select_two_warnings(sqlstate, a, b), "01004");
  check_more(__LINE__, 2, "N");
  EXPECT(rollback_work(sqlstate), "00000");

  /* 17.1 GR 2.a: The access mode is passed to SQLStartTran, and READ
   * UNCOMMITTED is READ ONLY (17.3 SR 4). */
  EXPECT(start_read_only(sqlstate), "00000");
  EXPECT(create_table(sqlstate), "25006");
  EXPECT(rollback_work(sqlstate), "00000");
  EXPECT(start_read_uncommitted(sqlstate), "00000");
  EXPECT(create_table(sqlstate), "25006");
  EXPECT(rollback_work(sqlstate), "00000");

  /* 13.4 GR 9: A dynamic SET TRANSACTION doesn't initiate an SQL-transaction
   * either. */
  EXPECT(execute_set_size_1(sqlstate), "00000");
  EXPECT(get_more(sqlstate, &number, more, &active), "00000");
  CHECK(active == 0);
  EXPECT(select_two_warnings(sqlstate, a, b), "01004");
  check_more(__LINE__, 1, "Y");
  EXPECT(rollback_work(sqlstate), "00000");
  EXPECT(prepare_set_size_1(sqlstate), "00000");
  EXPECT(rollback_work(sqlstate), "00000");
  EXPECT(execute_set(sqlstate), "00000");
  EXPECT(get_more(sqlstate, &number, more, &active), "00000");
  CHECK(active == 0);
  EXPECT(select_two_warnings(sqlstate, a, b), "01004");
  check_more(__LINE__, 1, "Y");
  EXPECT(rollback_work(sqlstate), "00000");

  if (failures > 0) {
    return 1;
  }
  printf("OK\n");
  return 0;
}
