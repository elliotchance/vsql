/* section select */
/*
 * The target of a value in the row of a <select statement: single row>. The
 * type is the SQL data type of the host parameter, and the length of a string
 * includes the null character. The indicator is set when has_indicator is 1.
 */
struct vsql_m_target {
  SQLSMALLINT type;
  SQLINTEGER length;
  SQLPOINTER value;
  int has_indicator;
  SQLINTEGER indicator;
};

/*
 * vsql_m_assign assigns the value of column i to the target (9.1 Retrieval
 * assignment). The indicator is SQL_NULL_DATA for a null value, or the length
 * of a string that was truncated (warning: string data, right truncation). A
 * null value without an indicator parameter is an exception: data exception —
 * null value, no indicator parameter.
 */
static SQLRETURN vsql_m_assign(SQLHSTMT stmt, SQLSMALLINT i,
                               struct vsql_m_target *t) {
  SQLINTEGER *indicator = t->has_indicator ? &t->indicator : NULL;
  SQLINTEGER length;
  SQLRETURN rc;
  char b[6];

  /* A BOOLEAN is retrieved as 'TRUE' or 'FALSE', and is 1 or 0 in C. */
  if (t->type == SQL_BOOLEAN) {
    rc = SQLGetData(stmt, i, SQL_CHAR, b, sizeof(b), indicator);
    if (!vsql_m_failed(rc) && (indicator == NULL || *indicator >= 0)) {
      *(long *)t->value = strcmp(b, "TRUE") == 0;
    }
    return rc;
  }

  rc = SQLGetData(stmt, i,
                  t->type == SQL_VARCHAR ? (SQLSMALLINT)SQL_CHAR : t->type,
                  t->value, t->length, indicator);

  /* A CHARACTER(L) is padded with spaces to its length. */
  if (t->type == SQL_CHAR && !vsql_m_failed(rc) &&
      (indicator == NULL || *indicator >= 0)) {
    length = (SQLINTEGER)strlen((char *)t->value);
    memset((char *)t->value + length, ' ', (size_t)(t->length - 1 - length));
    ((char *)t->value)[t->length - 1] = '\0';
  }

  return rc;
}

/*
 * vsql_m_select executes the query and assigns the values of its only row to
 * the targets. It returns 1 if the values were assigned.
 */
static int vsql_m_select(char *sqlstate, const char *sql, int n,
                         struct vsql_m_param *params, int m,
                         struct vsql_m_target *targets) {
  SQLHSTMT stmt;
  SQLSMALLINT columns;
  SQLRETURN rc;
  int i, truncated = 0;

  if (!vsql_m_run(sqlstate, sql, n, params, &stmt)) {
    return 0;
  }

  /*
   * SR 3.b.i: The number of columns must be the number of targets. It's only
   * different when the select list has an asterisk: dynamic SQL error — using
   * clause does not match target specifications.
   */
  rc = SQLNumResultCols(stmt, &columns);
  if (!vsql_m_failed(rc) && columns != m) {
    vsql_m_status(sqlstate, "07002");
    SQLFreeHandle(SQL_HANDLE_STMT, stmt);
    return 0;
  }

  /* GR 2.b: If there's no row, then a completion condition is raised: no
   * data. */
  if (!vsql_m_failed(rc)) {
    rc = SQLFetch(stmt);
  }

  /* GR 2.c: Otherwise, the values in the row are assigned to the targets. */
  for (i = 0; i < m && (rc == SQL_SUCCESS || rc == SQL_SUCCESS_WITH_INFO);
       i++) {
    rc = vsql_m_assign(stmt, (SQLSMALLINT)(i + 1), &targets[i]);
    if (rc == SQL_SUCCESS_WITH_INFO) {
      truncated = 1;
    }
  }

  if (vsql_m_failed(rc) || rc == SQL_NO_DATA) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_STMT, stmt);
    SQLFreeHandle(SQL_HANDLE_STMT, stmt);
    return 0;
  }

  /* GR 2.a: If there's more than one row, then an exception condition is
   * raised: cardinality violation. */
  rc = SQLFetch(stmt);
  if (rc == SQL_NO_DATA) {
    vsql_m_status(sqlstate, truncated ? "01004" : "00000");
  } else if (vsql_m_failed(rc)) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_STMT, stmt);
  } else {
    vsql_m_status(sqlstate, "21000");
  }
  SQLFreeHandle(SQL_HANDLE_STMT, stmt);

  return 1;
}
