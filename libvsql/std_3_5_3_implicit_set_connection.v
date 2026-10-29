module main

// ISO/IEC 9075-3:2003(E), 5.3, Implicit set connection
//
// Specify the rules for an implicit SET CONNECTION statement.
//
// Each SQL-connection is to a different SQL-server (a database file, or a new
// in-memory database), and vsql doesn't support transactions that affect more
// than one SQL-server. So only the current SQL-connection can have an active
// SQL-transaction, and switching to another connection while it does is an
// exception condition.

// Each SQL-environment is its own SQL-agent, with its own current
// SQL-connection (Env.current_connection), so connections that are allocated in
// different SQL-environments can each have an active SQL-transaction, and can be
// used from different threads at the same time.

// current_connection is the handle of the current SQL-connection of an
// SQL-environment, or 0 if there isn't one.
fn current_connection(env i64) i64 {
	return (envs[env] or { return 0 }).current_connection
}

fn set_current_connection(env i64, dc i64) {
	mut e := envs[env] or { return }
	e.current_connection = dc
}

fn implicit_set_connection(dc i64) ! {
	env := (dbcs[dc] or { return }).env
	current := current_connection(env)
	if dc == current {
		return
	}

	// - 2. If an SQL-transaction is active for the current SQL-connection and
	// the SQL-implementation does not support transactions that affect more
	// than one SQL-server, then an exception condition is raised: feature not
	// supported — multiple server transactions.
	if current != 0 && transaction_active(sql_handle_dbc, current) {
		return cli_error('0A001', 'multiple server transactions')
	}

	// - 4, 5. The current SQL-connection becomes dormant, and DC becomes the
	// current SQL-connection.
	set_current_connection(env, dc)
}
