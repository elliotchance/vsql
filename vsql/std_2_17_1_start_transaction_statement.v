module vsql

import time

// ISO/IEC 9075-2:2016(E), 17.1, <start transaction statement>
//
// Start an SQL-transaction and set its characteristics.

struct StartTransactionStatement {
	modes []TransactionMode
}

fn (stmt StartTransactionStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// - GR 1.
	if conn.in_transaction() {
		return sqlstate_25001()
	}

	// - GR 2, 3, 4, 5. NOTE 710: A SET TRANSACTION before doesn't change the
	// characteristics.
	limit := condition_area_limit(mut conn, params, stmt.modes)!
	conn.start_transaction()!
	conn.initiate_transaction(limit)

	return new_result_msg('START TRANSACTION', elapsed_parse, t.elapsed())
}

// start_transaction starts the SQL-transaction in storage. The SQL-transaction
// includes every catalog, since a statement can use any of them.
fn (mut conn Connection) start_transaction() ! {
	for _, mut catalog in conn.catalogs {
		catalog.start_transaction()!
	}
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
