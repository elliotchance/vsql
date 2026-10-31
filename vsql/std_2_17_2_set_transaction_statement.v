module vsql

import time

// ISO/IEC 9075-2:2016(E), 17.2, <set transaction statement>
//
// Set the characteristics of the next SQL-transaction for the SQL-agent.
//
// LOCAL (Feature T251) isn't supported.

struct SetTransactionStatement {
	modes []TransactionMode
}

fn (stmt SetTransactionStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// ISO/IEC 9075-2:2016(E), 17.2, <set transaction statement>, General Rules, 1.a.i
	if conn.is_active() {
		return sqlstate_25001()
	}

	// The SQL-transaction isn't initiated yet.
	//
	// ISO/IEC 9075-2:2016(E), 17.2, <set transaction statement>, General Rules, 7
	conn.next_condition_area_limit = condition_area_limit(mut conn, params, stmt.modes)!

	return new_result_msg('SET TRANSACTION', elapsed_parse, t.elapsed())
}

fn (stmt SetTransactionStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN SET TRANSACTION')
}
