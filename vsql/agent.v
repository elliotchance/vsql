module vsql

// The concepts are described by:
//
// ISO/IEC 9075-1:2003(E), 4.2, SQL-environments and their components
// ISO/IEC 9075-1:2003(E), 4.2.1, SQL-environments
// ISO/IEC 9075-1:2003(E), 4.2.2, SQL-agents
// ISO/IEC 9075-1:2003(E), 4.2.3.1, SQL-clients

// AgentOptions are the options for new_agent.
@[params]
pub struct AgentOptions {
pub:
	// catalogs are the paths of more files that are attached as catalogs to the
	// default SQL-connection (see Connection.add_catalog).
	catalogs []string
}

// An Agent is an SQL-agent, which runs <direct SQL statement>s on its
// SQL-connections, and is how "vsql cli" runs statements. Unlike a Connection,
// it can run the connection statements: CONNECT TO, SET CONNECTION and
// DISCONNECT. The SQL-connections that aren't current are dormant, and each
// keeps its own SQL-session context.
//
// Each SQL-connection is to a different SQL-server (a database file, or a new
// in-memory database). An SQL-transaction can affect more than one SQL-server
// (T262): the part of it on each SQL-connection is a branch, which is started
// with the same characteristics (unless SET LOCAL TRANSACTION changes them), and
// a COMMIT or ROLLBACK on any of them ends every branch.
//
// ISO/IEC 9075-2:2023, 4.43.7.2, Encompassing transaction belonging to the SQL-agent
pub struct Agent {
	// ISO/IEC 9075-2:2023, 4.44, SQL-connections
	// ISO/IEC 9075-2:2023, 18.1, <connect statement>, General Rules, 9.a
	// ISO/IEC 9075-2:2023, 18.2, <set connection statement>, General Rules, 4
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
	// (including a syntax error) is passed to Connection.direct. The warnings
	// are emptied first, and are the diagnostics of this statement after.
	//
	// ISO/IEC 9075-2:2023, 22.1, <direct SQL statement>, General Rules, 6.b; ISO/IEC 9075-2:2023, 9.17, Executing an <SQL procedure statement>, General Rules, 7 and 22
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

	// A statement after a connection statement doesn't connect to the default
	// SQL-server again, since it was made dormant or disconnected.
	//
	// ISO/IEC 9075-2:2023, 22.1, <direct SQL statement>, General Rules, 6.b.ii
	if a.current == unsafe { nil } {
		if a.connected {
			return sqlstate_08003('there is no current SQL-connection')
		}
		a.connect_default()!
	}

	mut conn := a.current
	conn.clear_warnings()
	conn.branch_of = a.active_transaction(conn)

	// A COMMIT or ROLLBACK ends every branch of the SQL-transaction.
	if conn.branch_of != none || conn.is_active() {
		if stmt := parse_transaction_end(sql_stmt) {
			if a.active_branches(conn).len > 0 {
				result := a.end_transaction(stmt, sql_stmt, options)!
				a.warnings = conn.warnings.clone()
				return result
			}
		}
	}

	was_active := conn.is_active()
	result := conn.direct(sql_stmt, options) or {
		a.warnings = conn.warnings.clone()
		// An error that rolled back the branch (such as a serialization
		// failure) rolls back the whole SQL-transaction.
		if was_active && !conn.is_active() {
			a.rollback_branches(conn)
		}
		return err
	}
	a.warnings = conn.warnings.clone()

	return result
}

// active_transaction is the characteristics of the SQL-transaction when it's
// active on an SQL-connection other than conn, so that a transaction of conn
// is a branch of it.
fn (a Agent) active_transaction(conn &Connection) ?TransactionCharacteristics {
	for other in a.active_branches(conn) {
		return other.current_characteristics()
	}

	return none
}

