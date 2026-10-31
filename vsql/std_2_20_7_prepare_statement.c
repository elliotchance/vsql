/* section prepared */
/*
 * The prepared statements of the module in an SQL-connection, which is the
 * SQL-session.
 *
 * ISO/IEC 9075-2:2016(E), 20.7, <prepare statement>, General Rules, 10
 */
static struct vsql_m_prepared **
vsql_m_find_prepared(struct vsql_m_connection *c, const char *name) {
  struct vsql_m_prepared **p = &c->prepared;

  while (*p != NULL &&
         ((*p)->module != &vsql_m_own || strcmp((*p)->name, name) != 0)) {
    p = &(*p)->next;
  }

  return p;
}

/*
 * vsql_m_deallocate destroys the prepared statement *p. It returns 0 (with the
 * status parameter set) if one of the dynamic cursors that are declared for it
 * is open: invalid cursor state. The attributes of a CLI statement can't be set
 * while its cursor is open, so setting the holdability to the same value finds
 * out if it's open. A closed dynamic cursor has no cursor instance until it's
 * opened again (with the statement that's prepared then).
 *
 * ISO/IEC 9075-2:2016(E), 20.9, <deallocate prepared statement>, General Rules, 2 and 3
 */
static int vsql_m_deallocate(char *sqlstate, struct vsql_m_connection *c,
                             struct vsql_m_prepared **p) {
  SQLHSTMT *cursors = vsql_m_cursors(c);
  struct vsql_m_prepared *next;
  SQLINTEGER holdable;
  int i;

  for (i = 0; cursors != NULL && i < vsql_m_cursor_count; i++) {
    if (cursors[i] != 0 && vsql_m_cursor_statements[i] != NULL &&
        strcmp(vsql_m_cursor_statements[i], (*p)->name) == 0 &&
        !vsql_m_failed(SQLGetStmtAttr(cursors[i], SQL_ATTR_CURSOR_HOLDABLE,
                                      &holdable, 0, NULL)) &&
        vsql_m_failed(SQLSetStmtAttr(cursors[i], SQL_ATTR_CURSOR_HOLDABLE,
                                     &holdable, 0))) {
      vsql_m_status(sqlstate, "24000");
      return 0;
    }
  }

  next = (*p)->next;
  vsql_m_free_prepared(*p);
  *p = next;

  return 1;
}

/* section prepared_statement */
/*
 * vsql_m_prepared_statement is the prepared statement with the name in the
 * current SQL-connection, or NULL (with the status parameter set) if there
 * isn't one: invalid SQL statement name.
 *
 * ISO/IEC 9075-2:2016(E), 20.10, <describe statement>, General Rules, 1
 * ISO/IEC 9075-2:2016(E), 20.13, <execute statement>, General Rules, 1
 * ISO/IEC 9075-2:2016(E), 20.19, <dynamic open statement>, General Rules, 1.a.i
 */
static struct vsql_m_prepared *vsql_m_prepared_statement(char *sqlstate,
                                                         const char *name) {
  struct vsql_m_connection *c = vsql_m_connection(sqlstate);
  struct vsql_m_prepared *p;

  if (c == NULL) {
    return NULL;
  }

  p = *vsql_m_find_prepared(c, name);
  if (p == NULL) {
    vsql_m_status(sqlstate, "26000");
  }

  return p;
}

/* section prepare */
/*
 * vsql_m_prepare is a <prepare statement>. The statement is prepared with
 * SQLPrepare, which checks that it's a <preparable statement> (and that it
 * doesn't have a <simple comment>). START TRANSACTION, COMMIT and ROLLBACK
 * can't be prepared, since the SQL/CLI only does them with SQLStartTran and
 * SQLEndTran.
 *
 * ISO/IEC 9075-2:2016(E), 20.7, <prepare statement>, General Rules, 6.c and 10
 */
