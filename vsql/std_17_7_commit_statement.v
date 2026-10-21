module vsql

import time

// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>
//
// Terminate the current SQL-transaction with commit.

struct CommitStatement {
}

fn (stmt CommitStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	if !conn.in_transaction() {
		return sqlstate_2d000()
	}

	for _, mut catalog in conn.catalogs {
		catalog.commit_transaction()!
	}

	return new_result_msg('COMMIT', elapsed_parse, t.elapsed())
}

fn (mut catalog CatalogConnection) commit_transaction() ! {
	catalog.open_write_connection()!
	defer {
		catalog.release_write_connection()
	}

	mut blob_refs := []PageObject{}
	for page_number, _ in catalog.storage.transaction_pages {
		mut page := catalog.storage.btree.pager.fetch_page(page_number)!
		for obj in page.objects() {
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
}

fn (stmt CommitStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN COMMIT')
}
