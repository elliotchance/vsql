// vacuum.v contains VACUUM, which isn't part of the standard. It rebuilds the
// database file so that it's as small as it can be.

module vsql

import time

// VACUUM
struct VacuumStatement {}

// execute rebuilds the B-tree of the current catalog (see Storage.vacuum). It
// can't be in a transaction (it's a 25001 error), because the pages of the
// rebuilt file replace every page, rather than being part of the transaction.
// The result is "VACUUM scanned removed": the number of pages of the B-tree
// that were read, and how many pages were removed from the file (including
// free pages).
fn (stmt VacuumStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	if conn.in_transaction() {
		return sqlstate_25001()
	}

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut catalog := conn.catalog()
	scanned, removed := catalog.storage.vacuum()!

	return new_result_msg('VACUUM ${scanned} ${removed}', elapsed_parse, t.elapsed())
}

fn (stmt VacuumStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN VACUUM')
}

// vacuum rebuilds the B-tree, so that the file is as small as it can be. Every
// object is added to a new B-tree in order, which fills every page (see
// split_objects), and the new pages replace all of the pages of the file (see
// Pager.replace_pages). The file is made shorter when the statement is
// committed (see wal_checkpoint), and there are no free pages.
//
// A large value is put back together by the iterator (see read_blob), and is
// split again by Btree.add, so its blob and fragment objects aren't copied.
//
// It's an error if another connection has a transaction, because the
// transaction may have objects that it hasn't committed or removed yet, and
// they would be copied too. The new B-tree is kept in memory until it's
// written, so it needs as much memory as the file (without its free space).
//
// It returns the number of pages of the B-tree that were read (free pages
// aren't read), and the number of pages that were removed from the file
// (including the free pages). The file isn't changed when the new B-tree wouldn't have fewer pages, which
// can happen when there's nothing to remove, because a large value is split
// into objects of half a page that can't be packed any closer.
fn (mut f Storage) vacuum() !(int, int) {
	if !f.is_only_transaction() {
		return sqlstate_40001('cannot VACUUM while another connection has a transaction')
	}

	mut pager := new_memory_pager()
	mut btree := new_btree(pager, f.btree.page_size)
	mut iter := f.btree.new_range_iterator([u8(0)], [u8(255)])
	for {
		object := iter.next() or { break }
		if object.key[0] in [`B`, `F`] {
			continue
		}

		btree.add(PageObject{
			...object
			key:   object.key.clone()
			value: object.value.clone()
		})!
	}
	if err := iter.err {
		return err
	}

	pager.commit()
	before := f.btree.pager.total_pages()
	if pager.pages.len >= before {
		return iter.pages_read, 0
	}

	f.btree.pager.replace_pages(pager.pages, pager.root_page)!

	return iter.pages_read, before - pager.pages.len
}