static void vsql_m_prepare(char *sqlstate, const char *name, const char *sql) {
  struct vsql_m_connection *c = vsql_m_connection(sqlstate);
  struct vsql_m_prepared **p, *prepared;
  SQLRETURN rc;

  if (c == NULL) {
    return;
  }

  /* A prepared statement with the name is deallocated.
   *
   * ISO/IEC 9075-2:2016(E), 20.7, <prepare statement>, General Rules, 9 */
  p = vsql_m_find_prepared(c, name);
  if (*p != NULL && !vsql_m_deallocate(sqlstate, c, p)) {
    return;
  }

  prepared =
      (struct vsql_m_prepared *)calloc(1, sizeof(struct vsql_m_prepared));
  if (prepared != NULL) {
    vsql_m_copy(&prepared->sql, sql);
  }
  if (prepared == NULL || prepared->sql == NULL) {
    free(prepared);
    vsql_m_status(sqlstate, "HY001");
    return;
  }

  rc = SQLAllocHandle(SQL_HANDLE_STMT, c->dbc, &prepared->stmt);
  if (vsql_m_failed(rc)) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_DBC, c->dbc);
    free(prepared->sql);
    free(prepared);
    return;
  }

  /* The <prepare statement> is transaction-initiating, since the statement
   * is.
   *
   * ISO/IEC 9075-2:2016(E), 4.39.4, SQL-statements and transaction states */
  c->active = 1;
  rc = SQLPrepare(prepared->stmt, (SQLCHAR *)sql, SQL_NTS);
  vsql_m_diag(sqlstate, rc, SQL_HANDLE_STMT, prepared->stmt);
  if (vsql_m_failed(rc)) {
    vsql_m_free_prepared(prepared);
    return;
  }
  SQLGetDiagField(SQL_HANDLE_STMT, prepared->stmt, 0, SQL_DIAG_DYNAMIC_FUNCTION,
                  prepared->dynamic_function,
                  sizeof(prepared->dynamic_function), NULL);
  SQLGetDiagField(SQL_HANDLE_STMT, prepared->stmt, 0,
                  SQL_DIAG_DYNAMIC_FUNCTION_CODE,
                  &prepared->dynamic_function_code, 0, NULL);

  prepared->module = &vsql_m_own;
  prepared->name = name;
  prepared->next = c->prepared;
  c->prepared = prepared;
}

/* section deallocate_prepare */
/* ISO/IEC 9075-2:2016(E), 20.9, <deallocate prepared statement> */
static void vsql_m_deallocate_prepare(char *sqlstate, const char *name) {
  struct vsql_m_connection *c = vsql_m_connection(sqlstate);
  struct vsql_m_prepared **p;

  if (c == NULL) {
    return;
  }
  c->active = 1;

  /* ISO/IEC 9075-2:2016(E), 20.9, <deallocate prepared statement>, General Rules, 1 */
  p = vsql_m_find_prepared(c, name);
  if (*p == NULL) {
    vsql_m_status(sqlstate, "26000");
    return;
  }

  if (vsql_m_deallocate(sqlstate, c, p)) {
    vsql_m_status(sqlstate, "00000");
  }
}

/* section describe */
/*
 * vsql_m_describe_column sets the item descriptor area to the description of
 * a column, from the IRD of the prepared statement. A datetime is the concise
 * data type (such as SQL_TYPE_DATE) in the IRD. LEVEL and KEY_MEMBER are 0
 * (zero) (#801), and a collation that isn't set is the zero-length string.
 *
 * ISO/IEC 9075-2:2016(E), 20.10, <describe statement>, General Rules, 7
 */
