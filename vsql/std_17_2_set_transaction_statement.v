module vsql

import time

// ISO/IEC 9075-2:2016(E), 17.2, <set transaction statement>
//
// Set the characteristics of the next SQL-transaction for the SQL-agent.

struct SetTransactionStatement {
	characteristics TransactionCharacteristics
}

fn (stmt SetTransactionStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	if conn.in_transaction() {
		return sqlstate_25001()
	}

	conn.next_transaction = stmt.characteristics

	return new_result_msg('SET TRANSACTION', elapsed_parse, t.elapsed())
}

fn (stmt SetTransactionStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN SET TRANSACTION')
}
