module vsql

import time

// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>
//
// Terminate the current SQL-transaction with commit.
//
// AND CHAIN (T261) isn't supported. A COMMIT when there isn't an active
// SQL-transaction is 2D000 (invalid transaction termination, #231). That's only
// with query (or autocommit), where a statement outside of a START
// TRANSACTION is in an SQL-transaction that ends with it (see
// Connection.direct).

struct CommitStatement {
}

fn (stmt CommitStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	if !conn.in_transaction() {
		return sqlstate_2d000()
	}

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
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

	// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>, General Rules, 6.c and 9
	for _, mut catalog in conn.catalogs {
		catalog.commit_transaction()!
	}

	return new_result_msg('COMMIT', elapsed_parse, t.elapsed())
}

// commit_error is the error for anything that prevents a COMMIT, which is always
// a transaction rollback, see PreparedStmt.fail. Conflicts are found when a row
// is written, so a COMMIT can't fail with a serialization failure.
//
// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>, General Rules, 6.a and 6.b
// ISO/IEC 9075-3:2003(E), 6.17, EndTran, General Rules, 12.d.i and 12.d.iii
fn commit_error(err IError) IError {
	is_violation := sqlstate_from_int(err.code()).starts_with('23')
	return if is_violation {
		sqlstate_40002(err.msg(), violated_constraint(err) or { Identifier{} })
	} else {
		sqlstate_40v01(err.msg())
	}
}

// commit_transaction must be called with the write connection open.
fn (mut catalog CatalogConnection) commit_transaction() ! {
	mut blob_refs := []PageObject{}
	mut schema_changed := false
	for page_number, _ in catalog.storage.transaction_pages {
		mut page := catalog.storage.btree.pager.fetch_page(page_number)!
		for obj in page.objects() {
			if (obj.tid == catalog.storage.transaction_id
				|| obj.xid == catalog.storage.transaction_id) && obj.key[0] in [`T`, `S`, `N`] {
				schema_changed = true
			}

			// Only remove the now expired records.
			if obj.xid == catalog.storage.transaction_id {
				page.delete(obj.key, obj.tid)
				if obj.is_blob_ref {
					blob_refs << obj
				}
			}
		}

		catalog.storage.btree.pager.store_page(page_number, page)!
	}

	for obj in blob_refs {
		catalog.storage.btree.remove_blob(obj)!
	}

	// We do the reverse of start_transation where we disable the active
	// transaction before calling isolation_end.
	catalog.storage.transaction_state = .not_active
	catalog.storage.isolation_end()!

	// We can erase these now.
	catalog.storage.save_transaction_pages()
	catalog.storage.transaction_pages = map[int]bool{}
	catalog.storage.end_constraint_modes()

	// Other connections may have loaded the schema while this transaction was
	// active, so they could not see the tables, schemas and indexes it created
	// or dropped. They must reload it now that the changes are committed.
	if schema_changed {
		catalog.storage.schema_changed()
	}
}

fn (stmt CommitStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN COMMIT')
}
