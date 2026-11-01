/* section scan */
/*
 * vsql_m_scan returns the number of dynamic parameters ("?") in the text of a
 * statement, that aren't in a literal, a delimited identifier or a comment.
 * single is set to 1 if the statement can be a <dynamic single row select
 * statement>, which is a <query specification>: it starts with SELECT, and
 * doesn't have a UNION, EXCEPT, INTERSECT, ORDER BY, OFFSET or FETCH that isn't
 * in parentheses.
 *
 * ISO/IEC 9075-2:2016(E), 20.21, <dynamic single row select statement>
 */
static int vsql_m_scan(const char *sql, int *single) {
  static const char *const words[] = {"UNION", "EXCEPT", "INTERSECT",
                                      "ORDER", "OFFSET", "FETCH"};
  int n = 0, depth = 0, first = 1, depth_comment;
  size_t i = 0, start, j, k;
  char word[10], quote;

  *single = 0;
  while (sql[i] != '\0') {
    if (sql[i] == '\'' || sql[i] == '"') {
      /* A doubled quote is the end of one string and the start of another. */
      quote = sql[i++];
      while (sql[i] != '\0' && sql[i] != quote) {
        i++;
      }
      if (sql[i] != '\0') {
        i++;
      }
    } else if (sql[i] == '/' && sql[i + 1] == '*') {
      /* Bracketed comments can be nested. */
      depth_comment = 1;
      i += 2;
      while (sql[i] != '\0' && depth_comment > 0) {
        if (sql[i] == '/' && sql[i + 1] == '*') {
          depth_comment++;
          i++;
        } else if (sql[i] == '*' && sql[i + 1] == '/') {
          depth_comment--;
          i++;
        }
        i++;
      }
    } else if (sql[i] == '-' && sql[i + 1] == '-') {
      while (sql[i] != '\0' && sql[i] != '\n') {
        i++;
      }
    } else if (isalpha((unsigned char)sql[i]) || sql[i] == '_') {
      start = i;
      while (isalnum((unsigned char)sql[i]) || sql[i] == '_') {
        i++;
      }
      for (j = 0; j < i - start && j < sizeof(word) - 1; j++) {
        word[j] = (char)toupper((unsigned char)sql[start + j]);
      }
      word[j] = '\0';
      if (first) {
        *single = strcmp(word, "SELECT") == 0;
        first = 0;
      } else if (depth == 0) {
        for (k = 0; k < sizeof(words) / sizeof(words[0]); k++) {
          if (strcmp(word, words[k]) == 0) {
            *single = 0;
          }
        }
      }
    } else {
      if (sql[i] == '?') {
        n++;
      } else if (sql[i] == '(') {
        depth++;
      } else if (sql[i] == ')') {
        depth--;
      }
      first = first && isspace((unsigned char)sql[i]);
      i++;
    }
  }

  return n;
}

/* section find_descriptor */
/*
 * The SQL descriptor areas of an SQL-connection. Every <SQL dynamic statement>
 * that uses one is transaction-initiating.
 *
 * ISO/IEC 9075-2:2016(E), 4.39.4, SQL-statements and transaction states
 */
static struct vsql_m_descriptor **
vsql_m_find_descriptor(struct vsql_m_connection *c, const char *name,
                       const void *module) {
  struct vsql_m_descriptor **d = &c->descriptors;

  while (*d != NULL &&
         ((*d)->module != module || strcmp((*d)->name, name) != 0)) {
    d = &(*d)->next;
  }

  return d;
}

/* section descriptor */
/*
 * vsql_m_descriptor is the SQL descriptor area with the name in the current
 * SQL-connection, or NULL (with the status parameter set) if there isn't one:
 * invalid SQL descriptor name.
 *
 * ISO/IEC 9075-2:2016(E), 20.4, <get descriptor statement>, General Rules, 1
 * ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>, General Rules, 2
 * ISO/IEC 9075-2:2016(E), 20.10, <describe statement>, General Rules, 3
 * ISO/IEC 9075-2:2016(E), 20.11, <input using clause>, General Rules, 1
 * ISO/IEC 9075-2:2016(E), 20.12, <output using clause>, General Rules, 4.a
 */
static struct vsql_m_descriptor *
vsql_m_descriptor(char *sqlstate, const char *name, const void *module) {
  struct vsql_m_connection *c = vsql_m_connection(sqlstate);
  struct vsql_m_descriptor *d;

  if (c == NULL) {
    return NULL;
  }
  c->active = 1;

  d = *vsql_m_find_descriptor(c, name, module);
  if (d == NULL) {
    vsql_m_status(sqlstate, "33000");
  }

  return d;
}

