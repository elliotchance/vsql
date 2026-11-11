module vsql

import time

// ISO/IEC 9075-2:2016(E), 17.1, <start transaction statement>
//
// Start an SQL-transaction and set its characteristics.
//
// The concept is described by ISO/IEC 9075-1:2003(E), 4.8.5, SQL-transactions.
//
// The concept is also described by:
//
// ISO/IEC 9075-2:2016(E), 4.41, SQL-transactions

struct StartTransactionStatement {
	// modes is empty when there are no <transaction characteristics>.
	modes []TransactionMode
	// implicit is set when the SQL-transaction is started for a statement that
	// isn't a START TRANSACTION, which has these characteristics instead of
	// modes, see Connection.direct.
	implicit ?TransactionCharacteristics
}

fn (stmt StartTransactionStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	check_transaction_modes(stmt.modes)!

	// ISO/IEC 9075-2:2016(E), 17.1, <start transaction statement>, General Rules, 1
	if conn.in_transaction() {
		return sqlstate_25001()
	}

	// A SET TRANSACTION before doesn't change the characteristics (NOTE 710).
	//
	// ISO/IEC 9075-2:2016(E), 17.1, <start transaction statement>, General Rules, 2 to 5
	characteristics := stmt.implicit or {
		new_transaction_characteristics(mut conn, params, stmt.modes)!
	}
	if characteristics.isolation_level.locks_transaction() {
		conn.lock_transaction()!
	}
	conn.start_transaction()!
	conn.initiate_transaction(characteristics)

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
	assert catalog.storage.transaction_keys.len == 0

	catalog.storage.transaction_pages = map[int]bool{}
}

fn (stmt StartTransactionStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN START TRANSACTION')
}