static void vsql_m_describe_column(SQLHSTMT stmt, SQLSMALLINT column,
                                   struct vsql_m_item *item) {
  static const int numbers[][2] = {
      {SQL_DESC_TYPE, VSQL_M_TYPE},
      {SQL_DESC_DATETIME_INTERVAL_CODE, VSQL_M_DATETIME_INTERVAL_CODE},
      {SQL_DESC_LENGTH, VSQL_M_LENGTH},
      {SQL_DESC_OCTET_LENGTH, VSQL_M_OCTET_LENGTH},
      {SQL_DESC_PRECISION, VSQL_M_PRECISION},
      {SQL_DESC_SCALE, VSQL_M_SCALE},
      {SQL_DESC_NULLABLE, VSQL_M_NULLABLE},
      {SQL_DESC_UNNAMED, VSQL_M_UNNAMED}};
  static const int strings[][2] = {
      {SQL_DESC_NAME, VSQL_M_NAME},
      {SQL_DESC_CHARACTER_SET_CATALOG, VSQL_M_CHARACTER_SET_CATALOG},
      {SQL_DESC_CHARACTER_SET_SCHEMA, VSQL_M_CHARACTER_SET_SCHEMA},
      {SQL_DESC_CHARACTER_SET_NAME, VSQL_M_CHARACTER_SET_NAME},
      {SQL_DESC_COLLATION_CATALOG, VSQL_M_COLLATION_CATALOG},
      {SQL_DESC_COLLATION_SCHEMA, VSQL_M_COLLATION_SCHEMA},
      {SQL_DESC_COLLATION_NAME, VSQL_M_COLLATION_NAME}};
  SQLINTEGER value;
  char s[129];
  size_t i;

  vsql_m_reset_item(item);
  for (i = 0; i < sizeof(numbers) / sizeof(numbers[0]); i++) {
    value = 0;
    SQLColAttribute(stmt, column, (SQLSMALLINT)numbers[i][0], NULL, 0, NULL,
                    &value);
    item->number[numbers[i][1]] = value;
  }
  for (i = 0; i < sizeof(strings) / sizeof(strings[0]); i++) {
    s[0] = '\0';
    SQLColAttribute(stmt, column, (SQLSMALLINT)strings[i][0], (SQLCHAR *)s,
                    (SQLSMALLINT)sizeof(s), NULL, NULL);
    if (s[0] != '\0') {
      vsql_m_copy(&item->string[strings[i][1]], s);
    }
  }

  if (item->number[VSQL_M_TYPE] >= SQL_TYPE_DATE &&
      item->number[VSQL_M_TYPE] <= SQL_TYPE_TIMESTAMP_WITH_TIMEZONE) {
    item->number[VSQL_M_TYPE] = SQL_DATETIME;
  }
}

/*
 * vsql_m_describe is a <describe output statement>. A statement that isn't a
 * <dynamic select statement> has no output dynamic parameters, so its COUNT is
 * 0 (zero).
 *
 * ISO/IEC 9075-2:2016(E), 20.10, <describe statement>, General Rules, 5.b and 5.c
 */
static void vsql_m_describe(char *sqlstate, const char *statement,
                            const char *name, const void *module) {
  struct vsql_m_prepared *p = vsql_m_prepared_statement(sqlstate, statement);
  struct vsql_m_descriptor *d;
  SQLSMALLINT columns = 0, i;

  if (p == NULL) {
    return;
  }
  d = vsql_m_descriptor(sqlstate, name, module);
  if (d == NULL) {
    return;
  }

  /* ISO/IEC 9075-2:2016(E), 20.10, <describe statement>, General Rules, 6.a to 6.c */
  SQLNumResultCols(p->stmt, &columns);
  d->count = columns;
  d->top_level_count = columns;
  strcpy(d->dynamic_function, p->dynamic_function);
  d->dynamic_function_code = p->dynamic_function_code;

  /* ISO/IEC 9075-2:2016(E), 20.10, <describe statement>, General Rules, 6.e and 6.f */
  if (columns > d->max) {
    vsql_m_status(sqlstate, "01005");
    return;
  }

  for (i = 1; i <= columns; i++) {
    vsql_m_describe_column(p->stmt, i, &d->items[i - 1]);
  }
  vsql_m_status(sqlstate, "00000");
}

/* section input */
/*
 * An <input using clause> is the host parameters (n of them) or an SQL
 * descriptor area. n is -1 when there isn't one.
 *
 * ISO/IEC 9075-2:2016(E), 20.11, <input using clause>
 */
struct vsql_m_input {
  int n;
  struct vsql_m_param *params;
  const char *descriptor;
  const void *module;
};

/* vsql_m_bind_item binds DATA of an item descriptor area to dynamic parameter
 * i, or the null value if INDICATOR is negative. The value isn't cast to the
 * type of the dynamic parameter, since it isn't determined (#649).
 *
 * ISO/IEC 9075-2:2016(E), 20.11, <input using clause>, General Rules, 6.b.i */
