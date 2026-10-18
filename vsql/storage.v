// storage.v acts as the gateway for common operations against the raw objects
// on from the pager, such as fetching tables and rows.
//
// Storage is maintained over individual operations on the file because it
// caches the schema.

module vsql

import os

enum TransactionState {
	not_active
	// Whilst in a transaction (specifically START TRANSACTION, not an implicit
	// transaction). This is important to stop a nested transaction from
	// starting or closing an unstarted transaction.
	active
	// If transaction_state is .aborted, all SQL statements will return a
	// SQLSTATE 25P02 until a COMMIT or ROLLBACK is issued. Also, in this state
	// a COMMIT will be treated as a ROLLBACK.
	aborted
}

struct Storage {
mut:
	header Header
	// btree is replaced for each operation (because it needs a new pager for
	// each operation).
	btree Btree
	// We keep the table definitions in memory because they are needed for most
	// operations (including read and writing rows). All tables must be loaded
	// when the database is opened.
	tables map[string]Table
	// file is opened, flushed and closed with each operation against the file.
	file os.File
	// See TransactionState for docs.
	transaction_state TransactionState
	// transaction_id is the current active transaction ID, or zero if there is
	// no active transaction. If there is no active transaction, each statement
	// will be given an implicit transaction.
	transaction_id u64
	// transaction_pages contains all the page numbers that have been modified
	// during this transaction. This is important for COMMIT and ROLLBACK to
	// revisit pages that need to be cleaned up or frozen.
	transaction_pages map[int]bool
	// Like the tables we keep the schemas in memory.
	schemas map[string]Schema
	// session is held for as long as the connection is open. It is used to
	// detect transactions left behind by connections that no longer exist. See
	// recover().
	session SessionLock
}

fn new_storage(btree Btree) Storage {
	return Storage{
		btree: btree
	}
}

// open_file must be called before the file is locked, since the lock is placed
// on the file that is opened.
fn (mut f Storage) open_file(path string) ! {
	f.file = os.open_file(path, 'r+') or { return error('unable to open ${path}: ${err}') }
}

// open must be called after open_file and the file being locked. exclusive
// must only be true if the file is locked exclusively.
fn (mut f Storage) open(path string, catalog_name string, exclusive bool) ! {
	mut header := read_header(mut f.file)!

	f.btree = new_btree(new_file_pager(mut f.file, header.page_size, header.root_page)!,
		header.page_size)

	if exclusive && f.other_transaction_ids(header).len > 0 {
		if f.session.try_exclusive()! {
			defer {
				f.session.shared() or { panic(err) }
			}

			f.recover(mut header)!
		}
	}

	// Avoid reloading the schema if it hasn't changed.
	if header.schema_version == f.header.schema_version {
		f.header = header
		return
	}
	f.header = header

	// The schema must be read in an isolation block, which may or may not
	// belong to an active transaction.
	f.isolation_start()!
	defer {
		f.isolation_end() or { panic(err) }
	}

	f.tables = map[string]Table{}
	for object in f.btree.new_range_iterator('T'.bytes(), 'U'.bytes()) {
		if object_is_visible(object.tid, object.xid, f.transaction_id, mut
			f.header.active_transaction_ids)
		{
			table := new_table_from_bytes(object.value, object.tid, catalog_name)!
			f.tables[table.name.storage_id()] = table
		}
	}

	f.schemas = map[string]Schema{}
	for object in f.btree.new_range_iterator('S'.bytes(), 'T'.bytes()) {
		if object_is_visible(object.tid, object.xid, f.transaction_id, mut
			f.header.active_transaction_ids)
		{
			schema := new_schema_from_bytes(object.value, object.tid)!
			f.schemas[schema.name] = schema
		}
	}
}

// parse_definition parses the definition of a schema object (such as a table),
// which is stored in the file as SQL. See "Schema Objects" in the "File Format"
// docs.
fn parse_definition(data []u8) !Stmt {
	return parse_tokens(tokenize(data.bytestr()))
}

// other_transaction_ids returns the active transaction IDs that do not belong
// to this connection.
fn (f Storage) other_transaction_ids(header Header) []u64 {
	mut tids := []u64{}
	for tid in header.active_transaction_ids.tids {
		if tid != 0 && (f.transaction_state == .not_active || tid != f.transaction_id) {
			tids << tid
		}
	}

	return tids
}

