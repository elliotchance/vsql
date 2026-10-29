module main

// ISO/IEC 9075-3:2003(E), 6.16, Disconnect
//
// Terminate an established connection.

@[export: 'SQLDisconnect']
fn sql_disconnect(connection_handle SQLInteger) i16 {
	entry := enter(sql_handle_dbc, i64(connection_handle))
	defer {
		entry.leave()
	}
	h := i64(connection_handle)
	mut dbc := dbcs[h] or { return sql_invalid_handle }
	dbc.diag.clear()

	return disconnect(mut dbc, h) or { dbc.diag.error(err) }
}

fn disconnect(mut dbc Dbc, h i64) !i16 {
	// - 2.a. If there is no established SQL-connection associated with C, then
	// an exception condition is raised: connection exception — connection does
	// not exist.
	mut conn := dbc.conn or { return cli_error('08003', 'connection does not exist') }

	// - 4.a. If any statement has a deferred parameter number, then an
	// exception condition is raised: CLI-specific condition — function sequence
	// error.
	for _, stmt in stmts {
		if stmt.dbc == h {
			stmt.check_deferred()!
		}
	}

	// An SQL-transaction that's only active because of an open cursor is
	// committed when AUTOCOMMIT is on (see autocommit.v).
	if dbc.autocommit_transaction && conn.in_transaction() {
		close_cursors(h, false)
		autocommit(mut dbc.diag, h, true)!
	}

	// - 4.b. If EC is active, then an exception condition is raised: invalid
	// transaction state — active SQL-transaction.
	if conn.in_transaction() {
		return cli_error('25001', 'active SQL-transaction')
	}

	// - 5, 6. FreeHandle is implicitly invoked for every allocated
	// SQL-statement and CLI descriptor area.
	mut statements := []i64{}
	for sh, stmt in stmts {
		if stmt.dbc == h {
			statements << sh
		}
	}
	for sh in statements {
		free_stmt(sh)
	}
	mut descriptors := []i64{}
	for dh, desc in descs {
		if desc.dbc == h {
			descriptors << dh
		}
	}
	for dh in descriptors {
		free_desc(dh)
	}

	// - 8. The SQL-session associated with EC is terminated.
	db_close(mut conn)
	dbc.conn = none
	dbc.is_default = false

	// - 10. If EC and CC were the same SQL-connection, then there is no current
	// SQL-connection. Otherwise, CC remains the current SQL-connection.
	if current_connection(dbc.env) == h {
		set_current_connection(dbc.env, 0)
	}

	return sql_success
}