// active_branches are the SQL-connections other than conn that have an active
// branch of the SQL-transaction.
fn (a Agent) active_branches(conn &Connection) []&Connection {
	return a.all_connections().filter(voidptr(it) != voidptr(conn) && it.is_active())
}

// parse_transaction_end returns the statement if sql_stmt is one COMMIT, or
// one ROLLBACK that isn't TO SAVEPOINT.
fn parse_transaction_end(sql_stmt string) ?Stmt {
	statements, rest := split_terminated_statements(sql_stmt)
	if statements.len != 1 || rest != '' {
		return none
	}

	stmt := parse_tokens(tokenize(statements[0]) or { return none }) or { return none }
	if stmt is CommitStatement || (stmt is RollbackStatement && stmt.savepoint == '') {
		return stmt
	}

	return none
}

// end_transaction ends every branch of the SQL-transaction with a COMMIT or
// ROLLBACK (with or without AND CHAIN) that's run on the current
// SQL-connection.
//
// For a COMMIT, the deferred constraints of the other branches are checked
// first, so that if any of them aren't satisfied, every branch is rolled back,
// like the COMMIT of one SQL-connection. Then the current branch is committed,
// and the others after it. Committing more than one SQL-server isn't atomic: if
// committing one of the others fails (which can only be because of the
// SQL-server, such as a disk error), the branches before it stay committed.
//
// ISO/IEC 9075-2:2023, 17.7, <commit statement>, General Rules, 10.a
// ISO/IEC 9075-2:2023, 17.8, <rollback statement>, General Rules, 2.h.i
fn (mut a Agent) end_transaction(stmt Stmt, sql_stmt string, options DirectOptions) !Result {
	mut current := a.current
	mut others := a.active_branches(current)
	chain := if stmt is CommitStatement { stmt.chain } else { (stmt as RollbackStatement).chain }
	end := if stmt is CommitStatement { 'COMMIT' } else { 'ROLLBACK' } + if chain {
		' AND CHAIN'
	} else {
		''
	}

	if stmt is CommitStatement {
		for mut other in others {
			other.query('SET CONSTRAINTS ALL IMMEDIATE') or {
				a.rollback_branches(unsafe { nil })
				return err
			}
		}
	}

	result := current.direct(sql_stmt, options) or {
		a.rollback_branches(current)
		return err
	}
	for mut other in others {
		other.query(end)!
	}

	return result
}

// rollback_branches rolls back every branch of the SQL-transaction other than
// except, which may be nil.
fn (mut a Agent) rollback_branches(except &Connection) {
	for mut other in a.active_branches(except) {
		other.query('ROLLBACK') or {}
	}
}

// connect_default makes the default SQL-connection the current SQL-connection,
// and establishes it if needed. This is what happens before the first statement
// that isn't a connection statement, so it only needs to be called to connect
// sooner. It doesn't do anything if there is already a current SQL-connection.
pub fn (mut a Agent) connect_default() ! {
	// ISO/IEC 9075-2:2023, 9.17, Executing an <SQL procedure statement>, General Rules, 8.a and 8.b
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

// in_transaction is true when any SQL-connection has an active branch of the
// SQL-transaction (see Connection.in_transaction).
pub fn (a Agent) in_transaction() bool {
	return a.all_connections().any(it.in_transaction())
}

// close terminates every SQL-connection, which is the end of the SQL-session.
// If commit is true, an active SQL-transaction is committed first (and if a
// deferred constraint isn't satisfied, it's rolled back). Otherwise, it's
// rolled back.
pub fn (mut a Agent) close(commit bool) ! {
	// ISO/IEC 9075-2:2023, 22.1, <direct SQL statement>, General Rules, 3.a and 3.c
	if commit && a.in_transaction() {
		if a.current == unsafe { nil } {
			a.connect_default()!
		}
		a.direct('COMMIT;')!
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
//
// ISO/IEC 9075-2:2023, 18.3, <disconnect statement>, General Rules, 7 and 9
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
