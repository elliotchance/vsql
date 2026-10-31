/* section diagnostics_text */
/*
 * The class (or subclass) of an SQLSTATE that starts with 0 to 4 or A to H is
 * defined by the standard, and any other is defined by vsql.
 *
 * ISO/IEC 9075-2:2016(E), 23.1, <get diagnostics statement>, General Rules, 4.b and 4.c
 */
static const char *vsql_m_origin(char c) {
  return strchr("01234ABCDEFGH", c) != NULL ? "ISO 9075" : "vsql";
}

/*
 * vsql_m_item_text is the value of a character string item in the first
 * diagnostics area. n is the condition number, or 0 (zero) for a statement
 * information item. The MESSAGE_TEXT is the message of the condition, and the
 * CONNECTION_NAME and SERVER_NAME are of the SQL-connection that raised it.
 * The constraint is only identified for an integrity constraint violation.
 *
 * ISO/IEC 9075-2:2016(E), 23.1, <get diagnostics statement>, General Rules, 4.d, 4.f, 4.f.i, 4.m and 4.p
 */
static const char *vsql_m_item_text(int item, long long n) {
  const char *s = NULL;

  switch (item) {
  case SQL_DIAG_MORE:
    /* All of the conditions are kept, even though a condition can be dropped
     * by DIAGNOSTICS SIZE (#798).
     *
     * ISO/IEC 9075-2:2016(E), 23.1, <get diagnostics statement>, General Rules, 2.b
     */
    return "N";
  case VSQL_M_COMMAND_FUNCTION:
    return vsql_m_da.command_function;
  case VSQL_M_DYNAMIC_FUNCTION:
    return vsql_m_da.dynamic_function;
  case SQL_DIAG_SQLSTATE:
    return vsql_m_da.conditions[n - 1].sqlstate;
  case SQL_DIAG_MESSAGE_TEXT:
    s = vsql_m_da.conditions[n - 1].message;
    break;
  case SQL_DIAG_CLASS_ORIGIN:
    return vsql_m_origin(vsql_m_da.conditions[n - 1].sqlstate[0]);
  case SQL_DIAG_SUBCLASS_ORIGIN:
    return vsql_m_origin(vsql_m_da.conditions[n - 1].sqlstate[2]);
  case SQL_DIAG_CONSTRAINT_CATALOG:
    s = vsql_m_da.conditions[n - 1].constraint_catalog;
    break;
  case SQL_DIAG_CONSTRAINT_SCHEMA:
    s = vsql_m_da.conditions[n - 1].constraint_schema;
    break;
  case SQL_DIAG_CONSTRAINT_NAME:
    s = vsql_m_da.conditions[n - 1].constraint_name;
    break;
  case SQL_DIAG_CONNECTION_NAME:
    return vsql_m_da.connection_name;
  case SQL_DIAG_SERVER_NAME:
    s = vsql_m_da.server_name;
    break;
  }

  return s == NULL ? "" : s;
}

/* section diagnostics_number */
/*
 * vsql_m_item_number is the value of an exact numeric item, like
 * vsql_m_item_text. NUMBER is the number of conditions of the last statement
 * that isn't GET DIAGNOSTICS, and TRANSACTION_ACTIVE is 1 if the current
 * SQL-connection has an active SQL-transaction.
 *
 * ISO/IEC 9075-2:2016(E), 23.1, <get diagnostics statement>, General Rules, 2.a, 2.j, 4.n and 4.o
 */
static long long vsql_m_item_number(int item, long long n) {
  const char *s;
  long long length = 0;

  switch (item) {
  case SQL_DIAG_NUMBER:
    return vsql_m_da.number;
  case VSQL_M_COMMAND_FUNCTION_CODE:
    return vsql_m_da.command_function_code;
  case VSQL_M_DYNAMIC_FUNCTION_CODE:
    return vsql_m_da.dynamic_function_code;
  case SQL_DIAG_ROW_COUNT:
    return vsql_m_da.row_count;
  case SQL_DIAG_TRANSACTIONS_COMMITTED:
    return vsql_m_da.transactions_committed;
  case SQL_DIAG_TRANSACTIONS_ROLLED_BACK:
    return vsql_m_da.transactions_rolled_back;
  case SQL_DIAG_TRANSACTION_ACTIVE:
    return vsql_m_current != NULL && vsql_m_current->active;
  }

  s = vsql_m_da.conditions[n - 1].message;
  if (s == NULL) {
    return 0;
  }
  if (item == SQL_DIAG_MESSAGE_OCTET_LENGTH) {
    return (long long)strlen(s);
  }

  /* The MESSAGE_LENGTH is in characters, so the continuation bytes of UTF-8
   * aren't counted. */
  for (; *s != '\0'; s++) {
    if ((*s & 0xC0) != 0x80) {
      length++;
    }
  }

  return length;
}
