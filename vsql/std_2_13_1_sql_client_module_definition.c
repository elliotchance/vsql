/* section core */
/*
 * The SQL-agent is the program, and each SQL-connection is a CLI connection.
 * The default SQL-connection has no name.
 */
struct vsql_m_connection {
  char name[129];
  char *server;
  int is_default;
  SQLHDBC dbc;
  int active;
  /* The module whose schema is the default schema, see vsql_m_schema. */
  const void *module;
  struct vsql_m_cursors *cursors;
  struct vsql_m_connection *next;
};

/* The CLI statement of each cursor of a module that has been opened in an
 * SQL-connection (see 14.1). */
struct vsql_m_cursors {
  const void *module;
  SQLHSTMT *stmts;
  int n;
  struct vsql_m_cursors *next;
};

static int vsql_m_failed(SQLRETURN rc) {
  return rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO;
}

/*
 * The first diagnostics area, that a <get diagnostics statement> (23.1) reads.
 * Every other statement empties it (13.4 GR 6), and then it has the conditions
 * that the statement raised. A condition is either copied from the diagnostics
 * area that libvsql keeps for a handle, or raised by this runtime. A string is
 * NULL if there wasn't enough memory for it.
 */
struct vsql_m_condition {
  char sqlstate[6];
  char *message;
};

/* The <statement information item name>s that aren't in libvsql.h. */
#define VSQL_M_COMMAND_FUNCTION (-1)
#define VSQL_M_COMMAND_FUNCTION_CODE (-2)

struct vsql_m_da {
  char command_function[32];
  SQLINTEGER command_function_code;
  SQLINTEGER row_count;
  int transactions_committed;
  int transactions_rolled_back;
  int number;
  struct vsql_m_condition *conditions;
  char connection_name[129];
  char *server_name;
};

/*
 * Feature F181, "Multiple module support": Every module that's linked into the
 * program has the same SQL-agent, so they share the SQL-connections (and their
 * SQL-transactions) and the first diagnostics area. The first module that's
 * called keeps it, and the others find it with vsql_module_agent. A module that
 * was compiled with a different version of this struct has its own.
 */
#define VSQL_M_AGENT_VERSION 1

struct vsql_m_agent {
  int version;
  int ready;
  SQLHENV env;
  struct vsql_m_connection *connections;
  struct vsql_m_connection *current;
  int connected;
  struct vsql_m_da da;
};

static struct vsql_m_agent vsql_m_own, *vsql_m_a;

static struct vsql_m_agent *vsql_m_agent(void) {
  void **shared;

  if (vsql_m_a == NULL) {
    vsql_m_own.version = VSQL_M_AGENT_VERSION;
    shared = vsql_module_agent();
    if (*shared == NULL) {
      *shared = &vsql_m_own;
    }
    vsql_m_a = (struct vsql_m_agent *)*shared;
    if (vsql_m_a->version != VSQL_M_AGENT_VERSION) {
      vsql_m_a = &vsql_m_own;
    }
  }

  return vsql_m_a;
}

#define vsql_m_ready (vsql_m_agent()->ready)
#define vsql_m_env (vsql_m_agent()->env)
#define vsql_m_connections (vsql_m_agent()->connections)
#define vsql_m_current (vsql_m_agent()->current)
#define vsql_m_connected (vsql_m_agent()->connected)
#define vsql_m_da (vsql_m_agent()->da)

/* vsql_m_copy replaces the string in *s with a copy of value. */
static void vsql_m_copy(char **s, const char *value) {
  free(*s);
  *s = (char *)malloc(strlen(value) + 1);
  if (*s != NULL) {
    strcpy(*s, value);
  }
}

static void vsql_m_clear(void) {
  int i;

  for (i = 0; i < vsql_m_da.number; i++) {
    free(vsql_m_da.conditions[i].message);
  }
  free(vsql_m_da.conditions);
  vsql_m_da.conditions = NULL;
  vsql_m_da.number = 0;
}

/*
 * vsql_m_begin empties the first diagnostics area before a statement. The
 * COMMAND_FUNCTION of a statement that libvsql executes is empty, since it's
 * the DYNAMIC_FUNCTION that libvsql gives it.
 */
