module vsql

import time

// ISO/IEC 9075-2:2016(E), 18.2, <set connection statement>
//
// Select an SQL-connection from the available SQL-connections.

struct SetConnectionStatement {
	// connection_name is none for DEFAULT.
	connection_name ?ValueSpecification
}

fn (stmt SetConnectionStatement) execute(mut a Agent, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// - GR 1.
	a.check_multiple_server_transactions()!

	// - GR 2, 4, 5.
	a.current = a.connection(stmt.connection_name)!

	return new_result_msg('SET CONNECTION', elapsed_parse, t.elapsed())
}

// connection is the SQL-connection that is identified by a <connection object>,
// which is a <connection name>, or none for DEFAULT.
fn (a Agent) connection(object ?ValueSpecification) !&Connection {
	name := object or {
		if a.default_connection == unsafe { nil } {
			return sqlstate_08003('DEFAULT')
		}

		return a.default_connection
	}

	cn := connection_name(name)!

	return a.connections[cn] or { return sqlstate_08003(cn) }
}
