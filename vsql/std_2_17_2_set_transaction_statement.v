module vsql

import time

// ISO/IEC 9075-2:2016(E), 17.2, <set transaction statement>
//
// Set the characteristics of the next SQL-transaction for the SQL-agent.

struct SetTransactionStatement {
	modes []TransactionMode
}

fn (stmt SetTransactionStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	characteristics := new_transaction_characteristics(stmt.modes)!

	if conn.in_transaction() {
		return sqlstate_25001()
	}

	conn.next_transaction = characteristics

	return new_result_msg('SET TRANSACTION', elapsed_parse, t.elapsed())
}

fn (stmt SetTransactionStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN SET TRANSACTION')
}
