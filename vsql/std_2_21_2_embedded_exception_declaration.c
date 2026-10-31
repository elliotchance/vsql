/* section violated */
/*
 * vsql_m_violated is 1 if a condition in the first diagnostics area is the
 * violation of the constraint. catalog is NULL for any catalog. When more than
 * one constraint was violated, the first WHENEVER CONSTRAINT (that applies) is
 * chosen.
 *
 * ISO/IEC 9075-2:2016(E), 21.2, <embedded exception declaration>, General Rules, 1.c.i to 1.c.iii
 */
static int vsql_m_violated(const char *catalog, const char *schema,
                           const char *name) {
  int i;
  struct vsql_m_condition *c;

  for (i = 0; i < vsql_m_da.number; i++) {
    c = &vsql_m_da.conditions[i];
    if (c->constraint_name != NULL && strcmp(c->constraint_name, name) == 0 &&
        c->constraint_schema != NULL &&
        strcmp(c->constraint_schema, schema) == 0 &&
        (catalog == NULL || (c->constraint_catalog != NULL &&
                             strcmp(c->constraint_catalog, catalog) == 0))) {
      return 1;
    }
  }

  return 0;
}