/* section match */
/*
 * vsql_m_matches is 1 if the data type of a host parameter matches the data
 * type of an item descriptor area. type is a code from Table 28, and length is
 * the length of a CHARACTER or CHARACTER VARYING. A CHARACTER VARYING target
 * also matches a shorter CHARACTER VARYING. As an implementation-defined rule,
 * a DOUBLE PRECISION matches a FLOAT, and a character string matches a
 * NUMERIC, DECIMAL or datetime (which don't have a C data type), as its value
 * cast to a character string.
 *
 * ISO/IEC 9075-2:2016(E), 20.1, Description of SQL descriptor areas, Syntax Rules, 7 and 8
 */
static int vsql_m_matches(struct vsql_m_item *item, SQLSMALLINT type,
                          SQLINTEGER length, int target) {
  SQLINTEGER t = item->number[VSQL_M_TYPE], l = item->number[VSQL_M_LENGTH];

  switch (type) {
  case SQL_CHAR:
  case SQL_VARCHAR:
    if (t == SQL_NUMERIC || t == SQL_DECIMAL || t == SQL_DATETIME) {
      return 1;
    }
    return t == type &&
           (l == length || (type == SQL_VARCHAR && target && length >= l));
  case SQL_DOUBLE:
    return t == SQL_DOUBLE || t == SQL_FLOAT;
  }

  return t == type;
}

/* section items */
/*
 * vsql_m_valid is 1 if an item descriptor area is valid for a type that vsql
 * has. vsql doesn't have a ROW, ARRAY or MULTISET, so LEVEL must be 0 (zero).
 * A CHARACTER or CHARACTER VARYING is always in the character set of the
 * SQL-session, so its CHARACTER_SET_NAME isn't checked.
 *
 * ISO/IEC 9075-2:2016(E), 20.1, Description of SQL descriptor areas, Syntax Rules, 6
 */
static int vsql_m_valid(struct vsql_m_item *item) {
  SQLINTEGER *number = item->number;

  if (number[VSQL_M_LEVEL] != 0) {
    return 0;
  }

  switch (number[VSQL_M_TYPE]) {
  case SQL_CHAR:
  case SQL_VARCHAR:
    return number[VSQL_M_LENGTH] >= 1;
  case SQL_NUMERIC:
  case SQL_DECIMAL:
    return number[VSQL_M_PRECISION] >= 1 && number[VSQL_M_SCALE] >= 0 &&
           number[VSQL_M_SCALE] <= number[VSQL_M_PRECISION];
  case SQL_FLOAT:
    return number[VSQL_M_PRECISION] >= 1;
  case SQL_SMALLINT:
  case SQL_INTEGER:
  case SQL_BIGINT:
  case SQL_REAL:
  case SQL_DOUBLE:
  case SQL_BOOLEAN:
    return 1;
  case SQL_DATETIME:
    return number[VSQL_M_DATETIME_INTERVAL_CODE] >= SQL_CODE_DATE &&
           number[VSQL_M_DATETIME_INTERVAL_CODE] <= 5 &&
           number[VSQL_M_PRECISION] >= 0 && number[VSQL_M_PRECISION] <= 9;
  }

  return 0;
}

/*
 * vsql_m_items checks the first COUNT item descriptor areas of d for an <input
 * using clause> or an <output using clause>, which must be n valid item
 * descriptor areas. Otherwise it returns 0 (with the status parameter set):
 * invalid descriptor count, or sqlstate (using clause does not match dynamic
 * parameter specifications, or target specifications).
 *
 * ISO/IEC 9075-2:2016(E), 20.11, <input using clause>, General Rules, 5.a to 5.d.i
 * ISO/IEC 9075-2:2016(E), 20.12, <output using clause>, General Rules, 4.b to 4.e
 */
static int vsql_m_items(char *sqlstate, struct vsql_m_descriptor *d, int n,
                        const char *code) {
  int i;

  if (d->count < 0 || d->count > d->max) {
    vsql_m_status(sqlstate, "07008");
    return 0;
  }

  for (i = 0; i < d->count; i++) {
    if (!vsql_m_valid(&d->items[i])) {
      vsql_m_status(sqlstate, code);
      return 0;
    }
  }

  /* Every LEVEL is 0 (zero), so each item descriptor area is a value. */
  if (d->count != n) {
    vsql_m_status(sqlstate, code);
    return 0;
  }

  return 1;
}

