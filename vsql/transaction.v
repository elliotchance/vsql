// transaction.v contains the implementations for transaction statements:
// START TRANSACTION, COMMIT and ROLLBACK.

module vsql

import time

fn execute_start_transaction(mut c Connection, stmt StartTransactionStatement, elapsed_parse time.Duration) !Result {
	t := start_timer()
	mut catalog := c.catalog()

	match catalog.storage.transaction_state {
		.not_active {
			// All good, continue below.
		}
		.active {
			return sqlstate_25001()
		}
		.aborted {
			return sqlstate_25p02()
		}
	}

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

	return new_result_msg('START TRANSACTION', elapsed_parse, t.elapsed())
}

fn execute_commit(mut c Connection, stmt CommitStmt, elapsed_parse time.Duration) !Result {
	t := start_timer()
	mut catalog := c.catalog()

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
			// Only remove the now expired records.
			if obj.xid == catalog.storage.transaction_id {
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

	return new_result_msg('COMMIT', elapsed_parse, t.elapsed())
}

fn execute_rollback(mut c Connection, stmt RollbackStatement, elapsed_parse time.Duration) !Result {
	t := start_timer()
	mut catalog := c.catalog()

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
