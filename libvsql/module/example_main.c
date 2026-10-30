/*
 * example_main.c calls the procedures of example.mod. From the root of the
 * repository, run "make module-example".
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "example.h"

/* check prints the message of the first condition if the procedure failed. */
static void check(const char *procedure, const char *sqlstate) {
  char state[6], message[201] = "";

  if (strcmp(sqlstate, "00000") != 0) {
    error_message(state, message);
    fprintf(stderr, "%s: %s %s\n", procedure, sqlstate, message);
    exit(1);
  }
}

int main(void) {
  char sqlstate[6];
  char file[101] = "example.vsql";
  char name[21];
  long id;
  double price;
  short price_indicator;
  double factor = 0.9;
  long rows;

  remove("example.vsql");
  open_database(sqlstate, file);
  check("open_database", sqlstate);
  create_items(sqlstate);
  check("create_items", sqlstate);

  id = 1;
  strcpy(name, "Bagel");
  price = 2.5;
  price_indicator = 0;
  add_item(sqlstate, &id, name, &price, &price_indicator);
  check("add_item", sqlstate);

  /* A negative indicator inserts a NULL. */
  id = 2;
  strcpy(name, "Coffee");
  price_indicator = -1;
  add_item(sqlstate, &id, name, &price, &price_indicator);
  check("add_item", sqlstate);

  change_prices(sqlstate, &factor);
  check("change_prices", sqlstate);
  rows_changed(sqlstate, &rows);
  check("rows_changed", sqlstate);
  printf("Changed %ld prices\n", rows);

  /* A NULL value has a negative indicator. */
  for (id = 1; id <= 2; id++) {
    get_item(sqlstate, &id, name, &price, &price_indicator);
    check("get_item", sqlstate);
    if (price_indicator < 0) {
      printf("%s has no price\n", name);
    } else {
      printf("%s costs %.2f\n", name, price);
    }
  }

  /* There's no item 3 (02000 is no data). */
  get_item(sqlstate, &id, name, &price, &price_indicator);
  if (strcmp(sqlstate, "02000") != 0) {
    check("get_item", sqlstate);
  }

  commit_work(sqlstate);
  check("commit_work", sqlstate);
  close_database(sqlstate);
  check("close_database", sqlstate);

  printf("OK\n");
  return 0;
}
