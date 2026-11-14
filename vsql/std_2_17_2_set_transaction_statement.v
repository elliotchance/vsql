module vsql

import time

// ISO/IEC 9075-2:2023(E), 17.2, <set transaction statement>
//
// Set the characteristics of the next SQL-transaction for the SQL-agent.
//
// LOCAL (Feature T251) sets the characteristics of the branch of a transaction
// on this SQL-server. vsql doesn't have transactions that are on more than one
// SQL-server, so it's always 0A001, which is before anything else that LOCAL does.

struct SetTransactionStatement {
	modes []TransactionMode
	local bool
}

fn (stmt SetTransactionStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	check_transaction_modes(stmt.modes)!

	if stmt.local {
		// ISO/IEC 9075-2:2023(E), 17.2, <set transaction statement>, Syntax Rules, 1
		if stmt.modes.any(it is DiagnosticsSize) {
			return sqlstate_42601('DIAGNOSTICS SIZE cannot be used with LOCAL')
		}

		// ISO/IEC 9075-2:2023(E), 17.2, <set transaction statement>, General Rules, 1.b.i
		return sqlstate_0a001()
	}

	// ISO/IEC 9075-2:2023(E), 17.2, <set transaction statement>, General Rules, 1.a.i
	if conn.is_active() {
		return sqlstate_25001()
	}

	// The SQL-transaction isn't initiated yet.
	//
	// ISO/IEC 9075-2:2023(E), 17.2, <set transaction statement>, General Rules, 7
	conn.next_transaction = new_transaction_characteristics(mut conn, params, stmt.modes)!

	return new_result_msg('SET TRANSACTION', elapsed_parse, t.elapsed())
}

fn (stmt SetTransactionStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN SET TRANSACTION')
}