/*
 * vsql_m_c_type is the C data type of DATA (for SQLBindParameter and
 * SQLGetData), and sets size to its size in bytes. A value of a type that
 * doesn't have a C data type is a character string, which is long enough for
 * any value of the type.
 */
static SQLSMALLINT vsql_m_c_type(struct vsql_m_item *item, size_t *size) {
  SQLINTEGER *number = item->number;

  switch (number[VSQL_M_TYPE]) {
  case SQL_SMALLINT:
    *size = sizeof(SQLSMALLINT);
    return SQL_SMALLINT;
  case SQL_INTEGER:
    *size = sizeof(SQLINTEGER);
    return SQL_INTEGER;
  case SQL_BIGINT:
    *size = sizeof(SQLBIGINT);
    return SQL_BIGINT;
  case SQL_REAL:
    *size = sizeof(SQLREAL);
    return SQL_REAL;
  case SQL_FLOAT:
  case SQL_DOUBLE:
    *size = sizeof(SQLDOUBLE);
    return SQL_DOUBLE;
  case SQL_CHAR:
  case SQL_VARCHAR:
    /* A character is up to 4 bytes of UTF-8. */
    *size = (size_t)number[VSQL_M_LENGTH] * 4 + 1;
    return SQL_CHAR;
  case SQL_NUMERIC:
  case SQL_DECIMAL:
    *size = (size_t)number[VSQL_M_PRECISION] + 3;
    return SQL_CHAR;
  }

  *size = 64;
  return SQL_CHAR;
}

/* section allocate_descriptor */
/*
 * vsql_m_allocate_descriptor creates an SQL descriptor area. The maximum
 * <occurrences> is 32767, which is the largest item number in the SQL/CLI.
 * There's no limit to the number of SQL descriptor areas.
 *
 * ISO/IEC 9075-2:2016(E), 20.2, <allocate descriptor statement>, General Rules, 2
 */
static void vsql_m_allocate_descriptor(char *sqlstate, const char *name,
                                       const void *module, long long max) {
  struct vsql_m_connection *c = vsql_m_connection(sqlstate);
  struct vsql_m_descriptor *d;

  if (c == NULL) {
    return;
  }
  c->active = 1;

  /* ISO/IEC 9075-2:2016(E), 20.2, <allocate descriptor statement>, General Rules, 3 */
  if (max < 1 || max > 32767) {
    vsql_m_status(sqlstate, "07009");
    return;
  }

  /* ISO/IEC 9075-2:2016(E), 20.2, <allocate descriptor statement>, General Rules, 4.a */
  if (*vsql_m_find_descriptor(c, name, module) != NULL) {
    vsql_m_status(sqlstate, "33000");
    return;
  }

  /* LEVEL (and every other component) is 0 (zero).
   *
   * ISO/IEC 9075-2:2016(E), 20.2, <allocate descriptor statement>, General Rules, 4.b */
  d = (struct vsql_m_descriptor *)calloc(1, sizeof(struct vsql_m_descriptor));
  if (d != NULL) {
    d->items =
        (struct vsql_m_item *)calloc((size_t)max, sizeof(struct vsql_m_item));
  }
  if (d == NULL || d->items == NULL) {
    free(d);
    vsql_m_status(sqlstate, "HY001");
    return;
  }
  d->module = module;
  d->name = name;
  d->max = (SQLINTEGER)max;
  d->next = c->descriptors;
  c->descriptors = d;
  vsql_m_status(sqlstate, "00000");
}

/* section deallocate_descriptor */
/* ISO/IEC 9075-2:2016(E), 20.3, <deallocate descriptor statement>, General Rules, 1.a and 1.b */
static void vsql_m_deallocate_descriptor(char *sqlstate, const char *name,
                                         const void *module) {
  struct vsql_m_connection *c = vsql_m_connection(sqlstate);
  struct vsql_m_descriptor **d, *next;

  if (c == NULL) {
    return;
  }
  c->active = 1;

  d = vsql_m_find_descriptor(c, name, module);
  if (*d == NULL) {
    vsql_m_status(sqlstate, "33000");
    return;
  }
  next = (*d)->next;
  vsql_m_free_descriptor(*d);
  *d = next;
  vsql_m_status(sqlstate, "00000");
}

/* section get_item */
/*
 * vsql_m_get_item is item descriptor area n for a <get descriptor statement>,
 * or NULL (with the status parameter set). data is the type (a code from Table
 * 28) and length of the target of DATA, or 0 (zero) if DATA isn't retrieved.
 * indicator is 1 if INDICATOR is also retrieved. The targets aren't changed
 * when there's an exception condition.
 *
 * ISO/IEC 9075-2:2016(E), 20.4, <get descriptor statement>, General Rules, 6
 */
