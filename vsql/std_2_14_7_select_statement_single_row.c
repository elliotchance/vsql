/* section put */
/*
 * vsql_m_put assigns a string to a CHARACTER(length) or CHARACTER
 * VARYING(length) target, which has (length + 1) * 4 bytes since a UTF-8
 * character is up to 4 bytes. A value of more than length characters is cut
 * to its first length characters (never part of a character), and a shorter
 * one is padded with spaces to length characters (rather than length * 4 bytes,
 * which is only meant for a character set where every character has the same
 * size). It returns 1 if the string was truncated (warning: string data, right
 * truncation). The value can be the target.
 *
 * ISO/IEC 9075-2:2016(E), 9.1, Retrieval assignment, General Rules, 7.a-7.e
 * ISO/IEC 9075-2:2016(E), 9.4, Passing a value from the SQL-server to a host language, General Rules, 5.b
 * ISO/IEC 9075-2:2016(E), 13.5, Data type correspondences, Table 20
 * ISO/IEC 9075-2:2016(E), 23.1, <get diagnostics statement>, General Rules, 6.b and 6.c
 */
static int vsql_m_put(char *target, size_t length, const char *value) {
  size_t octets = 0, characters = 0;
  int truncated;

  for (; value[octets] != '\0'; octets++) {
    if (((unsigned char)value[octets] & 0xC0) != 0x80) {
      if (characters == length) {
        break;
      }
      characters++;
    }
  }
  truncated = value[octets] != '\0';
  memmove(target, value, octets);
  for (; characters < length; characters++) {
    target[octets++] = ' ';
  }
  target[octets] = '\0';

  return truncated;
}

/* section target */
/*
 * The target of a value in the row of a <select statement: single row>. The
 * type is the SQL data type of the host parameter, and length is the length in
 * characters of a string (see vsql_m_put). max_indicator is the largest value
 * that the indicator parameter can contain, or 0 (zero) if there isn't one.
 */
struct vsql_m_target {
  SQLSMALLINT type;
  SQLINTEGER length;
  SQLPOINTER value;
  SQLINTEGER max_indicator;
  SQLINTEGER indicator;
};

/* vsql_m_characters is the number of characters that start in a piece of a
 * UTF-8 string, which can end in the middle of a character. */
static SQLINTEGER vsql_m_characters(const char *s) {
  SQLINTEGER characters = 0;

  for (; *s != '\0'; s++) {
    if (((unsigned char)*s & 0xC0) != 0x80) {
      characters++;
    }
  }

  return characters;
}

/*
 * vsql_m_assign assigns the value of column i to the target. The indicator is
 * SQL_NULL_DATA for a null value, the length in characters of a string that was
 * truncated (warning: string data, right truncation), and otherwise 0 (zero). A
 * null value without an indicator parameter is an exception: data exception —
 * null value, no indicator parameter. A length that's too big for the indicator
 * parameter is an exception: data exception — indicator overflow.
 *
 * The value is converted by SQLGetData, so one that isn't assignable is cast
 * when it's retrieved, rather than being a syntax error.
 *
 * ISO/IEC 9075-2:2016(E), 9.1, Retrieval assignment, Syntax Rules, 3 and 5.b
 * ISO/IEC 9075-2:2016(E), 9.1, Retrieval assignment, General Rules, 3 to 6
 * ISO/IEC 9075-2:2016(E), 9.1, Retrieval assignment, General Rules, 7
 * ISO/IEC 9075-2:2016(E), 13.4, <SQL procedure statement>, General Rules, 12.b
 */
