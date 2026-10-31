module vsql

import time

// ISO/IEC 9075-2:2016(E), 18.3, <disconnect statement>
//
// Terminate an SQL-connection.
//
// Closing an SQL-connection doesn't report errors, so there's never a 01002
// warning (disconnect error).
//
// ISO/IEC 9075-2:2016(E), 18.3, <disconnect statement>, General Rules, 8

struct DisconnectStatement {
	// connection_name is none for DEFAULT, unless it's ALL or CURRENT.
	connection_name ?ValueSpecification
	all             bool
	current         bool
}

fn (stmt DisconnectStatement) execute(mut a Agent, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// ISO/IEC 9075-2:2016(E), 18.3, <disconnect statement>, General Rules, 1 to 3 and 5
	mut l := []&Connection{}
	if stmt.all {
		l = a.all_connections()
	} else if stmt.current {
		if a.current == unsafe { nil } {
			return sqlstate_08003('CURRENT')
		}
		l << a.current
	} else {
		l << a.connection(stmt.connection_name)!
	}

	// ISO/IEC 9075-2:2016(E), 18.3, <disconnect statement>, General Rules, 6
	for conn in l {
		if conn.is_active() {
			return sqlstate_25001()
		}
	}

	// ISO/IEC 9075-2:2016(E), 18.3, <disconnect statement>, General Rules, 7 and 9
	for conn in l {
		a.disconnect(conn)
	}

	return new_result_msg('DISCONNECT', elapsed_parse, t.elapsed())
}