// recover rolls back the transactions that were left active by connections
// that no longer exist, such as a process that crashed in the middle of a
// transaction. It must only be called when this is the only connection to the
// file (the session lock is held exclusively), so that every active
// transaction other than our own is known to be dead.
fn (mut f Storage) recover(mut header Header) ! {
	dead_tids := f.other_transaction_ids(header)

	// We do not know which pages a dead transaction modified, so all of them
	// need to be checked.
	for page_number in 0 .. f.btree.pager.total_pages() {
		mut page := f.btree.pager.fetch_page(page_number)!
		if page.kind != kind_leaf {
			continue
		}

		mut modified := false
		for obj in page.objects() {
			if obj.tid in dead_tids {
				page.delete(obj.key, obj.tid)
				modified = true
			} else if obj.xid in dead_tids {
				page.expire(obj.key, obj.tid, 0)
				modified = true
			}
		}

		if modified {
			f.btree.pager.store_page(page_number, page)!
		}
	}

	for tid in dead_tids {
		header.active_transaction_ids.remove(tid)
	}

	// The dead transactions may have created or dropped tables, so any cached
	// schema must be reloaded.
	header.schema_version++
}

fn (mut f Storage) schema_changed() {
	// We don't need to read the header again because write operations on a file
	// are exclusive so the version (and the header itself) we already have can
	// be incremented.
	f.header.schema_version++
}

// flush must be called before the file is unlocked and closed with close_file.
fn (mut f Storage) flush() ! {
	// Before closing the connection we always write back the page header in
	// case the schema_version or root_page have changed.
	//
	// TODO(elliotchance): We should be smarter about only writing this when we
	//  need to.
	f.header.root_page = f.btree.pager.root_page()

	write_header(mut f.file, f.header)!

	f.file.flush()
}

fn (mut f Storage) close_file() {
	f.file.close()
}

fn (mut f Storage) create_table(table_name Identifier, columns Columns, primary_key []string) ! {
	f.isolation_start()!
	defer {
		f.isolation_end() or { panic(err) }
	}

	table := Table{f.transaction_id, table_name, columns, primary_key, false}

	obj := new_page_object('T${table_name.storage_id()}'.bytes(), f.transaction_id, 0,
		table.bytes())
	f.btree.add(obj)!

	f.tables[table_name.storage_id()] = table
	f.schema_changed()
}

fn (mut f Storage) create_schema(schema_name string) ! {
	f.isolation_start()!
	defer {
		f.isolation_end() or { panic(err) }
	}

	schema := Schema{f.transaction_id, schema_name}

	obj := new_page_object('S${schema_name}'.bytes(), f.transaction_id, 0, schema.bytes())
	f.btree.add(obj)!

	f.schemas[schema_name] = schema
	f.schema_changed()
}

fn (mut f Storage) create_sequence(sequence Sequence) ! {
	f.isolation_start()!
	defer {
		f.isolation_end() or { panic(err) }
	}

	// The sequence defintion.
	obj1 := new_page_object('Q${sequence.name.storage_id()}'.bytes(), f.transaction_id, 0,
		sequence.definition_bytes())
	f.btree.add(obj1)!

	// The value for the sequence is stored as a separate object so that is can be
	// persistent outside of any transaction isolation. Transaction IDs will be
	// left at 0 since they don't apply.
	obj2 := new_page_object('V${sequence.name.storage_id()}'.bytes(), 0, 0, sequence.value_bytes())
	f.btree.add(obj2)!
}

fn (mut f Storage) sequence(name Identifier) !Sequence {
	f.isolation_start()!
	defer {
		f.isolation_end() or { panic(err) }
	}

	value_key := 'V${name.storage_id()}'.bytes()
	value_object := f.get_object(value_key) or {
		return sqlstate_42p01('sequence', name.str()) // sequence does not exist
	}

	definition_key := 'Q${name.storage_id()}'.bytes()
	definition_objects := f.read_objects(definition_key, definition_key)!

	sequence := new_sequence_from_bytes(definition_objects[0].value, value_object.value,
		definition_objects[0].tid)!

	return sequence
}

fn (mut f Storage) sequences() ![]Sequence {
	f.isolation_start()!
	defer {
		f.isolation_end() or { panic(err) }
	}

	mut sequences := []Sequence{}
	for definition_object in f.read_objects('Q'.bytes(), 'R'.bytes())! {
		value_object := f.get_object('V${definition_object.key[1..].bytestr()}'.bytes())!
		sequences << new_sequence_from_bytes(definition_object.value, value_object.value,
			definition_object.tid)!
	}

	return sequences
}

