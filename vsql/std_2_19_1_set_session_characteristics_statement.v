module vsql

import time

// ISO/IEC 9075-2:2023(E), 19.1, <set session characteristics statement>
//
// Set one or more characteristics for the current SQL-session.
//
// These are the enduring transaction characteristics. An SQL-transaction has them
// unless a SET TRANSACTION or START TRANSACTION says otherwise. It doesn't change
// the current SQL-transaction, so it can be used in one.

struct SetSessionCharacteristicsStatement {
	modes []TransactionMode
}

fn (stmt SetSessionCharacteristicsStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// ISO/IEC 9075-2:2023(E), 19.1, <set session characteristics statement>, Syntax Rules, 1
	check_transaction_modes(stmt.modes)!

	mut characteristics := conn.enduring_transaction
	for mode in stmt.modes {
		match mode {
			// ISO/IEC 9075-2:2023(E), 19.1, <set session characteristics statement>, General Rules, 1 and 2
			IsolationLevel {
				characteristics = TransactionCharacteristics{
					...characteristics
					isolation_level: mode
				}
			}
			// ISO/IEC 9075-2:2023(E), 19.1, <set session characteristics statement>, General Rules, 3
			TransactionAccessMode {
				characteristics = TransactionCharacteristics{
					...characteristics
					read_only: mode == .read_only
				}
			}
			// ISO/IEC 9075-2:2023(E), 19.1, <set session characteristics statement>, General Rules, 4
			DiagnosticsSize {
				characteristics = TransactionCharacteristics{
					...characteristics
					condition_area_limit: condition_area_limit(mut conn, params, mode)!
				}
			}
		}
	}
	conn.enduring_transaction = characteristics

	return new_result_msg('SET SESSION CHARACTERISTICS', elapsed_parse, t.elapsed())
}

fn (stmt SetSessionCharacteristicsStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN SET SESSION CHARACTERISTICS')
}
