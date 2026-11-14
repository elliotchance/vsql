module vsql

import time

// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>
//
// Terminate the current SQL-transaction with commit.
//
// A COMMIT when there isn't an active SQL-transaction does nothing, even with
// AND CHAIN. That's only with query (or autocommit), where a statement outside of
// a START TRANSACTION is in an SQL-transaction that ends with it (see
// Connection.direct).

struct CommitStatement {
	// chain is AND CHAIN. Without it, or with AND NO CHAIN, it's false.
	//
	// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>, Syntax Rules, 1
	chain bool
}

fn (stmt CommitStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// Outside of a transaction there's nothing to commit, since every statement
	// is committed when it finishes. The standard only uses 2D000 (invalid
	// transaction termination) for transactions that are managed outside of
	// the database (General Rules 1 and 2), so it succeeds.
	if !conn.in_transaction() {
		return new_result_msg('COMMIT', elapsed_parse, t.elapsed())
	}

	characteristics := conn.current_characteristics()
	constraint_modes := conn.commit_transaction()!

	// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>, General Rules, 10.a
	if stmt.chain {
		conn.end_transaction(true)
		conn.chain_transaction(characteristics, constraint_modes)!
	}

	return new_result_msg('COMMIT', elapsed_parse, t.elapsed())
}

// commit_transaction commits the SQL-transaction in every catalog. It returns the
// constraint modes that it ended with, which every constraint is immediate.
fn (mut conn Connection) commit_transaction() !map[string]map[string]bool {
	// A catalog that the SQL-transaction hasn't changed has nothing to commit,
	// so it isn't locked (and it can be one that can only be read).
	for _, mut catalog in conn.catalogs {
		if catalog.storage.transaction_state == .active {
			catalog.open_write_connection()!
			catalog.release_write_connection()
		}
	}

	// Every deferred constraint is checked first, as if by SET CONSTRAINTS ALL
	// IMMEDIATE, so that nothing is committed if one isn't satisfied. The
	// transaction is then rolled back, see commit_error.
	//
	// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>, General Rules, 5 and 6.a
	for _, mut catalog in conn.catalogs {
		catalog.storage.set_all_constraint_modes(false)
	}
	conn.check_deferred_constraints()!
	constraint_modes := conn.constraint_modes()

	// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>, General Rules, 6.c and 9
	for _, mut catalog in conn.catalogs {
		catalog.commit_transaction()!
	}

	return constraint_modes
}

// commit_error is the error for anything that prevents a COMMIT, which is always
// a transaction rollback, see PreparedStmt.fail. A serialization failure (such as
// when another connection has a SERIALIZABLE transaction, see isolation.v) is
// already a transaction rollback, so it's kept as it is.
//
// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>, General Rules, 6.a and 6.b
// ISO/IEC 9075-3:2003(E), 6.17, EndTran, General Rules, 12.d.i and 12.d.iii
fn commit_error(err IError) IError {
	sqlstate := sqlstate_from_int(err.code())
	return if sqlstate.starts_with('23') {
		sqlstate_40002(err.msg(), violated_constraint(err) or { Identifier{} },
			condition_table(err) or { Identifier{} })
	} else if sqlstate.starts_with('40') {
		err
	} else {
		sqlstate_40v01(err.msg())
	}
}

// commit_transaction must be called with the write connection open, unless the
// SQL-transaction hasn't changed anything.
fn (mut catalog CatalogConnection) commit_transaction() ! {
	if catalog.storage.transaction_state == .reading {
		catalog.storage.transaction_state = .not_active
		catalog.storage.end_constraint_modes()
		return
	}

	// Only remove the now expired records.
	schema_changed := catalog.storage.remove_expired(catalog.storage.transaction_page_numbers()!,
		true)!
	reload := catalog.storage.end_snapshot()!

	// We can erase these now. The pages have already been visited, so
	// isolation_end doesn't need to visit them (or the pages that were changed
	// since) again.
	catalog.storage.save_transaction_pages()
	catalog.storage.transaction_pages = map[int]bool{}
	catalog.storage.transaction_keys = map[string]bool{}
	catalog.storage.btree.written_pages = map[int]bool{}

	// We do the reverse of start_transation where we disable the active
	// transaction before calling isolation_end.
	catalog.storage.transaction_state = .not_active
	catalog.storage.rollback_needs_pages = false
	catalog.storage.isolation_end()!
	catalog.storage.end_constraint_modes()
	catalog.storage.end_savepoints()

	// Other connections may have loaded the schema while this transaction was
	// active, so they could not see the tables, schemas and indexes it created
	// or dropped. They must reload it now that the changes are committed.
	if schema_changed {
		catalog.storage.schema_changed()!
	}

	// The schema that a REPEATABLE READ transaction loaded is the one it could
	// see, which isn't the latest one.
	if reload {
		catalog.storage.load_schema(catalog.catalog_name)!
	}
}

fn (stmt CommitStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN COMMIT')
}
