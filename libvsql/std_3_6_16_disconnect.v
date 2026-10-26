module main

// ISO/IEC 9075-3:2003(E), 6.16, Disconnect
//
// Terminate an established connection.

@[export: 'SQLDisconnect']
fn sql_disconnect(connection_handle SQLInteger) i16 {
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
	conn.close()
	dbc.conn = none
	dbc.is_default = false

	return sql_success
}
