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
	// ISO/IEC 9075-3:2003(E), 6.16, Disconnect, General Rules, 1
	mut dbc := dbcs[h] or { return sql_invalid_handle }
	dbc.diag.clear()

	return disconnect(mut dbc, h) or { dbc.diag.error(err) }
}

fn disconnect(mut dbc Dbc, h i64) !i16 {
	// ISO/IEC 9075-3:2003(E), 6.16, Disconnect, General Rules, 2: the
	// connection must be established.
	mut conn := dbc.conn or { return cli_error('08003', 'connection does not exist') }

	// ISO/IEC 9075-3:2003(E), 6.16, Disconnect, General Rules, 3 and 4.a: no
	// statement can have a deferred parameter number. This is checked even
	// when there isn't an active SQL-transaction, which is #729.
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

	// ISO/IEC 9075-3:2003(E), 6.16, Disconnect, General Rules, 4.b: there
	// can't be an active SQL-transaction.
	if conn.in_transaction() {
		return cli_error('25001', 'active SQL-transaction')
	}

	// ISO/IEC 9075-3:2003(E), 6.16, Disconnect, General Rules, 5 and 6: every
	// allocated SQL-statement and CLI descriptor area is freed.
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

	// ISO/IEC 9075-3:2003(E), 6.16, Disconnect, General Rules, 8
	db_close(mut conn)
	dbc.conn = none
	dbc.is_default = false

	// ISO/IEC 9075-3:2003(E), 6.16, Disconnect, General Rules, 7 and 10: if it
	// was the current SQL-connection, there's no longer a current one.
	if current_connection(dbc.env) == h {
		set_current_connection(dbc.env, 0)
	}

	return sql_success
}
