module vsql

import time

// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>
//
// Terminate the current SQL-transaction with commit.

struct CommitStatement {
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

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	// Every deferred constraint is checked first, as if by SET CONSTRAINTS ALL
	// IMMEDIATE, so that nothing is committed if one isn't satisfied (General
	// Rules 5 and 6a). The transaction is then rolled back, see
	// PreparedStmt.fail.
	for _, mut catalog in conn.catalogs {
		catalog.storage.set_all_constraint_modes(false)
	}
	conn.check_deferred_constraints() or { return commit_error(err) }

	for _, mut catalog in conn.catalogs {
		catalog.commit_transaction()!
	}

	return new_result_msg('COMMIT', elapsed_parse, t.elapsed())
}

// commit_error is the error for a deferred constraint that isn't satisfied at
// the COMMIT (General Rule 6a), or another error (such as a serialization
// failure) as it is.
fn commit_error(err IError) IError {
	is_violation := sqlstate_from_int(err.code()).starts_with('23')
	return if is_violation { sqlstate_40002(err.msg()) } else { err }
}

// commit_transaction must be called with the write connection open.
fn (mut catalog CatalogConnection) commit_transaction() ! {
	mut blob_refs := []PageObject{}
	mut schema_changed := false
	for page_number, _ in catalog.storage.transaction_pages {
		mut page := catalog.storage.btree.pager.fetch_page(page_number)!
		for obj in page.objects() {
			if (obj.tid == catalog.storage.transaction_id
				|| obj.xid == catalog.storage.transaction_id) && obj.key[0] in [`T`, `S`] {
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
	catalog.storage.transaction_pages = map[int]bool{}
	catalog.storage.end_constraint_modes()

	// Other connections may have loaded the schema while this transaction was
	// active, so they could not see the tables and schemas it created or
	// dropped. They must reload it now that the changes are committed.
	if schema_changed {
		catalog.storage.schema_changed()
	}
}

fn (stmt CommitStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN COMMIT')
}