static void vsql_m_begin(const char *command_function, SQLINTEGER code) {
  vsql_m_clear();
  strcpy(vsql_m_da.command_function, command_function);
  vsql_m_da.command_function_code = code;
  vsql_m_da.row_count = 0;
  vsql_m_da.transactions_committed = 0;
  vsql_m_da.transactions_rolled_back = 0;
}

/*
 * vsql_m_raise adds a condition to the first diagnostics area. The
 * CONNECTION_NAME and SERVER_NAME are of the current SQL-connection (23.1 GR
 * 4.p.ii). The default SQL-connection is named DEFAULT.
 */
static void vsql_m_raise(const char *sqlstate, const char *message) {
  struct vsql_m_condition *conditions = (struct vsql_m_condition *)realloc(
      vsql_m_da.conditions,
      (size_t)(vsql_m_da.number + 1) * sizeof(struct vsql_m_condition));

  if (conditions == NULL) {
    return;
  }
  vsql_m_da.conditions = conditions;
  memcpy(conditions[vsql_m_da.number].sqlstate, sqlstate, 5);
  conditions[vsql_m_da.number].sqlstate[5] = '\0';
  conditions[vsql_m_da.number].message = NULL;
  vsql_m_copy(&conditions[vsql_m_da.number].message, message);
  vsql_m_da.number++;

  if (vsql_m_current == NULL) {
    vsql_m_da.connection_name[0] = '\0';
    vsql_m_copy(&vsql_m_da.server_name, "");
  } else {
    strcpy(vsql_m_da.connection_name,
           vsql_m_current->is_default ? "DEFAULT" : vsql_m_current->name);
    vsql_m_copy(&vsql_m_da.server_name,
                vsql_m_current->server == NULL ? "" : vsql_m_current->server);
  }
}

/* vsql_m_message is the message text of a condition that this runtime raises.
 */
static const char *vsql_m_message(const char *sqlstate) {
  static const char *const messages[][2] = {
      {"01000", "warning"},
      {"01004", "warning: string data, right truncation"},
      {"02000", "no data"},
      {"07002", "dynamic SQL error: using clause does not match target "
                "specifications"},
      {"08002", "connection exception: connection name in use"},
      {"08003", "connection exception: connection does not exist"},
      {"0A001", "feature not supported: multiple server transactions"},
      {"21000", "cardinality violation"},
      {"22024", "data exception: unterminated C string"},
      {"25001", "invalid transaction state: active SQL-transaction"},
      {"28000", "invalid authorization specification"},
      {"2E000", "invalid connection name"},
      {"HY000", "CLI-specific condition: general error"},
      {"HY001", "CLI-specific condition: memory allocation error"}};
  size_t i;

  for (i = 0; i < sizeof(messages) / sizeof(messages[0]); i++) {
    if (strcmp(messages[i][0], sqlstate) == 0) {
      return messages[i][1];
    }
  }

  return "";
}

/* vsql_m_sqlstate sets the status parameter, without changing the first
 * diagnostics area. */
static void vsql_m_sqlstate(char *sqlstate, const char *code) {
  memcpy(sqlstate, code, 6);
}

/* vsql_m_status sets the status parameter for a condition that this runtime
 * raises, which is the only condition in the first diagnostics area. */
static void vsql_m_status(char *sqlstate, const char *code) {
  vsql_m_sqlstate(sqlstate, code);
  vsql_m_clear();
  if (strcmp(code, "00000") != 0) {
    vsql_m_raise(code, vsql_m_message(code));
  }
}

/*
 * vsql_m_diag sets the status parameter from a CLI return code, and copies the
 * conditions in the diagnostics area of the handle to the first diagnostics
 * area.
 */
