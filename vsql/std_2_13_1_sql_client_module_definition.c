/* section core */
/*
 * The SQL-agent is the program, and each SQL-connection is a CLI connection.
 * The default SQL-connection has no name. Everything here is static, so it
 * belongs to this module.
 */
struct vsql_m_connection {
  char name[129];
  int is_default;
  SQLHDBC dbc;
  int active;
  struct vsql_m_connection *next;
};

static int vsql_m_ready;
static SQLHENV vsql_m_env;
static struct vsql_m_connection *vsql_m_connections;
static struct vsql_m_connection *vsql_m_current;
static int vsql_m_connected;

static void vsql_m_status(char *sqlstate, const char *code) {
  memcpy(sqlstate, code, 6);
}

/* vsql_m_diag sets the status parameter from a CLI return code. */
static void vsql_m_diag(char *sqlstate, SQLRETURN rc, SQLSMALLINT type,
                        SQLINTEGER handle) {
  if (rc == SQL_SUCCESS) {
    vsql_m_status(sqlstate, "00000");
    return;
  }
  if (rc == SQL_NO_DATA) {
    vsql_m_status(sqlstate, "02000");
    return;
  }

  sqlstate[0] = '\0';
  SQLGetDiagRec(type, handle, 1, (SQLCHAR *)sqlstate, NULL, NULL, 0, NULL);
  if (strlen(sqlstate) != 5) {
    vsql_m_status(sqlstate, rc == SQL_SUCCESS_WITH_INFO ? "01000" : "HY000");
  }
}

static int vsql_m_failed(SQLRETURN rc) {
  return rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO;
}

static void vsql_m_close(struct vsql_m_connection *c) {
  struct vsql_m_connection **p = &vsql_m_connections;

  while (*p != c) {
    p = &(*p)->next;
  }
  *p = c->next;
  if (vsql_m_current == c) {
    vsql_m_current = NULL;
  }

  SQLEndTran(SQL_HANDLE_DBC, c->dbc, SQL_ROLLBACK);
  SQLDisconnect(c->dbc);
  SQLFreeHandle(SQL_HANDLE_DBC, c->dbc);
  free(c);
}

/*
 * 13.1 GR 4: After the last call, a rollback statement is effectively executed
 * and all of the SQL-sessions are terminated. A program that exits without a
 * COMMIT loses its changes.
 */
static void vsql_m_exit(void) {
  while (vsql_m_connections != NULL) {
    vsql_m_close(vsql_m_connections);
  }
  SQLFreeHandle(SQL_HANDLE_ENV, vsql_m_env);
}

/*
 * vsql_m_open makes an SQL-connection to the SQL-server (a file, ":memory:" or
 * "DEFAULT"), with the schema of the module as the default schema.
 */
static struct vsql_m_connection *vsql_m_open(char *sqlstate, const char *server,
                                             const char *user) {
  struct vsql_m_connection *c;
  SQLHSTMT stmt;
  SQLRETURN rc;

  if (!vsql_m_ready) {
    if (vsql_m_failed(
            SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &vsql_m_env))) {
      vsql_m_status(sqlstate, "HY001");
      return NULL;
    }
    vsql_m_ready = 1;
    atexit(vsql_m_exit);
  }

  c = (struct vsql_m_connection *)calloc(1, sizeof(struct vsql_m_connection));
  if (c == NULL) {
    vsql_m_status(sqlstate, "HY001");
    return NULL;
  }
  c->next = vsql_m_connections;
  vsql_m_connections = c;

  rc = SQLAllocHandle(SQL_HANDLE_DBC, vsql_m_env, &c->dbc);
  if (vsql_m_failed(rc)) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_ENV, vsql_m_env);
    vsql_m_connections = c->next;
    free(c);
    return NULL;
  }

  rc = SQLConnect(c->dbc, (SQLCHAR *)server, SQL_NTS, (SQLCHAR *)user,
                  user == NULL ? 0 : SQL_NTS, NULL, 0);
  if (vsql_m_failed(rc)) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_DBC, c->dbc);
    vsql_m_close(c);
    return NULL;
  }

  SQLAllocHandle(SQL_HANDLE_STMT, c->dbc, &stmt);
  rc = SQLExecDirect(stmt, (SQLCHAR *)vsql_m_set_schema, SQL_NTS);
  if (vsql_m_failed(rc)) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_STMT, stmt);
    SQLFreeHandle(SQL_HANDLE_STMT, stmt);
    vsql_m_close(c);
    return NULL;
  }
  SQLFreeHandle(SQL_HANDLE_STMT, stmt);
  SQLEndTran(SQL_HANDLE_DBC, c->dbc, SQL_COMMIT);

  return c;
}

/* section connection */
/*
 * 13.4 GR 7: The SQL-connection for a statement that isn't a connection
 * statement. The default SQL-connection is made when it's needed, unless a
 * connection statement has been executed.
 */
