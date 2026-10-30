/* section cursor */
/*
 * The cursors of the module (14.1). Each SQL-connection has a CLI statement for
 * each cursor that has been opened in it, with the cursor name, so that a
 * positioned DELETE or UPDATE (14.8, 14.13) can change its current row.
 * vsql_m_cursors is the CLI statements of the cursors of this module in c, or
 * NULL if there isn't enough memory.
 */
static SQLHSTMT *vsql_m_cursors(struct vsql_m_connection *c) {
  struct vsql_m_cursors *m;

  for (m = c->cursors; m != NULL; m = m->next) {
    if (m->module == &vsql_m_own) {
      return m->stmts;
    }
  }

  m = (struct vsql_m_cursors *)malloc(sizeof(struct vsql_m_cursors));
  if (m == NULL) {
    return NULL;
  }
  m->stmts = (SQLHSTMT *)calloc((size_t)vsql_m_cursor_count, sizeof(SQLHSTMT));
  if (m->stmts == NULL) {
    free(m);
    return NULL;
  }
  m->module = &vsql_m_own;
  m->n = vsql_m_cursor_count;
  m->next = c->cursors;
  c->cursors = m;

  return m->stmts;
}

/*
 * vsql_m_cursor is the CLI statement of cursor i in the current
 * SQL-connection. It's allocated (with the name and holdability of the cursor)
 * the first time that the cursor is opened, so for a FETCH or CLOSE (when name
 * is NULL) a cursor that has never been opened is an exception condition:
 * invalid cursor state.
 */
static SQLHSTMT vsql_m_cursor(char *sqlstate, int i, const char *name,
                              int hold) {
  struct vsql_m_connection *c = vsql_m_connection(sqlstate);
  SQLINTEGER holdable = hold ? SQL_HOLDABLE : SQL_NONHOLDABLE;
  SQLHSTMT *cursors;
  SQLRETURN rc;

  if (c == NULL) {
    return 0;
  }
  cursors = vsql_m_cursors(c);
  if (cursors == NULL) {
    vsql_m_status(sqlstate, "HY001");
    return 0;
  }
  if (cursors[i] != 0) {
    return cursors[i];
  }
  if (name == NULL) {
    vsql_m_status(sqlstate, "24000");
    return 0;
  }

  rc = SQLAllocHandle(SQL_HANDLE_STMT, c->dbc, &cursors[i]);
  if (vsql_m_failed(rc)) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_DBC, c->dbc);
    cursors[i] = 0;
    return 0;
  }
  rc = SQLSetCursorName(cursors[i], (SQLCHAR *)name, SQL_NTS);
  if (!vsql_m_failed(rc)) {
    rc = SQLSetStmtAttr(cursors[i], SQL_ATTR_CURSOR_HOLDABLE, &holdable, 0);
  }
  if (vsql_m_failed(rc)) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_STMT, cursors[i]);
    SQLFreeHandle(SQL_HANDLE_STMT, cursors[i]);
    cursors[i] = 0;
    return 0;
  }

  return cursors[i];
}

/* section open */
/*
 * vsql_m_open_cursor opens cursor i (15.1), by executing its query. A cursor
 * that's already open is an invalid cursor state (from libvsql). If the query
 * fails, the cursor isn't open, so the CLI statement is freed, otherwise a
 * FETCH would be a function sequence error, instead of an invalid cursor
 * state.
 */
static void vsql_m_open_cursor(char *sqlstate, int i, const char *name,
                               int hold, const char *sql, int n,
                               struct vsql_m_param *params) {
  SQLHSTMT stmt = vsql_m_cursor(sqlstate, i, name, hold);

  if (stmt != 0 && !vsql_m_exec(sqlstate, vsql_m_current, stmt, sql, n,
                                params) &&
      strcmp(sqlstate, "24000") != 0) {
    SQLFreeHandle(SQL_HANDLE_STMT, stmt);
    vsql_m_cursors(vsql_m_current)[i] = 0;
  }
}

/* section fetch */
/*
 * vsql_m_fetch moves cursor i to the next row and assigns its values to the
 * targets (15.3). It returns 1 if the values were assigned. After the last row
 * there's no data.
 */
static int vsql_m_fetch(char *sqlstate, int i, int m,
                        struct vsql_m_target *targets) {
  SQLHSTMT stmt = vsql_m_cursor(sqlstate, i, NULL, 0);
  SQLSMALLINT columns;
  SQLRETURN rc;
  int truncated = 0;

  if (stmt == 0) {
    return 0;
  }

  /*
   * The number of columns is only different from the number of targets when
   * the select list has an asterisk: dynamic SQL error — using clause does not
   * match target specifications.
   */
  rc = SQLFetch(stmt);
  if (rc == SQL_SUCCESS || rc == SQL_SUCCESS_WITH_INFO) {
    rc = SQLNumResultCols(stmt, &columns);
    if (!vsql_m_failed(rc) && columns != m) {
      vsql_m_status(sqlstate, "07002");
      return 0;
    }
  }

  rc = vsql_m_assign_row(stmt, rc, m, targets, &truncated);
  if (vsql_m_failed(rc) || rc == SQL_NO_DATA) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_STMT, stmt);
    return 0;
  }
  vsql_m_status(sqlstate, truncated ? "01004" : "00000");

  return 1;
}

/* section close */
/* vsql_m_close_cursor closes cursor i (15.4). */
static void vsql_m_close_cursor(char *sqlstate, int i) {
  SQLHSTMT stmt = vsql_m_cursor(sqlstate, i, NULL, 0);

  if (stmt != 0) {
    vsql_m_diag(sqlstate, SQLCloseCursor(stmt), SQL_HANDLE_STMT, stmt);
  }
}