static SQLRETURN vsql_m_bind_item(SQLHSTMT stmt, SQLSMALLINT i,
                                  struct vsql_m_item *item) {
  SQLINTEGER *number = item->number, size = 0;
  SQLSMALLINT type = (SQLSMALLINT)number[VSQL_M_TYPE], c;
  size_t buffer;

  c = vsql_m_c_type(item, &buffer);
  if (type == SQL_DATETIME) {
    type = (SQLSMALLINT)(SQL_TYPE_DATE - SQL_CODE_DATE +
                         number[VSQL_M_DATETIME_INTERVAL_CODE]);
  }
  if (type == SQL_CHAR || type == SQL_VARCHAR) {
    size = number[VSQL_M_LENGTH];
  } else if (type != SQL_BOOLEAN) {
    size = number[VSQL_M_PRECISION];
  }
  item->length = number[VSQL_M_INDICATOR] < 0 ? SQL_NULL_DATA
                 : c == SQL_CHAR              ? SQL_NTS
                                              : 0;

  return SQLBindParameter(stmt, i, SQL_PARAM_MODE_IN, c, type, size,
                          (SQLSMALLINT)number[VSQL_M_SCALE],
                          item->data == NULL ? &item->length : item->data, 0,
                          &item->length);
}

/*
 * vsql_m_bind binds the <input using clause> to the dynamic parameters of a
 * statement, which was prepared from sql. It returns 0 (with the status
 * parameter set) if they don't match.
 *
 * ISO/IEC 9075-2:2016(E), 20.11, <input using clause>, General Rules, 2 and 3
 */
static int vsql_m_bind(char *sqlstate, SQLHSTMT stmt, const char *sql,
                       struct vsql_m_input *in) {
  struct vsql_m_descriptor *d;
  SQLRETURN rc = SQL_SUCCESS;
  int single, n = vsql_m_scan(sql, &single), i;

  if (in->descriptor != NULL) {
    /* ISO/IEC 9075-2:2016(E), 20.11, <input using clause>, General Rules, 5 and 5.d.ii */
    d = vsql_m_descriptor(sqlstate, in->descriptor, in->module);
    if (d == NULL || !vsql_m_items(sqlstate, d, n, "07001")) {
      return 0;
    }
    for (i = 0; i < n && !vsql_m_failed(rc); i++) {
      if (d->items[i].data == NULL &&
          d->items[i].number[VSQL_M_INDICATOR] >= 0) {
        vsql_m_status(sqlstate, "07001");
        return 0;
      }
      rc = vsql_m_bind_item(stmt, (SQLSMALLINT)(i + 1), &d->items[i]);
    }
  } else if (in->n < 0) {
    /* ISO/IEC 9075-2:2016(E), 20.13, <execute statement>, General Rules, 5
     * ISO/IEC 9075-2:2016(E), 20.19, <dynamic open statement>, General Rules, 3
     */
    if (n > 0) {
      vsql_m_status(sqlstate, "07004");
      return 0;
    }
  } else {
    /* ISO/IEC 9075-2:2016(E), 20.11, <input using clause>, General Rules, 4
     */
    if (in->n != n) {
      vsql_m_status(sqlstate, "07001");
      return 0;
    }
    rc = vsql_m_bind_params(stmt, n, in->params);
  }

  if (vsql_m_failed(rc)) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_STMT, stmt);
    return 0;
  }

  return 1;
}

/* section output */
/*
 * An <output using clause> is the targets (n of them) or an SQL descriptor
 * area. n is -1 when there isn't one.
 *
 * ISO/IEC 9075-2:2016(E), 20.12, <output using clause>
 */
struct vsql_m_output {
  int n;
  struct vsql_m_target *targets;
  const char *descriptor;
  const void *module;
};

/*
 * vsql_m_get_column sets DATA, INDICATOR, RETURNED_LENGTH and
 * RETURNED_OCTET_LENGTH of the item descriptor area to the value of column i,
 * cast to the data type of the item. A CHARACTER is padded with spaces to its
 * length. The returned lengths are of the value that's assigned (not the value
 * of a CHARACTER VARYING column) (#800).
 *
 * ISO/IEC 9075-2:2016(E), 20.12, <output using clause>, General Rules, 5.d.ii and 5.e.i
 */
