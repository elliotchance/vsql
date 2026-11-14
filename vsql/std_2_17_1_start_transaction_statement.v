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
		conn.lock_transaction(characteristics.read_only)!
	}
	conn.start_transaction(characteristics.isolation_level)!
	conn.initiate_transaction(characteristics)

	return new_result_msg('START TRANSACTION', elapsed_parse, t.elapsed())
}

// chain_transaction initiates the SQL-transaction of an AND CHAIN, after the last
// one has ended. It has the same access mode, isolation level and condition area
// limit, and the constraint modes aren't reset to their initial modes.
//
// A REPEATABLE READ or SERIALIZABLE transaction keeps the isolation lock, so that
// it can't fail after the last one has ended, and nothing else can commit between
// them. A lower level must give up the lock that committing took, or it would
// hold it until the next one ends.
//
// The end of the last one is finished first, as it is at the end of a statement.
// That also unlocks the file, and if the next one can't start then the last one
// has still ended.
fn (mut conn Connection) chain_transaction(characteristics TransactionCharacteristics, constraint_modes map[string]map[string]bool) ! {
	conn.take_isolation_error()!
	conn.finish_write(true)!
	if !characteristics.isolation_level.locks_transaction() {
		conn.unlock_transactions()
	}
	conn.start_transaction(characteristics.isolation_level)!
	conn.initiate_transaction(characteristics)
	for name, mut catalog in conn.catalogs {
		catalog.storage.constraint_modes = constraint_modes[name].clone()
	}
}

// constraint_modes are the constraint modes of every catalog, by its name.
fn (conn Connection) constraint_modes() map[string]map[string]bool {
	mut modes := map[string]map[string]bool{}
	for name, catalog in conn.catalogs {
		modes[name] = catalog.storage.constraint_modes.clone()
	}

	return modes
}

// start_transaction starts the SQL-transaction in storage. The SQL-transaction
// includes every catalog, since a statement can use any of them.
fn (mut conn Connection) start_transaction(level IsolationLevel) ! {
	for _, mut catalog in conn.catalogs {
		catalog.start_transaction(level)!
	}
}

// start_transaction starts an SQL-transaction that hasn't changed anything, so
// it doesn't lock or change the file (see TransactionState). It becomes a
// transaction that can write with begin_transaction.
//
// Except for REPEATABLE READ, which takes its snapshot now (see
// Storage.take_snapshot). The snapshot must be published with the transaction
// ID, so that a COMMIT in another connection keeps the versions of rows that it
// can see, so the transaction is given one straight away. If the database can
// only be read, it can't be, so it starts like the others, without a snapshot
// until it changes something (see Storage.snapshot_pending).
fn (mut catalog CatalogConnection) start_transaction(level IsolationLevel) ! {
	catalog.storage.snapshot_pending = level == .repeatable_read
	if level != .repeatable_read {
		catalog.storage.transaction_state = .reading
		return
	}

	catalog.open_write_connection() or {
		if err !is SQLState25006 {
			return err
		}
		catalog.storage.transaction_state = .reading
		catalog.storage.snapshot_header = catalog.storage.header
		return
	}
	defer {
		catalog.release_write_connection()
	}
	catalog.storage.begin_transaction()!
}

// begin_transaction makes an SQL-transaction that hasn't changed anything yet
// (see TransactionState) active, so that it can write. It must be called with
// the write connection open.
fn (mut f Storage) begin_transaction() ! {
	// isolation_start registers the transaction, then transaction_state ensures
	// that future calls to isolation_start for individual operations use the
	// same isolation scope (the transaction).
	f.isolation_start()!
	f.transaction_state = .active
	f.rollback_needs_pages = false

	// This would fail is a implicit or explicit transaction did not perform
	// cleanup.
	assert f.transaction_pages.len == 0
	assert f.transaction_keys.len == 0

	f.transaction_pages = map[int]bool{}

	if f.snapshot_pending {
		f.take_snapshot()!
	}
}

fn (stmt StartTransactionStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN START TRANSACTION')
}
