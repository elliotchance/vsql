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

// current_connection is the handle of the current SQL-connection, or 0 if there
// isn't one. There's one for the SQL-agent (the application), not one for each
// SQL-environment.
__global current_connection = i64(0)

fn implicit_set_connection(dc i64) ! {
	if dc == current_connection {
		return
	}

	// - 2. If an SQL-transaction is active for the current SQL-connection and
	// the SQL-implementation does not support transactions that affect more
	// than one SQL-server, then an exception condition is raised: feature not
	// supported — multiple server transactions.
	if current_connection != 0 && transaction_active(sql_handle_dbc, current_connection) {
		return cli_error('0A001', 'multiple server transactions')
	}

	// - 4, 5. The current SQL-connection becomes dormant, and DC becomes the
	// current SQL-connection.
	current_connection = dc
}