static SQLRETURN vsql_m_get_column(SQLHSTMT stmt, SQLSMALLINT i,
                                   struct vsql_m_item *item) {
  SQLINTEGER *number = item->number, length = 0, characters = 0;
  size_t size;
  SQLSMALLINT c = vsql_m_c_type(item, &size);
  char *data = (char *)malloc(size), *s;
  SQLRETURN rc;

  if (data == NULL) {
    return SQL_ERROR;
  }
  rc = SQLGetData(stmt, i, c, data, (SQLINTEGER)size, &length);
  if (vsql_m_failed(rc)) {
    free(data);
    return rc;
  }
  free(item->data);
  item->data = data;
  number[VSQL_M_INDICATOR] = length == SQL_NULL_DATA ? -1 : 0;

  if (c == SQL_CHAR && length != SQL_NULL_DATA) {
    for (s = data; *s != '\0'; s++) {
      if ((*s & 0xC0) != 0x80) {
        characters++;
      }
    }
    if (number[VSQL_M_TYPE] == SQL_CHAR) {
      for (; characters < number[VSQL_M_LENGTH]; characters++) {
        *s++ = ' ';
      }
      *s = '\0';
    }
    number[VSQL_M_RETURNED_LENGTH] = characters;
    number[VSQL_M_RETURNED_OCTET_LENGTH] = (SQLINTEGER)strlen(data);
  }

  return rc;
}

/*
 * vsql_m_into assigns the values of the row that stmt was fetched to (rc is the
 * return code of the fetch) to the <output using clause>. It returns 1 if the
 * values were assigned, otherwise the status parameter is set (and no data
 * isn't an assignment).
 *
 * ISO/IEC 9075-2:2016(E), 20.12, <output using clause>, General Rules, 1 and 2.a
 * ISO/IEC 9075-2:2016(E), 20.20, <dynamic fetch statement>, General Rules, 4 and 5
 */
static int vsql_m_into(char *sqlstate, SQLHSTMT stmt, SQLRETURN rc,
                       struct vsql_m_output *out) {
  struct vsql_m_descriptor *d;
  SQLSMALLINT columns = 0;
  int i, truncated = 0;

  if (!vsql_m_failed(rc) && rc != SQL_NO_DATA) {
    rc = SQLNumResultCols(stmt, &columns);
  }
  if (vsql_m_failed(rc) || rc == SQL_NO_DATA) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_STMT, stmt);
    return 0;
  }

  if (out->descriptor == NULL) {
    /* ISO/IEC 9075-2:2016(E), 20.12, <output using clause>, General Rules, 3 and 5.e.ii */
    if (out->n != columns) {
      vsql_m_status(sqlstate, "07002");
      return 0;
    }
    rc = vsql_m_assign_row(stmt, rc, out->n, out->targets, &truncated);
  } else {
    /* ISO/IEC 9075-2:2016(E), 20.12, <output using clause>, General Rules, 4
     */
    d = vsql_m_descriptor(sqlstate, out->descriptor, out->module);
    if (d == NULL || !vsql_m_items(sqlstate, d, columns, "07002")) {
      return 0;
    }
    for (i = 0; i < columns && !vsql_m_failed(rc); i++) {
      rc = vsql_m_get_column(stmt, (SQLSMALLINT)(i + 1), &d->items[i]);
      if (rc == SQL_SUCCESS_WITH_INFO) {
        truncated = 1;
      }
    }
  }

  if (vsql_m_failed(rc)) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_STMT, stmt);
    return 0;
  }
  vsql_m_status(sqlstate, truncated ? "01004" : "00000");

  return 1;
}

/* section execute_prepared */
/*
 * vsql_m_execute_prepared is an <execute statement>. A <dynamic select
 * statement> can only be executed if it's a <dynamic single row select
 * statement>, with an <output using clause>. Any other statement has no output
 * dynamic parameters. It returns 1 if the values of a row were assigned.
 *
 * ISO/IEC 9075-2:2016(E), 20.12, <output using clause>, General Rules, 2.b
 * ISO/IEC 9075-2:2016(E), 20.13, <execute statement>, General Rules, 2 and 7
 * ISO/IEC 9075-2:2016(E), 20.13, <execute statement>, General Rules, 10
 */