static void vsql_m_diag(char *sqlstate, SQLRETURN rc, SQLSMALLINT type,
                        SQLINTEGER handle) {
  SQLINTEGER number = 0, i, length;
  char state[6], *message;

  if (rc == SQL_SUCCESS) {
    vsql_m_status(sqlstate, "00000");
    return;
  }
  if (rc == SQL_NO_DATA) {
    vsql_m_status(sqlstate, "02000");
    return;
  }

  vsql_m_clear();
  SQLGetDiagField(type, handle, 0, SQL_DIAG_NUMBER, &number, 0, NULL);
  for (i = 1; i <= number; i++) {
    length = 0;
    SQLGetDiagField(type, handle, (SQLSMALLINT)i, SQL_DIAG_MESSAGE_OCTET_LENGTH,
                    &length, 0, NULL);
    if (vsql_m_failed(SQLGetDiagRec(type, handle, (SQLSMALLINT)i,
                                    (SQLCHAR *)state, NULL, NULL, 0, NULL))) {
      break;
    }
    message = (char *)malloc((size_t)length + 1);
    if (message != NULL) {
      SQLGetDiagRec(type, handle, (SQLSMALLINT)i, (SQLCHAR *)state, NULL,
                    (SQLCHAR *)message, (SQLSMALLINT)(length + 1), NULL);
    }
    vsql_m_raise(state, message == NULL ? "" : message);
    free(message);
  }

  if (vsql_m_da.number > 0) {
    vsql_m_sqlstate(sqlstate, vsql_m_da.conditions[0].sqlstate);
  } else {
    vsql_m_status(sqlstate, rc == SQL_SUCCESS_WITH_INFO ? "01000" : "HY000");
  }
}

static void vsql_m_close(struct vsql_m_connection *c) {
  struct vsql_m_connection **p = &vsql_m_connections;
  struct vsql_m_cursors *m;
  int i;

  while (*p != c) {
    p = &(*p)->next;
  }
  *p = c->next;
  if (vsql_m_current == c) {
    vsql_m_current = NULL;
  }

  SQLEndTran(SQL_HANDLE_DBC, c->dbc, SQL_ROLLBACK);
  while (c->cursors != NULL) {
    m = c->cursors;
    for (i = 0; i < m->n; i++) {
      if (m->stmts[i] != 0) {
        SQLFreeHandle(SQL_HANDLE_STMT, m->stmts[i]);
      }
    }
    c->cursors = m->next;
    free(m->stmts);
    free(m);
  }
  SQLDisconnect(c->dbc);
  SQLFreeHandle(SQL_HANDLE_DBC, c->dbc);
  free(c->server);
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
  vsql_m_ready = 0;
  vsql_m_clear();
  free(vsql_m_da.server_name);
}

/*
 * vsql_m_schema makes the schema of this module the default schema of the
 * SQL-connection c, unless it already is. When modules share an SQL-connection
 * the default schema is set again for each statement of a different module, so
 * a SET SCHEMA only lasts until then. It returns 0 (with the status parameter
 * set) if it fails.
 */
static int vsql_m_schema(char *sqlstate, struct vsql_m_connection *c) {
  SQLHSTMT stmt;
  SQLRETURN rc;

  if (c->module == &vsql_m_own) {
    return 1;
  }

  rc = SQLAllocHandle(SQL_HANDLE_STMT, c->dbc, &stmt);
  if (vsql_m_failed(rc)) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_DBC, c->dbc);
    return 0;
  }
  rc = SQLExecDirect(stmt, (SQLCHAR *)vsql_m_set_schema, SQL_NTS);
  if (vsql_m_failed(rc)) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_STMT, stmt);
    SQLFreeHandle(SQL_HANDLE_STMT, stmt);
    return 0;
  }
  SQLFreeHandle(SQL_HANDLE_STMT, stmt);
  if (!c->active) {
    SQLEndTran(SQL_HANDLE_DBC, c->dbc, SQL_COMMIT);
  }
  c->module = &vsql_m_own;

  return 1;
}

/*
 * vsql_m_open makes an SQL-connection to the SQL-server (a file, ":memory:" or
 * "DEFAULT"), with the schema of the module as the default schema.
 */