static SQLRETURN vsql_m_assign(SQLHSTMT stmt, SQLSMALLINT i,
                               struct vsql_m_target *t) {
  SQLINTEGER *indicator = t->max_indicator > 0 ? &t->indicator : NULL;
  SQLINTEGER characters;
  SQLRETURN rc;
  char b[256];

  /*
   * A BOOLEAN is retrieved as 'TRUE' or 'FALSE', and is 1 or 0 in C.
   *
   * ISO/IEC 9075-2:2016(E), 9.1, Retrieval assignment, General Rules, 7.p
   * ISO/IEC 9075-2:2016(E), 9.4, Passing a value from the SQL-server to a host language, General Rules, 5.g.ii
   */
  if (t->type == SQL_BOOLEAN) {
    rc = SQLGetData(stmt, i, SQL_CHAR, b, sizeof(b), indicator);
    if (!vsql_m_failed(rc) && (indicator == NULL || *indicator >= 0)) {
      *(long *)t->value = strcmp(b, "TRUE") == 0;
      t->indicator = 0;
    }
    return rc;
  }

  if (t->type != SQL_CHAR && t->type != SQL_VARCHAR) {
    return SQLGetData(stmt, i, t->type, t->value, 0, indicator);
  }

  /*
   * A string is retrieved into all of the target, which holds any value of
   * length characters, and is then cut to length characters. A CHARACTER(L)
   * or CHARACTER VARYING(L) is padded with spaces to its length.
   *
   * ISO/IEC 9075-2:2016(E), 9.1, Retrieval assignment, General Rules, 7.c and 7.e
   * ISO/IEC 9075-2:2016(E), 9.4, Passing a value from the SQL-server to a host language, General Rules, 5.b and 5.l
   */
  rc = SQLGetData(stmt, i, SQL_CHAR, t->value, (t->length + 1) * 4, indicator);
  if (vsql_m_failed(rc) || (indicator != NULL && *indicator < 0)) {
    return rc;
  }
  characters = vsql_m_characters((char *)t->value);
  if (!vsql_m_put((char *)t->value, (size_t)t->length, (char *)t->value)) {
    t->indicator = 0;
    return rc;
  }
  if (indicator == NULL) {
    return SQL_SUCCESS_WITH_INFO;
  }

  /*
   * The target only holds the start of a long value, so the characters of the
   * rest of it are counted in pieces.
   *
   * ISO/IEC 9075-2:2016(E), 9.1, Retrieval assignment, General Rules, 5.a and 6.a
   */
  while (rc == SQL_SUCCESS_WITH_INFO) {
    rc = SQLGetData(stmt, i, SQL_CHAR, b, sizeof(b), NULL);
    if (vsql_m_failed(rc)) {
      return rc;
    }
    characters += vsql_m_characters(b);
  }
  if (characters > t->max_indicator) {
    return VSQL_M_INDICATOR_OVERFLOW;
  }
  t->indicator = characters;

  return SQL_SUCCESS_WITH_INFO;
}

/*
 * vsql_m_assign_row assigns the values of the row that stmt has been fetched
 * to (rc is the return code of the fetch) to the targets, which are host
 * parameters (or embedded variables of the implied module). truncated is set
 * to 1 if a string was truncated.
 *
 * ISO/IEC 9075-2:2016(E), 14.5, <fetch statement>, Syntax Rules, 9.b.iv and 9.b.v
 * ISO/IEC 9075-2:2016(E), 14.5, <fetch statement>, General Rules, 5.b
 */
static SQLRETURN vsql_m_assign_row(SQLHSTMT stmt, SQLRETURN rc, int m,
                                   struct vsql_m_target *targets,
                                   int *truncated) {
  int i;

  for (i = 0; i < m && (rc == SQL_SUCCESS || rc == SQL_SUCCESS_WITH_INFO);
       i++) {
    rc = vsql_m_assign(stmt, (SQLSMALLINT)(i + 1), &targets[i]);
    if (rc == SQL_SUCCESS_WITH_INFO) {
      *truncated = 1;
    }
  }

  return rc;
}

/* section select */
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
  int truncated = 0;

  if (!vsql_m_run(sqlstate, sql, n, params, &stmt)) {
    return 0;
  }

  /*
   * The number of columns must be the number of targets. It's only different
   * when the select list has an asterisk: dynamic SQL error — using clause
   * does not match target specifications.
   *
   * ISO/IEC 9075-2:2016(E), 14.7, <select statement: single row>, Syntax Rules, 3.b.i
   */
  rc = SQLNumResultCols(stmt, &columns);
  if (!vsql_m_failed(rc) && columns != m) {
    vsql_m_status(sqlstate, "07002");
    SQLFreeHandle(SQL_HANDLE_STMT, stmt);
    return 0;
  }

  /*
   * If there's no row, then a completion condition is raised: no data.
   *
   * ISO/IEC 9075-2:2016(E), 14.7, <select statement: single row>, General Rules, 2.b and 3
   */
  if (!vsql_m_failed(rc)) {
    rc = SQLFetch(stmt);
  }

  /*
   * Otherwise, the values in the row are assigned to the targets.
   *
   * ISO/IEC 9075-2:2016(E), 14.7, <select statement: single row>, General Rules, 2.c and 4
   */
  rc = vsql_m_assign_row(stmt, rc, m, targets, &truncated);

  if (vsql_m_failed(rc) || rc == SQL_NO_DATA) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_STMT, stmt);
    SQLFreeHandle(SQL_HANDLE_STMT, stmt);
    return 0;
  }

  /*
   * If there's more than one row, then an exception condition is raised:
   * cardinality violation. The values of the first row have been assigned.
   *
   * ISO/IEC 9075-2:2016(E), 14.7, <select statement: single row>, General Rules, 2.a
   */
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
