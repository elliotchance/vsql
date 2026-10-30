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
//
// The isolation level is always READ COMMITTED, rather than an implicit
// SERIALIZABLE (#664).
//
// ISO/IEC 9075-2:2016(E), 17.3, <transaction characteristics>, Syntax Rules, 3

struct StartTransactionStatement {
	modes []TransactionMode
}

fn (stmt StartTransactionStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// ISO/IEC 9075-2:2016(E), 17.1, <start transaction statement>, General Rules, 1
	if conn.in_transaction() {
		return sqlstate_25001()
	}

	// A SET TRANSACTION before doesn't change the characteristics (NOTE 710).
	//
	// ISO/IEC 9075-2:2016(E), 17.1, <start transaction statement>, General Rules, 2 to 5
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
