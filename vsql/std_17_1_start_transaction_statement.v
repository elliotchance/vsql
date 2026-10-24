module vsql

import time

// ISO/IEC 9075-2:2016(E), 17.1, <start transaction statement>
//
// Start an SQL-transaction and set its characteristics.

struct StartTransactionStatement {
	// modes is empty when there are no <transaction characteristics>.
	modes []TransactionMode
}

fn (stmt StartTransactionStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	mut characteristics := conn.next_transaction or { TransactionCharacteristics{} }
	if stmt.modes.len > 0 {
		characteristics = new_transaction_characteristics(stmt.modes)!
	}

	if conn.in_transaction() {
		return sqlstate_25001()
	}

	// Characteristics from SET TRANSACTION are for this SQL-transaction, unless
	// they are replaced.
	conn.read_only = characteristics.read_only
	conn.isolation_level = characteristics.isolation_level
	conn.next_transaction = none

	if conn.isolation_level.locks_transaction() {
		conn.lock_transaction(conn.read_only)!
	}

	// The SQL-transaction includes every catalog, since a statement can use any
	// of them.
	for _, mut catalog in conn.catalogs {
		catalog.start_transaction()!
	}

	return new_result_msg('START TRANSACTION', elapsed_parse, t.elapsed())
}

fn (mut catalog CatalogConnection) start_transaction() ! {
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
}

fn (stmt StartTransactionStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN START TRANSACTION')
}
