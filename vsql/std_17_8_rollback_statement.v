module vsql

import time

// ISO/IEC 9075-2:2016(E), 17.8, <rollback statement>
//
// Terminate the current SQL-transaction with rollback, or rollback all actions
// affecting SQL-data and/or schemas since the establishment of a savepoint.

struct RollbackStatement {
}

fn (stmt RollbackStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	if !conn.in_transaction() {
		return sqlstate_2d000()
	}

	for _, mut catalog in conn.catalogs {
		catalog.rollback_transaction()!
	}

	return new_result_msg('ROLLBACK', elapsed_parse, t.elapsed())
}

fn (mut catalog CatalogConnection) rollback_transaction() ! {
	catalog.open_write_connection()!
	defer {
		catalog.release_write_connection()
	}

	mut schema_changed := false
	for page_number, _ in catalog.storage.transaction_pages {
		mut page := catalog.storage.btree.pager.fetch_page(page_number)!
		for obj in page.objects() {
			if (obj.tid == catalog.storage.transaction_id
				|| obj.xid == catalog.storage.transaction_id) && obj.key[0] in [`T`, `S`] {
				schema_changed = true
			}

			// Only remove the objects created in this transaction.
			if obj.tid == catalog.storage.transaction_id {
				page.delete(obj.key, catalog.storage.transaction_id)
			} else if obj.xid == catalog.storage.transaction_id {
				// Objects expired (deleted or updated) in this transaction are
				// made visible again.
				page.expire(obj.key, obj.tid, 0)!
			}
		}

		catalog.storage.btree.pager.store_page(page_number, page)!
	}

	// We do the reverse of start_transation where we disable the active
	// transaction before calling isolation_end.
	catalog.storage.transaction_state = .not_active
	catalog.storage.isolation_end()!

	// We can erase these now.
	catalog.storage.transaction_pages = map[int]bool{}

	// Tables and schemas that were created or dropped in this transaction must
	// be reloaded, here and in other connections.
	if schema_changed {
		catalog.storage.schema_changed()
		catalog.storage.load_schema(catalog.catalog_name)!
	}
}

fn (stmt RollbackStatement) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN ROLLBACK')
}