static int vsql_m_execute_prepared(char *sqlstate, const char *name,
                                   struct vsql_m_input *in,
                                   struct vsql_m_output *out) {
  struct vsql_m_prepared *p = vsql_m_prepared_statement(sqlstate, name);
  struct vsql_m_descriptor *d;
  SQLSMALLINT columns = 0;
  SQLRETURN rc;
  int single, assigned;

  if (p == NULL) {
    return 0;
  }
  strcpy(vsql_m_da.dynamic_function, p->dynamic_function);
  vsql_m_da.dynamic_function_code = p->dynamic_function_code;

  vsql_m_scan(p->sql, &single);
  SQLNumResultCols(p->stmt, &columns);
  if (columns > 0) {
    /* ISO/IEC 9075-2:2016(E), 20.13, <execute statement>, General Rules, 3.a and 3.b */
    if (!single) {
      vsql_m_status(sqlstate, "07003");
      return 0;
    }

    /* ISO/IEC 9075-2:2016(E), 20.13, <execute statement>, General Rules, 6 */
    if (out->n < 0 && out->descriptor == NULL) {
      vsql_m_status(sqlstate, "07007");
      return 0;
    }
    strcpy(vsql_m_da.dynamic_function, "SELECT");
    vsql_m_da.dynamic_function_code = 41;
  } else if (out->descriptor != NULL) {
    d = vsql_m_descriptor(sqlstate, out->descriptor, out->module);
    if (d == NULL || !vsql_m_items(sqlstate, d, 0, "07002")) {
      return 0;
    }
  } else if (out->n > 0) {
    vsql_m_status(sqlstate, "07002");
    return 0;
  }

  if (!vsql_m_bind(sqlstate, p->stmt, p->sql, in)) {
    return 0;
  }

  /* The statement initiates an SQL-transaction.
   *
   * ISO/IEC 9075-2:2016(E), 13.4, <SQL procedure statement>, General Rules, 9
   * ISO/IEC 9075-2:2016(E), 20.13, <execute statement>, General Rules, 9 */
  vsql_m_current->active = 1;
  rc = SQLExecute(p->stmt);
  if (!vsql_m_failed(rc)) {
    SQLGetDiagField(SQL_HANDLE_STMT, p->stmt, 0, SQL_DIAG_ROW_COUNT,
                    &vsql_m_da.row_count, 0, NULL);
  }
  if (columns == 0 || vsql_m_failed(rc)) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_STMT, p->stmt);
    return 0;
  }

  /* There must be one row.
   *
   * ISO/IEC 9075-2:2016(E), 20.21, <dynamic single row select statement>, General Rules, 2.a and 2.b */
  assigned = vsql_m_into(sqlstate, p->stmt, SQLFetch(p->stmt), out);
  if (assigned) {
    rc = SQLFetch(p->stmt);
    if (rc == SQL_SUCCESS || rc == SQL_SUCCESS_WITH_INFO) {
      vsql_m_status(sqlstate, "21000");
    } else if (rc != SQL_NO_DATA) {
      vsql_m_diag(sqlstate, rc, SQL_HANDLE_STMT, p->stmt);
    }
  }
  SQLCloseCursor(p->stmt);

  return assigned;
}

/* section execute_immediate */
/*
 * vsql_m_execute_immediate is an <execute immediate statement>, which prepares
 * and executes a statement, without a prepared statement. The statement can't
 * be a query, or have a dynamic parameter: syntax error or access rule
 * violation.
 *
 * ISO/IEC 9075-2:2016(E), 20.14, <execute immediate statement>, General Rules, 1 to 3
 */
