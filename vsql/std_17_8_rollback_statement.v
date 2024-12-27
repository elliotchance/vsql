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
	mut catalog := conn.catalog()

	match catalog.storage.transaction_state {
		.not_active {
			return sqlstate_2d000()
		}
		.active {
			// All good, continue below.
		}
		.aborted {
			return sqlstate_25p02()
		}
	}

	catalog.open_write_connection()!
	defer {
		catalog.release_write_connection()
	}

	for page_number, _ in catalog.storage.transaction_pages {
		mut page := catalog.storage.btree.pager.fetch_page(page_number)!
		for obj in page.objects() {
			// Only remove the objects created in this transaction.
			if obj.tid == catalog.storage.transaction_id {
				page.delete(obj.key, catalog.storage.transaction_id)
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

	return new_result_msg('ROLLBACK', elapsed_parse, t.elapsed())
}

fn (stmt RollbackStatement) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN ROLLBACK')
}
