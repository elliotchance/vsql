module vsql

import time

// ISO/IEC 9075-2:2016(E), 17.8, <rollback statement>
//
// Terminate the current SQL-transaction with rollback, or rollback all actions
// affecting SQL-data and/or schemas since the establishment of a savepoint.
//
// Like COMMIT, a ROLLBACK when there isn't an active SQL-transaction does nothing,
// even with AND CHAIN. TO SAVEPOINT is a savepoint exception then, because there
// are no savepoints.

struct RollbackStatement {
	// chain is AND CHAIN. Without it, or with AND NO CHAIN, it's false.
	//
	// ISO/IEC 9075-2:2016(E), 17.8, <rollback statement>, Syntax Rules, 2
	chain bool
	// savepoint is the name of the TO SAVEPOINT, which is empty without it.
	savepoint string
}

fn (stmt RollbackStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	if stmt.savepoint != '' {
		// ISO/IEC 9075-2:2016(E), 17.8, <rollback statement>, Syntax Rules, 1
		if stmt.chain {
			return sqlstate_42601('AND CHAIN cannot be used with TO SAVEPOINT')
		}

		conn.rollback_to_savepoint(stmt.savepoint)!

		return new_result_msg('ROLLBACK', elapsed_parse, t.elapsed())
	}

	// Like COMMIT, there's nothing to roll back outside of a transaction.
	if !conn.in_transaction() {
		return new_result_msg('ROLLBACK', elapsed_parse, t.elapsed())
	}

	characteristics := conn.current_characteristics()
	constraint_modes := conn.constraint_modes()

	// ISO/IEC 9075-2:2016(E), 17.8, <rollback statement>, General Rules, 2.b and 2.g
	for _, mut catalog in conn.catalogs {
		catalog.rollback_transaction()!
	}
	conn.end_transaction(false)

	// ISO/IEC 9075-2:2016(E), 17.8, <rollback statement>, General Rules, 2.h.i
	if stmt.chain {
		conn.chain_transaction(characteristics, constraint_modes)!
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
	catalog.storage.end_constraint_modes()
	catalog.storage.end_savepoints()

	// Tables and schemas that were created or dropped in this transaction must
	// be reloaded, here and in other connections.
	if schema_changed {
		catalog.storage.schema_changed()
		catalog.storage.load_schema(catalog.catalog_name)!
	}
}

fn (stmt RollbackStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN ROLLBACK')
}