static struct vsql_m_connection *vsql_m_open(char *sqlstate, const char *server,
                                             const char *user) {
  struct vsql_m_connection *c;
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
  vsql_m_copy(&c->server, server);

  rc = SQLAllocHandle(SQL_HANDLE_DBC, vsql_m_env, &c->dbc);
  if (vsql_m_failed(rc)) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_ENV, vsql_m_env);
    vsql_m_connections = c->next;
    free(c->server);
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

  if (!vsql_m_schema(sqlstate, c)) {
    vsql_m_close(c);
    return NULL;
  }

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
    return vsql_m_schema(sqlstate, vsql_m_current) ? vsql_m_current : NULL;
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

/* section exec */
struct vsql_m_param {
  SQLSMALLINT value_type;
  SQLSMALLINT parameter_type;
  SQLINTEGER length;
  SQLPOINTER value;
  SQLINTEGER indicator;
};

/*
 * vsql_m_exec prepares and executes a statement on stmt (of the SQL-connection
 * c), with a "?" for each host parameter. It returns 0 (with the status
 * parameter set) if it fails.
 */
static int vsql_m_exec(char *sqlstate, struct vsql_m_connection *c,
                       SQLHSTMT stmt, const char *sql, int n,
                       struct vsql_m_param *params) {
  SQLRETURN rc;
  int i;

  rc = SQLPrepare(stmt, (SQLCHAR *)sql, SQL_NTS);
  if (vsql_m_da.command_function[0] == '\0') {
    SQLGetDiagField(SQL_HANDLE_STMT, stmt, 0, SQL_DIAG_DYNAMIC_FUNCTION,
                    vsql_m_da.command_function,
                    sizeof(vsql_m_da.command_function), NULL);
    SQLGetDiagField(SQL_HANDLE_STMT, stmt, 0, SQL_DIAG_DYNAMIC_FUNCTION_CODE,
                    &vsql_m_da.command_function_code, 0, NULL);
  }
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
  if (!vsql_m_failed(rc)) {
    SQLGetDiagField(SQL_HANDLE_STMT, stmt, 0, SQL_DIAG_ROW_COUNT,
                    &vsql_m_da.row_count, 0, NULL);
  }

  vsql_m_diag(sqlstate, rc, SQL_HANDLE_STMT, stmt);

  return !vsql_m_failed(rc);
}

/* section run */
/*
 * vsql_m_run prepares and executes a statement, with a "?" for each host
 * parameter. It returns 0 (with the status parameter set) if it fails,
 * otherwise the statement must be freed.
 */
static int vsql_m_run(char *sqlstate, const char *sql, int n,
                      struct vsql_m_param *params, SQLHSTMT *stmt) {
  struct vsql_m_connection *c = vsql_m_connection(sqlstate);
  SQLRETURN rc;

  if (c == NULL) {
    return 0;
  }

  rc = SQLAllocHandle(SQL_HANDLE_STMT, c->dbc, stmt);
  if (vsql_m_failed(rc)) {
    vsql_m_diag(sqlstate, rc, SQL_HANDLE_DBC, c->dbc);
    return 0;
  }

  if (!vsql_m_exec(sqlstate, c, *stmt, sql, n, params)) {
    SQLFreeHandle(SQL_HANDLE_STMT, *stmt);
    return 0;
  }

  return 1;
}

/* section execute */
static void vsql_m_execute(char *sqlstate, const char *sql, int n,
                           struct vsql_m_param *params) {
  SQLHSTMT stmt;

  if (vsql_m_run(sqlstate, sql, n, params, &stmt)) {
    SQLFreeHandle(SQL_HANDLE_STMT, stmt);
  }
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
  SQLRETURN rc;

  if (c == NULL) {
    return;
  }

  rc = SQLEndTran(SQL_HANDLE_DBC, c->dbc, completion);
  vsql_m_diag(sqlstate, rc, SQL_HANDLE_DBC, c->dbc);

  /* A commit that fails with transaction rollback rolls back. */
  if (c->active && completion == SQL_COMMIT && !vsql_m_failed(rc)) {
    vsql_m_da.transactions_committed = 1;
  } else if (c->active &&
             (completion == SQL_ROLLBACK || strncmp(sqlstate, "40", 2) == 0)) {
    vsql_m_da.transactions_rolled_back = 1;
  }
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