fn (mut f Storage) sequence_next_value(name Identifier) !i64 {
	f.isolation_start()!
	defer {
		f.isolation_end() or { panic(err) }
	}

	mut sequence := f.sequence(name)!
	mut canonical_name := name.storage_id()
	next_sequence := sequence.next()!
	key := 'V${canonical_name}'.bytes()

	f.btree.remove(key, 0, false)!
	new_obj := new_page_object(key, 0, 0, next_sequence.value_bytes())
	f.btree.add(new_obj)!

	return next_sequence.current_value
}

fn (mut f Storage) update_sequence(old_sequence Sequence, new_sequence Sequence) ! {
	f.isolation_start()!
	defer {
		f.isolation_end() or { panic(err) }
	}

	mut canonical_name := new_sequence.name.storage_id()
	definition_key := 'Q${canonical_name}'.bytes()

	old_obj := new_page_object(definition_key, old_sequence.tid, 0, old_sequence.definition_bytes())
	new_obj := new_page_object(definition_key, f.transaction_id, 0, new_sequence.definition_bytes())
	f.btree.update(old_obj, new_obj, f.transaction_id)!

	value_key := 'V${canonical_name}'.bytes()
	f.btree.remove(value_key, 0, false)!
	new_value_obj := new_page_object(value_key, 0, 0, new_sequence.value_bytes())
	f.btree.add(new_value_obj)!
}

fn (mut f Storage) delete_table(table_name string, tid u64) ! {
	f.isolation_start()!
	defer {
		f.isolation_end() or { panic(err) }
	}

	f.btree.expire('T${table_name}'.bytes(), tid, f.transaction_id)!

	// The rows are expired the same way as a DELETE, so they are removed when
	// the transaction ends.
	//
	// TODO(elliotchance): The range also contains the rows of any table named
	//  "${table_name}:...", see https://github.com/elliotchance/vsql/issues/285.
	//  Those rows are skipped here so they are not lost.
	mut other_prefixes := [][]u8{}
	for other_table_name, _ in f.tables {
		if other_table_name.starts_with('${table_name}:') {
			other_prefixes << 'R${other_table_name}:'.bytes()
		}
	}

	// ';' = ':' + 1
	for object in f.read_objects('R${table_name}:'.bytes(), 'R${table_name};'.bytes())! {
		if other_prefixes.any(object.key.len >= it.len && object.key[..it.len] == it) {
			continue
		}

		row_page_number := f.btree.expire(object.key, object.tid, f.transaction_id)!
		if row_page_number >= 0 {
			f.transaction_pages[row_page_number] = true
		}
	}

	f.tables.delete(table_name)
	f.schema_changed()
}

fn (mut f Storage) delete_schema(schema_name string, tid u64) ! {
	f.isolation_start()!
	defer {
		f.isolation_end() or { panic(err) }
	}

	f.btree.expire('S${schema_name}'.bytes(), tid, f.transaction_id)!

	f.schemas.delete(schema_name)
	f.schema_changed()
}

fn (mut f Storage) delete_sequence(name Identifier, tid u64) ! {
	f.isolation_start()!
	defer {
		f.isolation_end() or { panic(err) }
	}

	f.btree.expire('Q${name.storage_id()}'.bytes(), tid, f.transaction_id)!
	f.btree.remove('V${name.storage_id()}'.bytes(), 0, false)!
}

fn (mut f Storage) delete_row(table_name string, mut row Row) ! {
	f.isolation_start()!
	defer {
		f.isolation_end() or { panic(err) }
	}

	page_number := f.btree.expire(row.object_key(f.tables[table_name])!, row.tid, f.transaction_id)!

	// A negative page_number means the object didn't exist so there's nothing to
	// save. This should not be possible because the delete_row will only be
	// issued on a row that already exists, but I guess to be safe let's not let
	// it panic.
	if page_number < 0 {
		return error('DELETE: integrity issue, preventing panic')
	}
}

fn (mut f Storage) write_row(mut r Row, t Table) ! {
	f.isolation_start()!
	defer {
		f.isolation_end() or { panic(err) }
	}

	f.assign_row_id(mut r, t)
	f.check_primary_key(mut r, t)!
	obj := new_page_object(r.object_key(t)!, f.transaction_id, 0, r.bytes(t))
	f.btree.add(obj)!
}

