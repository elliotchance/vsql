/*
 * The tests of the <updatability clause> of a cursor (test_updatability.mod).
 * See test_main.c.
 *
 * ISO/IEC 9075-2:2023(E), 14.3, <cursor specification>, Syntax Rules, 6 and 9
 */

#include <stdio.h>
#include <string.h>

#include "test_updatability.h"

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

int main(void) {
  long x = 0, y = 0;

  EXPECT(create_upd(sqlstate), "00000");
  EXPECT(insert_upd(sqlstate), "00000");
  EXPECT(commit_work(sqlstate), "00000");

  /* FOR READ ONLY can't be changed through the cursor, even though the query
   * is simply updatable. */
  EXPECT(open_read_only(sqlstate), "00000");
  EXPECT(fetch_read_only(sqlstate, &x, &y), "00000");
  EXPECT(delete_read_only(sqlstate), "34000");
  EXPECT(update_read_only(sqlstate), "34000");

  /* FOR UPDATE OF y can only set y, and makes an ordered query updatable. */
  EXPECT(open_update_y(sqlstate), "00000");
  EXPECT(fetch_update_y(sqlstate, &x, &y), "00000");
  CHECK(x == 1 && y == 10);
  EXPECT(set_x(sqlstate), "42601");
  y = 11;
  EXPECT(set_y(sqlstate, &y), "00000");
  EXPECT(sum_y(sqlstate, &y), "00000");
  CHECK(y == 31);

  /* A closed cursor is an invalid cursor state. */
  EXPECT(close_update_y(sqlstate), "00000");
  EXPECT(set_y(sqlstate, &y), "24000");
  EXPECT(commit_work(sqlstate), "00000");

  if (failures > 0) {
    return 1;
  }
  printf("OK\n");

  return 0;
}