static void vsql_m_execute_immediate(char *sqlstate, const char *sql) {
  struct vsql_m_connection *c = vsql_m_connection(sqlstate);
  SQLSMALLINT columns = 0;
  SQLHSTMT stmt;
  SQLRETURN rc;
  int single;

  if (c == NULL) {
    return;
  }
  if (vsql_m_scan(sql, &single) > 0) {
    vsql_m_status(sqlstate, "42000");
    return;
  }

  rc = SQLAllocHandle(SQL_HANDLE_STMT, c->dbc, &stmt);
  if (vsql_m_failed(rc)) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_DBC, c->dbc);
    return;
  }

  rc = SQLPrepare(stmt, (SQLCHAR *)sql, SQL_NTS);
  if (!vsql_m_failed(rc)) {
    SQLGetDiagField(SQL_HANDLE_STMT, stmt, 0, SQL_DIAG_DYNAMIC_FUNCTION,
                    vsql_m_da.dynamic_function,
                    sizeof(vsql_m_da.dynamic_function), NULL);
    SQLGetDiagField(SQL_HANDLE_STMT, stmt, 0, SQL_DIAG_DYNAMIC_FUNCTION_CODE,
                    &vsql_m_da.dynamic_function_code, 0, NULL);
    rc = SQLNumResultCols(stmt, &columns);
  }
  if (!vsql_m_failed(rc) && columns > 0) {
    vsql_m_status(sqlstate, "42000");
    SQLFreeHandle(SQL_HANDLE_STMT, stmt);
    return;
  }

  /* The statement initiates an SQL-transaction.
   *
   * ISO/IEC 9075-2:2016(E), 13.4, <SQL procedure statement>, General Rules, 9
   */
  if (!vsql_m_failed(rc)) {
    c->active = 1;
    rc = SQLExecute(stmt);
  }
  if (!vsql_m_failed(rc)) {
    SQLGetDiagField(SQL_HANDLE_STMT, stmt, 0, SQL_DIAG_ROW_COUNT,
                    &vsql_m_da.row_count, 0, NULL);
  }
  vsql_m_diag(sqlstate, rc, SQL_HANDLE_STMT, stmt);
  SQLFreeHandle(SQL_HANDLE_STMT, stmt);
}

/* section open_dynamic */
/*
 * vsql_m_open_dynamic opens the dynamic cursor i, which is declared for a
 * prepared statement. The cursor's CLI statement prepares the statement again,
 * so the cursor stays the same if the prepared statement is prepared again, and
 * more than one cursor can be declared for the same prepared statement. The
 * cursor is updatable if its query is.
 *
 * ISO/IEC 9075-2:2016(E), 20.19, <dynamic open statement>, General Rules, 4 to 7
 * ISO/IEC 9075-2:2016(E), 15.1, Effect of opening a cursor, General Rules, 4.b
 */
static void vsql_m_open_dynamic(char *sqlstate, int i, const char *name,
                                int hold, const char *statement,
                                struct vsql_m_input *in) {
  struct vsql_m_prepared *p = vsql_m_prepared_statement(sqlstate, statement);
  SQLSMALLINT columns = 0;
  SQLHSTMT stmt;
  SQLRETURN rc;

  if (p == NULL) {
    return;
  }

  /* ISO/IEC 9075-2:2016(E), 20.19, <dynamic open statement>, General Rules, 1.a.ii */
  SQLNumResultCols(p->stmt, &columns);
  if (columns == 0) {
    vsql_m_status(sqlstate, "07005");
    return;
  }

  stmt = vsql_m_cursor(sqlstate, i, name, hold);
  if (stmt == 0) {
    return;
  }

  /* A cursor that's already open is an invalid cursor state (from libvsql).
   * Otherwise, if it can't be opened, the CLI statement is freed, like
   * vsql_m_open_cursor. */
  rc = SQLPrepare(stmt, (SQLCHAR *)p->sql, SQL_NTS);
  if (vsql_m_failed(rc)) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_STMT, stmt);
    if (strcmp(sqlstate, "24000") == 0) {
      return;
    }
  } else if (vsql_m_bind(sqlstate, stmt, p->sql, in)) {
    vsql_m_current->active = 1;
    rc = SQLExecute(stmt);
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_STMT, stmt);
    if (!vsql_m_failed(rc)) {
      return;
    }
  }

  SQLFreeHandle(SQL_HANDLE_STMT, stmt);
  vsql_m_cursors(vsql_m_current)[i] = 0;
}

/* section fetch_dynamic */
/*
 * vsql_m_fetch_dynamic moves the dynamic cursor i to the next row and assigns
 * its values to the <output using clause>. It returns 1 if they were assigned.
 *
 * ISO/IEC 9075-2:2016(E), 20.20, <dynamic fetch statement>, General Rules, 2 and 3
 */
static int vsql_m_fetch_dynamic(char *sqlstate, int i,
                                struct vsql_m_output *out) {
  SQLHSTMT stmt = vsql_m_cursor(sqlstate, i, NULL, 0);

  return stmt != 0 && vsql_m_into(sqlstate, stmt, SQLFetch(stmt), out);
}