static struct vsql_m_connection *vsql_m_connection(char *sqlstate) {
  if (vsql_m_current != NULL) {
    return vsql_m_current;
  }

  if (vsql_m_connected) {
    vsql_m_status(sqlstate, "08003");
    return NULL;
  }

  vsql_m_current = vsql_m_open(sqlstate, "DEFAULT", NULL);
  if (vsql_m_current != NULL) {
    vsql_m_current->is_default = 1;
  }

  return vsql_m_current;
}

/* section execute */
struct vsql_m_param {
  SQLSMALLINT value_type;
  SQLSMALLINT parameter_type;
  SQLINTEGER length;
  SQLPOINTER value;
  SQLINTEGER indicator;
};

/*
 * vsql_m_execute prepares and executes a statement, with a "?" for each host
 * parameter.
 */
static void vsql_m_execute(char *sqlstate, const char *sql, int n,
                           struct vsql_m_param *params) {
  struct vsql_m_connection *c = vsql_m_connection(sqlstate);
  SQLHSTMT stmt;
  SQLRETURN rc;
  int i;

  if (c == NULL) {
    return;
  }

  rc = SQLAllocHandle(SQL_HANDLE_STMT, c->dbc, &stmt);
  if (vsql_m_failed(rc)) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_DBC, c->dbc);
    return;
  }

  rc = SQLPrepare(stmt, (SQLCHAR *)sql, SQL_NTS);
  for (i = 0; i < n && !vsql_m_failed(rc); i++) {
    rc = SQLBindParameter(stmt, (SQLSMALLINT)(i + 1), SQL_PARAM_MODE_IN,
                          params[i].value_type, params[i].parameter_type,
                          params[i].length, 0, params[i].value, 0,
                          &params[i].indicator);
  }

  /* 13.4 GR 9: The statement initiates an SQL-transaction. */
  if (!vsql_m_failed(rc)) {
    c->active = 1;
    rc = SQLExecute(stmt);
  }

  vsql_m_diag(sqlstate, rc, SQL_HANDLE_STMT, stmt);
  SQLFreeHandle(SQL_HANDLE_STMT, stmt);
}

/* section start */
static void vsql_m_start(char *sqlstate) {
  struct vsql_m_connection *c = vsql_m_connection(sqlstate);
  SQLRETURN rc;

  if (c == NULL) {
    return;
  }

  rc = SQLStartTran(SQL_HANDLE_DBC, c->dbc, SQL_TRANSACTION_READ_WRITE,
                    SQL_TRANSACTION_READ_COMMITTED);
  vsql_m_diag(sqlstate, rc, SQL_HANDLE_DBC, c->dbc);
  if (!vsql_m_failed(rc)) {
    c->active = 1;
  }
}

/* section end */
static void vsql_m_end(char *sqlstate, SQLSMALLINT completion) {
  struct vsql_m_connection *c = vsql_m_connection(sqlstate);

  if (c == NULL) {
    return;
  }

  vsql_m_diag(sqlstate, SQLEndTran(SQL_HANDLE_DBC, c->dbc, completion),
              SQL_HANDLE_DBC, c->dbc);
  c->active = 0;
}

/* section string */
/*
 * 9.3 GR 5.b.iii: A character string host parameter must end with a null
 * character: data exception — unterminated C string.
 */
static int vsql_m_string(char *sqlstate, const char *s, size_t length) {
  if (memchr(s, '\0', length) == NULL) {
    vsql_m_status(sqlstate, "22024");
    return 0;
  }

  return 1;
}

/* section name */
/*
 * vsql_m_name is the connection name (or user name) in s, after leading and
 * trailing spaces are removed. It must be an identifier, which is either
 * delimited ("Name") or upper case (name is NAME). It's empty if it isn't an
 * identifier.
 */
static void vsql_m_name(char *name, const char *s) {
  size_t start = 0, end = strlen(s), i, n = 0;

  while (start < end && s[start] == ' ') {
    start++;
  }
  while (end > start && s[end - 1] == ' ') {
    end--;
  }
  name[0] = '\0';

  if (start < end && s[start] == '"') {
    if (end - start < 3 || s[end - 1] != '"') {
      return;
    }
    for (i = start + 1; i < end - 1; i++) {
      if (n == 128 ||
          (s[i] == '"' && (i + 1 == end - 1 || s[++i] != '"'))) {
        name[0] = '\0';
        return;
      }
      name[n++] = s[i];
    }
  } else {
    for (i = start; i < end; i++) {
      if (n == 128 || !(isalpha((unsigned char)s[i]) || s[i] == '_' ||
                        (i > start && isdigit((unsigned char)s[i])))) {
        name[0] = '\0';
        return;
      }
      name[n++] = (char)toupper((unsigned char)s[i]);
    }
  }
  name[n] = '\0';
}

