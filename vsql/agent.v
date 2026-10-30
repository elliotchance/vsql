module vsql

// AgentOptions are the options for new_agent.
@[params]
pub struct AgentOptions {
pub:
	// catalogs are the paths of more files that are attached as catalogs to the
	// default SQL-connection (see Connection.add_catalog).
	catalogs []string
}

// An Agent is an SQL-agent (ISO/IEC 9075-2:2016(E), 4.42), which runs
// <direct SQL statement>s on its SQL-connections, and is how "vsql cli" runs
// statements. Unlike a Connection, it can run the connection statements:
// CONNECT TO, SET CONNECTION and DISCONNECT.
//
// Each SQL-connection is to a different SQL-server (a database file, or a new
// in-memory database), and vsql doesn't support transactions that affect more
// than one SQL-server. So only the current SQL-connection can have an active
// SQL-transaction.
pub struct Agent {
	default_server string
	options        AgentOptions
mut:
	// default_connection is the default SQL-connection, if it's established.
	default_connection &Connection = unsafe { nil }
	// connections are the other SQL-connections, by name.
	connections map[string]&Connection
	// current is the current SQL-connection, if there is one.
	current &Connection = unsafe { nil }
	// connected is true after a connection statement has been run.
	connected bool
pub mut:
	// warnings are the warnings of the last statement.
	warnings []IError
}

// new_agent creates an SQL-agent that doesn't have any SQL-connections yet.
// default_server is the path of the default SQL-server, which is a database
// file or ":memory:". The default SQL-connection is established when a
// statement is run, or with CONNECT TO DEFAULT.
pub fn new_agent(default_server string, options AgentOptions) Agent {
	return Agent{
		default_server: default_server
		options:        options
	}
}

// direct executes a <direct SQL statement> (see Connection.direct) on the
// current SQL-connection, or a connection statement.
pub fn (mut a Agent) direct(sql_stmt string, options DirectOptions) !Result {
	a.warnings = []IError{}

	// A connection statement isn't run on an SQL-connection. Anything else
	// (including a syntax error) is passed to Connection.direct.
	t := start_timer()
	if stmt := parse_connection_statement(sql_stmt) {
		a.connected = true
		elapsed_parse := t.elapsed()
		if stmt is ConnectStatement {
			return stmt.execute(mut a, elapsed_parse)
		}
		if stmt is SetConnectionStatement {
			return stmt.execute(mut a, elapsed_parse)
		}

		return (stmt as DisconnectStatement).execute(mut a, elapsed_parse)
	}

	// - 22.1 GR 2.c.i.
	if a.current == unsafe { nil } {
		if a.connected {
			return sqlstate_08003('there is no current SQL-connection')
		}
		a.connect_default()!
	}

	mut conn := a.current
	conn.clear_warnings()
	result := conn.direct(sql_stmt, options)!
	a.warnings = conn.warnings.clone()

	return result
}

// connect_default makes the default SQL-connection the current SQL-connection,
// and establishes it if needed. This is what happens before the first statement
// that isn't a connection statement (ISO/IEC 9075-2:2016(E), 22.1, General Rules,
// 5.c.i), so it only needs to be called to connect sooner. It doesn't do
// anything if there is already a current SQL-connection.
pub fn (mut a Agent) connect_default() ! {
	if a.current != unsafe { nil } {
		return
	}
	if a.default_connection == unsafe { nil } {
		a.default_connection = a.open_default() or { return sqlstate_08001(err.msg()) }
	}
	a.current = a.default_connection
}

// parse_connection_statement returns the statement if sql_stmt is one
// connection statement that ends with a semicolon.
fn parse_connection_statement(sql_stmt string) ?Stmt {
	statements, rest := split_terminated_statements(sql_stmt)
	if statements.len != 1 || rest != '' {
		return none
	}

	stmt := parse_tokens(tokenize(statements[0]) or { return none }) or { return none }
	if stmt is ConnectStatement || stmt is SetConnectionStatement || stmt is DisconnectStatement {
		return stmt
	}

	return none
}

// in_transaction is true when the current SQL-connection has an active
// SQL-transaction (see Connection.in_transaction).
pub fn (a Agent) in_transaction() bool {
	return a.current != unsafe { nil } && a.current.in_transaction()
}

// close terminates every SQL-connection, which is the end of the SQL-session
// (ISO/IEC 9075-2:2016(E), 22.1, General Rules, 2.a). If commit is true, an
// active SQL-transaction is committed first. Otherwise, it's rolled back.
pub fn (mut a Agent) close(commit bool) ! {
	if commit && a.in_transaction() {
		a.current.query('COMMIT')!
	}

	for conn in a.all_connections() {
		a.disconnect(conn)
	}
}

// all_connections are the default SQL-connection (if it's established) and
// every other SQL-connection.
fn (a Agent) all_connections() []&Connection {
	mut l := []&Connection{}
	if a.default_connection != unsafe { nil } {
		l << a.default_connection
	}
	for _, conn in a.connections {
		l << conn
	}

	return l
}

// open_default establishes an SQL-connection to the default SQL-server.
fn (a Agent) open_default() !&Connection {
	mut conn := open(a.default_server)!
	for catalog in a.options.catalogs {
		conn.add_catalog(catalog_name_from_path(catalog), catalog, default_connection_options())!
	}

	return conn
}

// disconnect terminates an SQL-connection. If it's the current SQL-connection,
// there is no current SQL-connection after.
fn (mut a Agent) disconnect(conn &Connection) {
	mut c := unsafe { conn }
	c.close()

	if voidptr(a.default_connection) == voidptr(conn) {
		a.default_connection = unsafe { nil }
	}
	mut names := []string{}
	for name, other in a.connections {
		if voidptr(other) == voidptr(conn) {
			names << name
		}
	}
	for name in names {
		a.connections.delete(name)
	}
	if voidptr(a.current) == voidptr(conn) {
		a.current = unsafe { nil }
	}
}

// check_multiple_server_transactions raises 0A001 if the current SQL-connection
// is active, since vsql doesn't support transactions that affect more than one
// SQL-server.
fn (a Agent) check_multiple_server_transactions() ! {
	if a.current != unsafe { nil } && a.current.is_active() {
		return sqlstate_0a001()
	}
}