static struct vsql_m_item *vsql_m_get_item(char *sqlstate, const char *name,
                                           const void *module, long long n,
                                           SQLSMALLINT data, SQLINTEGER length,
                                           int indicator) {
  struct vsql_m_descriptor *d = vsql_m_descriptor(sqlstate, name, module);
  struct vsql_m_item *item;

  if (d == NULL) {
    return NULL;
  }

  /* ISO/IEC 9075-2:2016(E), 20.4, <get descriptor statement>, General Rules, 2
   */
  if (n < 1 || n > d->max) {
    vsql_m_status(sqlstate, "07009");
    return NULL;
  }

  /* ISO/IEC 9075-2:2016(E), 20.4, <get descriptor statement>, General Rules, 3
   */
  if (n > d->count) {
    vsql_m_status(sqlstate, "02000");
    return NULL;
  }

  item = &d->items[n - 1];
  if (data != 0) {
    /* ISO/IEC 9075-2:2016(E), 20.4, <get descriptor statement>, General Rules, 4 */
    if (!vsql_m_matches(item, data, length, 1)) {
      vsql_m_status(sqlstate, "22005");
      return NULL;
    }

    /* ISO/IEC 9075-2:2016(E), 20.4, <get descriptor statement>, General Rules, 5.c */
    if (item->number[VSQL_M_INDICATOR] < 0 && !indicator) {
      vsql_m_status(sqlstate, "22002");
      return NULL;
    }
  }

  return item;
}

/* section get_data */
/*
 * vsql_m_get_data assigns DATA to the target, which has the data type type and
 * length (in characters, for a string, see vsql_m_put). It isn't assigned
 * when the value is null, or undefined. It returns 1 if a string was
 * truncated.
 *
 * ISO/IEC 9075-2:2016(E), 20.4, <get descriptor statement>, General Rules, 7.b.ii
 */
static int vsql_m_get_data(struct vsql_m_item *item, void *target,
                           SQLSMALLINT type, size_t length) {
  if (item->data == NULL || item->number[VSQL_M_INDICATOR] < 0) {
    return 0;
  }

  switch (type) {
  case SQL_SMALLINT:
    *(short *)target = *(SQLSMALLINT *)item->data;
    return 0;
  case SQL_INTEGER:
    *(long *)target = *(SQLINTEGER *)item->data;
    return 0;
  case SQL_BIGINT:
    *(long long *)target = *(SQLBIGINT *)item->data;
    return 0;
  case SQL_REAL:
    *(float *)target = *(SQLREAL *)item->data;
    return 0;
  case SQL_DOUBLE:
    *(double *)target = *(SQLDOUBLE *)item->data;
    return 0;
  case SQL_BOOLEAN:
    *(long *)target = strcmp((char *)item->data, "TRUE") == 0;
    return 0;
  }

  return vsql_m_put((char *)target, length, type == SQL_CHAR, (char *)item->data);
}

/* section set_count */
/* vsql_m_set_count sets COUNT for a <set descriptor statement>.
 *
 * ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>, General Rules, 6 */
static void vsql_m_set_count(char *sqlstate, const char *name,
                             const void *module, long long count) {
  struct vsql_m_descriptor *d = vsql_m_descriptor(sqlstate, name, module);

  if (d == NULL) {
    return;
  }
  if (count != (SQLINTEGER)count) {
    vsql_m_status(sqlstate, "22003");
    return;
  }
  d->count = (SQLINTEGER)count;
  vsql_m_status(sqlstate, "00000");
}

/* section set_item */
/*
 * vsql_m_set_item is item descriptor area n for a <set descriptor statement>,
 * or NULL (with the status parameter set). Any component that was set before
 * an exception condition keeps its value.
 *
 * ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>, General Rules, 8
 */
static struct vsql_m_item *vsql_m_set_item(char *sqlstate, const char *name,
                                           const void *module, long long n) {
  struct vsql_m_descriptor *d = vsql_m_descriptor(sqlstate, name, module);

  if (d == NULL) {
    return NULL;
  }

  /* ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>, General Rules, 3
   */
  if (n < 1 || n > d->max) {
    vsql_m_status(sqlstate, "07009");
    return NULL;
  }

  return &d->items[n - 1];
}

