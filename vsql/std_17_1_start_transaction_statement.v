module vsql

import time

// ISO/IEC 9075-2:2016(E), 17.1, <start transaction statement>
//
// Start an SQL-transaction and set its characteristics.

struct StartTransactionStatement {
}

fn (stmt StartTransactionStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()
	mut catalog := conn.catalog()

	match catalog.storage.transaction_state {
		.not_active {
			// All good, continue below.
		}
		.active {
			return sqlstate_25001()
		}
		.aborted {
			return sqlstate_25p02()
		}
	}

	catalog.open_write_connection()!
	defer {
		catalog.release_write_connection()
	}

	// isolation_start registers the transaction, then transaction_state ensures
	// that future calls to isolation_start for individual operations use the
	// same isolation scope (the transaction).
	catalog.storage.isolation_start()!
	catalog.storage.transaction_state = .active

	// This would fail is a implicit or explicit transaction did not perform
	// cleanup.
	assert catalog.storage.transaction_pages.len == 0

	// TODO(elliotchance): Is this really needed? We should find a way to make
	//  sure implicit transactions erase this at the end of their used as well.
	catalog.storage.transaction_pages = map[int]bool{}

	return new_result_msg('START TRANSACTION', elapsed_parse, t.elapsed())
}

fn (stmt StartTransactionStatement) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN START TRANSACTION')
}