// assign_row_id gives a new row in a table without a PRIMARY KEY the next row
// ID. Writes hold an exclusive lock on the file, so the header we have is
// current, and flush saves the new value.
fn (mut f Storage) assign_row_id(mut r Row, t Table) {
	if t.primary_key.len > 0 || r.id.len > 0 {
		return
	}

	f.header.row_id++

	// Big-endian keeps the rows in the order they were inserted.
	mut buf := new_empty_bytes()
	buf.write_u64(f.header.row_id)
	r.id = buf.bytes()
}

fn (mut f Storage) update_row(mut old Row, mut new Row, t Table) ! {
	f.isolation_start()!
	defer {
		f.isolation_end() or { panic(err) }
	}

	f.assign_row_id(mut new, t)
	if new.object_key(t)! != old.object_key(t)! {
		f.check_primary_key(mut new, t)!
	}
	old_obj := new_page_object(old.object_key(t)!, old.tid, 0, old.bytes(t))
	new_obj := new_page_object(new.object_key(t)!, f.transaction_id, 0, new.bytes(t))
	f.btree.update(old_obj, new_obj, f.transaction_id)!
}

fn (mut f Storage) read_rows(table_name Identifier) ![]Row {
	f.isolation_start()!
	defer {
		f.isolation_end() or { panic(err) }
	}

	mut rows := []Row{}

	// ';' = ':' + 1
	table_storage_id := table_name.storage_id()
	for object in f.read_objects('R${table_storage_id}:'.bytes(), 'R${table_storage_id};'.bytes())! {
		rows << new_row_from_bytes(f.tables[table_storage_id], object.value, object.tid)
	}

	return rows
}

fn (mut f Storage) read_objects(start []u8, end []u8) ![]PageObject {
	mut objs := []PageObject{}
	for object in f.btree.new_range_iterator(start, end) {
		if object_is_visible(object.tid, object.xid, f.transaction_id, mut
			f.header.active_transaction_ids)
		{
			objs << object
		}
	}

	return objs
}

fn (mut f Storage) get_object(start []u8) !PageObject {
	for object in f.btree.new_range_iterator(start, start) {
		return object
	}

	return error('no object: ${start.bytestr()}')
}

// isolation_start signals the start of an operation that shall be atomic until
// isolation_end is invoked. If there is no active transaction, a new
// transaction will be created. Otherwise, this isolation block will be part of
// the current transaction.
fn (mut f Storage) isolation_start() ! {
	match f.transaction_state {
		.not_active {
			// Fallthrough to the logic below.
		}
		.active {
			return
		}
		.aborted {
			return sqlstate_25p02()
		}
	}

	f.header.transaction_id++

	f.transaction_id = f.header.transaction_id
	f.header.active_transaction_ids.add(f.transaction_id)!
}

fn (mut f Storage) transaction_aborted() {
	if f.transaction_state == .active {
		f.transaction_state = .aborted
	}
}

// isolation_end must be called at some point after isolation_start to signal
// the end of the atomic blocks. At the moment blocks cannot be nested so the
// state of the active or implicit transaction state is expected to be
// maintained.
fn (mut f Storage) isolation_end() ! {
	// The B-tree is replaced for each operation, so the pages it changed must
	// be kept with the transaction before then.
	for page_number, _ in f.btree.written_pages {
		f.transaction_pages[page_number] = true
	}
	f.btree.written_pages = map[int]bool{}

	match f.transaction_state {
		.not_active {
			// Fallthrough to logic below.
		}
		.active, .aborted {
			// Do nothing. COMMIT, ROLLBACK or some other transaction terminator
			// will take care of this later.
			return
		}
	}

	// Revist any remaining pages to clean out any expired rows.
	for page_number, _ in f.transaction_pages {
		// Removing objects can move the last page and truncate the file.
		if page_number >= f.btree.pager.total_pages() {
			continue
		}

		mut page := f.btree.pager.fetch_page(page_number)!
		for obj in page.objects() {
			// Only remove the objects expired in this transaction.
			if obj.xid == f.transaction_id {
				page.delete(obj.key, obj.tid)
			}
		}

		f.btree.pager.store_page(page_number, page)!
	}

	f.transaction_pages = map[int]bool{}

	f.header.active_transaction_ids.remove(f.transaction_id)
}