/* section set_number */
/*
 * vsql_m_set_number sets an exact numeric component of an item descriptor
 * area, after which DATA is undefined. It returns 0 (with the status parameter
 * set) if the value can't be set.
 *
 * ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>, General Rules, 4 and 5.e
 */
static int vsql_m_set_number(char *sqlstate, struct vsql_m_item *item,
                             int component, long long value) {
  SQLINTEGER *number = item->number, level;

  free(item->data);
  item->data = NULL;
  if (value != (SQLINTEGER)value) {
    vsql_m_status(sqlstate, "22003");
    return 0;
  }

  switch (component) {
  case VSQL_M_LEVEL:
    /* vsql doesn't have a ROW, ARRAY or MULTISET, so LEVEL can only be 0
     * (zero) for any item descriptor area.
     *
     * ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>, General Rules, 5.b.i to 5.b.iii */
    if (value != 0) {
      vsql_m_status(sqlstate, "0700E");
      return 0;
    }
    break;
  case VSQL_M_TYPE:
    /* The other components (except LEVEL) are reset to 0 (zero), so SCALE is
     * 0 (zero) and so is the PRECISION of a datetime. The default PRECISION of
     * a NUMERIC or DECIMAL is 18, and of a FLOAT is 53.
     *
     * ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>, General Rules, 5.c.i to 5.c.iii */
    level = number[VSQL_M_LEVEL];
    vsql_m_reset_item(item);
    number[VSQL_M_LEVEL] = level;
    if (value == SQL_CHAR || value == SQL_VARCHAR) {
      number[VSQL_M_LENGTH] = 1;
      vsql_m_copy(&item->string[VSQL_M_CHARACTER_SET_SCHEMA],
                  "INFORMATION_SCHEMA");
      vsql_m_copy(&item->string[VSQL_M_CHARACTER_SET_NAME], "UTF8");
    } else if (value == SQL_NUMERIC || value == SQL_DECIMAL) {
      number[VSQL_M_PRECISION] = 18;
    } else if (value == SQL_FLOAT) {
      number[VSQL_M_PRECISION] = 53;
    }
    break;
  case VSQL_M_DATETIME_INTERVAL_CODE:
    /* vsql doesn't have an INTERVAL.
     *
     * ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>, General Rules, 5.d.i and 5.d.iii */
    if (number[VSQL_M_TYPE] != SQL_DATETIME || value < SQL_CODE_DATE ||
        value > 5) {
      vsql_m_status(sqlstate, "0700F");
      return 0;
    }
    number[VSQL_M_PRECISION] = value == 3 || value == 5 ? 6 : 0;
    break;
  }
  number[component] = (SQLINTEGER)value;

  return 1;
}

/* section set_string */
/* vsql_m_set_string sets a character string component, after which DATA is
 * undefined.
 *
 * ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>, General Rules, 4 and 5.e */
static int vsql_m_set_string(struct vsql_m_item *item, int component,
                             const char *value) {
  free(item->data);
  item->data = NULL;
  vsql_m_copy(&item->string[component], value);

  return 1;
}

/* section set_data */
/*
 * vsql_m_set_data sets DATA to the value of a host parameter, which has the
 * data type type and length (for a string). It returns 0 (with the status
 * parameter set) if it doesn't match the data type of the item: data exception
 * — error in assignment.
 *
 * ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>, General Rules, 5.a.iii and 5.a.iv
 */
static int vsql_m_set_data(char *sqlstate, struct vsql_m_item *item,
                           SQLSMALLINT type, SQLINTEGER length,
                           const void *value) {
  size_t size = 0;

  if (!vsql_m_matches(item, type, length, 0)) {
    vsql_m_status(sqlstate, "22005");
    return 0;
  }

  /* A BOOLEAN is 1 or 0 in C, and 'TRUE' or 'FALSE' in DATA. */
  if (type == SQL_BOOLEAN) {
    value = *(const long *)value ? "TRUE" : "FALSE";
    type = SQL_CHAR;
  }

  switch (type) {
  case SQL_SMALLINT:
    size = sizeof(short);
    break;
  case SQL_INTEGER:
    size = sizeof(long);
    break;
  case SQL_BIGINT:
    size = sizeof(long long);
    break;
  case SQL_REAL:
    size = sizeof(float);
    break;
  case SQL_DOUBLE:
    size = sizeof(double);
    break;
  default:
    size = strlen((const char *)value) + 1;
  }

  free(item->data);
  item->data = malloc(size);
  if (item->data == NULL) {
    vsql_m_status(sqlstate, "HY001");
    return 0;
  }
  memcpy(item->data, value, size);

  return 1;
}