static struct vsql_m_connection *vsql_m_find(const char *name) {
  struct vsql_m_connection *c;

  for (c = vsql_m_connections; c != NULL; c = c->next) {
    if (!c->is_default && strcmp(c->name, name) == 0) {
      return c;
    }
  }

  return NULL;
}

static struct vsql_m_connection *vsql_m_find_default(void) {
  struct vsql_m_connection *c;

  for (c = vsql_m_connections; c != NULL; c = c->next) {
    if (c->is_default) {
      return c;
    }
  }

  return NULL;
}

/* section switch */
/*
 * 18.1 GR 1, 18.2 GR 1: A connection statement can't be used while there's an
 * active SQL-transaction: feature not supported — multiple server transactions.
 */
static int vsql_m_switch(char *sqlstate) {
  vsql_m_connected = 1;
  if (vsql_m_current != NULL && vsql_m_current->active) {
    vsql_m_status(sqlstate, "0A001");
    return 0;
  }

  return 1;
}

/* section connect */
/* 18.1, <connect statement>. server is NULL for CONNECT TO DEFAULT. */
static void vsql_m_connect(char *sqlstate, const char *server,
                           const char *name, const char *user) {
  struct vsql_m_connection *c;
  char cn[129], user_name[129];

  if (!vsql_m_switch(sqlstate)) {
    return;
  }

  if (server == NULL) {
    if (vsql_m_find_default() != NULL) {
      vsql_m_status(sqlstate, "08002");
      return;
    }
    c = vsql_m_open(sqlstate, "DEFAULT", NULL);
    if (c != NULL) {
      c->is_default = 1;
      vsql_m_current = c;
      vsql_m_status(sqlstate, "00000");
    }
    return;
  }

  /* - 2 to 5. The user name must be an identifier. */
  if (user != NULL) {
    vsql_m_name(user_name, user);
    if (user_name[0] == '\0') {
      vsql_m_status(sqlstate, "28000");
      return;
    }
  }

  /* - 6, 7. The connection name is the server name if there's no AS. */
  vsql_m_name(cn, name == NULL ? server : name);
  if (cn[0] == '\0') {
    vsql_m_status(sqlstate, "2E000");
    return;
  }
  if (vsql_m_find(cn) != NULL) {
    vsql_m_status(sqlstate, "08002");
    return;
  }

  c = vsql_m_open(sqlstate, server, user);
  if (c != NULL) {
    strcpy(c->name, cn);
    vsql_m_current = c;
    vsql_m_status(sqlstate, "00000");
  }
}

/* section set_connection */
/* 18.2, <set connection statement>. name is NULL for DEFAULT. */
static void vsql_m_set_connection(char *sqlstate, const char *name) {
  struct vsql_m_connection *c;
  char cn[129];

  if (!vsql_m_switch(sqlstate)) {
    return;
  }

  if (name == NULL) {
    c = vsql_m_find_default();
  } else {
    vsql_m_name(cn, name);
    if (cn[0] == '\0') {
      vsql_m_status(sqlstate, "2E000");
      return;
    }
    c = vsql_m_find(cn);
  }

  if (c == NULL) {
    vsql_m_status(sqlstate, "08003");
    return;
  }

  vsql_m_current = c;
  vsql_m_status(sqlstate, "00000");
}

/* section disconnect */
/*
 * 18.3, <disconnect statement>. which is 'n' for a name, 'D' for DEFAULT, 'A'
 * for ALL or 'C' for CURRENT.
 */
static void vsql_m_disconnect(char *sqlstate, char which, const char *name) {
  struct vsql_m_connection *c = NULL, *next;
  char cn[129];

  vsql_m_connected = 1;
  if (which == 'n') {
    vsql_m_name(cn, name);
    if (cn[0] == '\0') {
      vsql_m_status(sqlstate, "2E000");
      return;
    }
    c = vsql_m_find(cn);
  } else if (which == 'D') {
    c = vsql_m_find_default();
  } else if (which == 'C') {
    c = vsql_m_current;
  }

  if (which != 'A' && c == NULL) {
    vsql_m_status(sqlstate, "08003");
    return;
  }

  /* - 4. None of the SQL-connections can be active: invalid transaction state
   * — active SQL-transaction. */
  for (next = vsql_m_connections; next != NULL; next = next->next) {
    if ((which == 'A' || next == c) && next->active) {
      vsql_m_status(sqlstate, "25001");
      return;
    }
  }

  if (which == 'A') {
    while (vsql_m_connections != NULL) {
      vsql_m_close(vsql_m_connections);
    }
  } else {
    vsql_m_close(c);
  }
  vsql_m_status(sqlstate, "00000");
}
