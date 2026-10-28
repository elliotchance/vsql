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
	// data_lock is held while file is open. See DataFileLock.
	data_lock DataFileLock
	// See TransactionState for docs.
	transaction_state TransactionState
	// transaction_id is the current active transaction ID, or zero if there is
	// no active transaction. If there is no active transaction, each statement
	// will be given an implicit transaction.
	transaction_id u64
	// isolation_depth is the number of isolation blocks that are open, so that
	// an isolation block inside another one (such as delete_table calling
	// delete_identity) is part of the same implicit transaction.
	isolation_depth int
	// transaction_pages contains all the page numbers that have been modified
	// during this transaction. This is important for COMMIT and ROLLBACK to
	// revisit pages that need to be cleaned up or frozen.
	transaction_pages map[int]bool
	// Like the tables we keep the schemas in memory.
	schemas map[string]Schema
	// read_only is true when the file is only locked for reading. A read only
	// statement (outside of an explicit transaction) uses a transaction ID of 0
	// because it must not modify the header, see isolation_start.
	read_only bool
	// file_pager is the pager of btree when the database is a file. It holds
	// the pages changed by the current statement until commit.
	file_pager &FilePager = unsafe { nil }
	// snapshot is the state before the current statement that changes the
	// database, see begin_statement.
	snapshot StatementSnapshot
	// sequence_values contains the values of sequences changed by the current
	// statement, so that they can be kept if it fails, see discard_statement.
	sequence_values map[string]PageObject
	// session is held for as long as the connection is open. It is used to
	// detect transactions left behind by connections that no longer exist. See
	// recover().
	session SessionLock
	// isolation_error is the first error from isolation_end in end_isolation,
	// which the statement must fail with, see take_isolation_error.
	isolation_error ?IError
	// constraint_modes are the constraint modes set by SET CONSTRAINTS for the
	// current (or next) transaction, true for DEFERRED, keyed by the schema
	// and name of the constraint (see constraint_key). A deferrable constraint
	// that isn't here has its initial constraint mode.
	constraint_modes map[string]bool
	// deferred_checks are the deferred constraints that a statement in the
	// current transaction didn't check, with the storage ID of their table.
	// Each is checked against every row of its table once it's immediate (see
	// check_deferred_constraints).
	deferred_checks map[string]string
}

// StatementSnapshot is the state of Storage that is kept in memory, from before
// a statement that changes the database. A statement that fails must not
// change anything (ISO/IEC 9075-2:2016(E), 4.39.5), so this is put back, and
// the pages it changed are never written.
struct StatementSnapshot {
	header            Header
	tables            map[string]Table
	schemas           map[string]Schema
	transaction_state TransactionState
	transaction_id    u64
	transaction_pages map[int]bool
	isolation_depth   int
}

// begin_statement must be called at the start of a statement that changes the
// database, once the file is locked. The statement must end with either
// commit_statement or discard_statement.
fn (mut f Storage) begin_statement() {
	f.snapshot = StatementSnapshot{
		header:            Header{
			...f.header
			reserved: f.header.reserved.clone()
		}
		tables:            f.tables.clone()
		schemas:           f.schemas.clone()
		transaction_state: f.transaction_state
		transaction_id:    f.transaction_id
		isolation_depth:   f.isolation_depth
		transaction_pages: f.transaction_pages.clone()
	}
	f.btree.written_pages = map[int]bool{}
	f.sequence_values = map[string]PageObject{}
}

// commit_statement keeps the changes made by the current statement. For a file,
// they are written through the write-ahead log, see commit.
fn (mut f Storage) commit_statement(path string) ! {
	if path == ':memory:' {
		mut pager := f.btree.pager
		if mut pager is MemoryPager {
			pager.commit()
		}

		return
	}

	f.commit(path)!
}

// discard_statement forgets the changes made by the current statement, because
// it failed. Except that values issued by sequences are kept: "changes to the
// current base value of a sequence generator are not controlled by
// SQL-transactions" (ISO/IEC 9075-2:2016(E), 4.27.2).
fn (mut f Storage) discard_statement(path string) ! {
	sequence_values := f.sequence_values.clone()

	f.header = f.snapshot.header
	f.tables = f.snapshot.tables.clone()
	f.schemas = f.snapshot.schemas.clone()
	f.transaction_state = f.snapshot.transaction_state
	f.transaction_id = f.snapshot.transaction_id
	f.isolation_depth = f.snapshot.isolation_depth
	f.transaction_pages = f.snapshot.transaction_pages.clone()
	f.btree.pager.discard()
	f.btree.written_pages = map[int]bool{}
	f.sequence_values = map[string]PageObject{}

	if sequence_values.len > 0 {
		for _, obj in sequence_values {
			f.btree.replace_value(obj, obj.value)!
		}

		f.commit_statement(path)!
	}
}

fn new_storage(btree Btree) Storage {
	return Storage{
		btree: btree
	}
}

// open_file must be called before the file is locked, since the lock is placed
// on the file that is opened.
fn (mut f Storage) open_file(path string) ! {
	fault_point('open')!
	// The "b" is needed on Windows, otherwise the file is opened in text mode.
	f.file = os.open_file(path, 'rb+') or { return sqlstate_58030('unable to open ${path}: ${err}') }
}

// open must be called after open_file and the file being locked. exclusive
// must only be true if the file is locked exclusively.
fn (mut f Storage) open(catalog_name string, exclusive bool) ! {
	fault_point('read_header')!
	mut header := read_header(mut f.file)!
	f.read_only = !exclusive

	f.file_pager = new_file_pager(mut f.file, header.page_size, header.root_page)!
	f.btree = new_btree(f.file_pager, header.page_size)

	if exclusive && f.other_transaction_ids(header).len > 0 {
		if f.session.try_exclusive()! {
			// The session lock must go back to shared even if recovering fails,
			// otherwise no other connection can open the database.
			f.recover(mut header) or {
				f.session.shared() or {}
				return err
			}
			f.session.shared()!
		}
	}

	// Avoid reloading the schema if it hasn't changed.
	if header.schema_version == f.header.schema_version {
		f.header = header
		return
	}
	f.header = header

	f.load_schema(catalog_name)!
}

// load_schema reads the tables and schemas that are visible to the current
// transaction from the file.
fn (mut f Storage) load_schema(catalog_name string) ! {
	// The schema must be read in an isolation block, which may or may not
	// belong to an active transaction.
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.tables = map[string]Table{}
	mut iter := f.btree.new_range_iterator('T'.bytes(), 'U'.bytes())
	for {
		object := iter.next() or { break }
		if object_is_visible(object.tid, object.xid, f.transaction_id, mut
			f.header.active_transaction_ids)
		{
			table := new_table_from_bytes(object.key, object.value, object.tid, catalog_name)!
			f.tables[table.name.storage_id()] = table
		}
	}
	if err := iter.err {
		return err
	}

	f.schemas = map[string]Schema{}
	iter = f.btree.new_range_iterator('S'.bytes(), 'T'.bytes())
	for {
		object := iter.next() or { break }
		if object_is_visible(object.tid, object.xid, f.transaction_id, mut
			f.header.active_transaction_ids)
		{
			schema := new_schema_from_bytes(object.value, object.tid)!
			f.schemas[schema.name] = schema
		}
	}
	if err := iter.err {
		return err
	}
}

// parse_definition parses the definition of a schema object (such as a table),
// which is stored in the file as SQL. See "Schema Objects" in the "File Format"
// docs.
fn parse_definition(data []u8) !Stmt {
	return parse_tokens(tokenize(data.bytestr())!)
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
				page.expire(obj.key, obj.tid, 0)!
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

// commit must be called before a file that was locked exclusively is unlocked
// and closed. The pages changed by the statement and the header are written to
// the file through the write-ahead log, see wal_commit.
fn (mut f Storage) commit(path string) ! {
	f.header.root_page = f.btree.pager.root_page()

	wal_commit(mut f.file, path, f.header, f.file_pager) or { return io_error(err) }
}

fn (mut f Storage) close_file() {
	f.file.close()
}

// table returns the definition of a table, which the caller has already found
// (such as with Connection.resolve_table_identifier). A Table contains pointers
// (in the search condition of a CHECK constraint), so V would otherwise need an
// "or" block that's never used.
fn (f Storage) table(storage_id string) Table {
	return unsafe { f.tables[storage_id] }
}

fn (mut f Storage) create_table(definition Table) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.check_concurrent_referenced_tables(definition, [])!

	f.header.table_id++
	table := Table{
		...definition
		tid: f.transaction_id
		id:  f.header.table_id
	}

	obj := new_page_object(table_object_key(table.id), f.transaction_id, 0, table.bytes())
	f.btree.add(obj)!

	if column := table.identity_column() {
		f.add_identity(table.id, (column.identity or { IdentityColumn{} }).sequence)!
	}

	f.tables[table.name.storage_id()] = table
	f.schema_changed()
}

// schema_constraint_names are the names of the constraints of the tables in the
// schema of the table, other than the table itself.
fn (f Storage) schema_constraint_names(table_name Identifier) []string {
	mut names := []string{}
	for _, table in f.tables {
		if table.name.schema_name == table_name.schema_name
			&& table.name.storage_id() != table_name.storage_id() {
			names << table.constraint_names()
		}
	}

	return names
}

// update_table replaces the definition of a table, which has the same id, with
// a new version (such as from an ALTER TABLE).
fn (mut f Storage) update_table(definition Table) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.check_concurrent_rows(definition)!
	f.check_concurrent_referenced_tables(definition, f.table(definition.name.storage_id()).foreign_keys)!

	table := Table{
		...definition
		tid: f.transaction_id
	}
	f.btree.update(new_page_object(table_object_key(table.id), f.transaction_id, 0,
		table.bytes()))!

	f.tables[table.name.storage_id()] = table
	f.schema_changed()
}

fn (mut f Storage) create_schema(schema_name string) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	schema := Schema{
		tid:  f.transaction_id
		name: schema_name
	}

	obj := new_page_object('S${schema_name}'.bytes(), f.transaction_id, 0, schema.bytes())
	f.btree.add(obj)!

	f.schemas[schema_name] = schema
	f.schema_changed()
}

fn (mut f Storage) create_sequence(sequence Sequence) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	// The sequence defintion.
	obj1 := new_page_object('Q${sequence.name.storage_id()}'.bytes(), f.transaction_id, 0,
		sequence.definition_bytes())
	f.btree.add(obj1)!

	// The value for the sequence is stored as a separate object so that NEXT
	// VALUE FOR can change it outside of any transaction isolation (see
	// sequence_next_value). It's created in this transaction, so that it's
	// removed by a ROLLBACK.
	obj2 := new_page_object('V${sequence.name.storage_id()}'.bytes(), f.transaction_id, 0,
		sequence.value_bytes())
	f.btree.add(obj2)!
}

fn (mut f Storage) sequence(name Identifier) !Sequence {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	value_object := f.sequence_value_object(name.storage_id()) or {
		return sqlstate_42p01('sequence', name.str()) // sequence does not exist
	}

	definition_key := 'Q${name.storage_id()}'.bytes()
	definition_objects := f.read_objects(definition_key, definition_key)!
	if definition_objects.len == 0 {
		return sqlstate_42p01('sequence', name.str()) // sequence does not exist
	}

	sequence := new_sequence_from_bytes(definition_objects[0].value, value_object.value,
		definition_objects[0].tid)!

	return sequence
}

fn (mut f Storage) sequences() ![]Sequence {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	mut sequences := []Sequence{}
	for definition_object in f.read_objects('Q'.bytes(), 'R'.bytes())! {
		value_object := f.sequence_value_object(definition_object.key[1..].bytestr())!
		sequences << new_sequence_from_bytes(definition_object.value, value_object.value,
			definition_object.tid)!
	}

	return sequences
}

fn (mut f Storage) sequence_next_value(name Identifier) !i64 {
	// This would be a bug. See PreparedStmt.writes.
	if f.read_only {
		return sqlstate_xx000('cannot use NEXT VALUE FOR without a write connection')
	}

	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	mut sequence := f.sequence(name)!
	next_sequence := sequence.next()!

	// The new value is not part of the transaction, so the version that's
	// visible is changed in place, rather than creating a new version.
	value_object := f.sequence_value_object(name.storage_id())!
	new_value := next_sequence.value_bytes()
	f.btree.replace_value(value_object, new_value)!
	f.sequence_values['${value_object.key.bytestr()}:${value_object.tid}'] = PageObject{
		...value_object
		value: new_value
	}

	return next_sequence.current_value
}

// sequence_value_object returns the version of the value of a sequence that is
// visible to the current transaction.
fn (mut f Storage) sequence_value_object(storage_id string) !PageObject {
	key := 'V${storage_id}'.bytes()
	objects := f.read_objects(key, key)!
	if objects.len == 0 {
		return sqlstate_xx001('no value for sequence ${storage_id}')
	}

	return objects[0]
}

fn (mut f Storage) update_sequence(old_sequence Sequence, new_sequence Sequence) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	mut canonical_name := new_sequence.name.storage_id()
	definition_key := 'Q${canonical_name}'.bytes()

	new_obj := new_page_object(definition_key, f.transaction_id, 0, new_sequence.definition_bytes())
	f.btree.update(new_obj)!

	// A new value (such as from RESTART) is a new version, so that it's undone
	// by a ROLLBACK.
	if new_sequence.current_value != old_sequence.current_value
		|| new_sequence.exhausted != old_sequence.exhausted
		|| new_sequence.unused != old_sequence.unused {
		old_value_obj := f.sequence_value_object(canonical_name)!
		new_value_obj := new_page_object(old_value_obj.key, f.transaction_id, 0, new_sequence.value_bytes())
		f.btree.update(new_value_obj)!
	}
}

// create_identity stores the current value of the sequence of the identity
// column that's added to a table (see AddColumnDefinition).
fn (mut f Storage) create_identity(table_id u64, sequence Sequence) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.add_identity(table_id, sequence)!
}

// add_identity adds the current value of the sequence of the identity column of
// a table. Like the value of a sequence (see create_sequence), it's a separate
// object, so that it can be changed outside of any transaction isolation (see
// identity_next_value), and it's created in this transaction.
fn (mut f Storage) add_identity(table_id u64, sequence Sequence) ! {
	f.btree.add(new_page_object(identity_key(table_id), f.transaction_id, 0, sequence.value_bytes()))!
}

// identity_sequence returns the sequence of the identity column of a table,
// with its current value.
fn (mut f Storage) identity_sequence(table Table) !Sequence {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	column := table.identity_column() or {
		return sqlstate_xx000('table ${table.name} has no identity column')
	}
	value_object := f.identity_value_object(table.id)!

	return (column.identity or { IdentityColumn{} }).sequence.with_value(value_object.value)
}

// identity_next_value returns the next value of the identity column of a table,
// the same way as NEXT VALUE FOR (see sequence_next_value).
fn (mut f Storage) identity_next_value(table Table) !i64 {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	next_sequence := f.identity_sequence(table)!.next()!
	value_object := f.identity_value_object(table.id)!
	new_value := next_sequence.value_bytes()
	f.btree.replace_value(value_object, new_value)!
	f.sequence_values['${value_object.key.bytestr()}:${value_object.tid}'] = PageObject{
		...value_object
		value: new_value
	}

	return next_sequence.current_value
}

// update_identity changes the current value of the sequence of the identity
// column of a table (such as from RESTART). It's a new version, so that it's
// undone by a ROLLBACK.
fn (mut f Storage) update_identity(table_id u64, sequence Sequence) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.btree.update(new_page_object(identity_key(table_id), f.transaction_id, 0, sequence.value_bytes()))!
}

// delete_identity expires the current value of the sequence of the identity
// column of a table, when the column or the table is dropped.
fn (mut f Storage) delete_identity(table_id u64) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	value_object := f.identity_value_object(table_id)!
	f.btree.expire(value_object.key, value_object.tid, f.transaction_id)!
}

fn (mut f Storage) identity_value_object(table_id u64) !PageObject {
	key := identity_key(table_id)
	objects := f.read_objects(key, key)!
	if objects.len == 0 {
		return sqlstate_xx001('no identity value for table ${table_id}')
	}

	return objects[0]
}

fn (mut f Storage) delete_table(table_name string, tid u64) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.check_concurrent_rows(f.table(table_name))!
	f.check_concurrent_references(f.table(table_name))!

	table_id := f.table(table_name).id
	f.btree.expire(table_object_key(table_id), tid, f.transaction_id)!
	if _ := f.table(table_name).identity_column() {
		f.delete_identity(table_id)!
	}

	// The rows are expired the same way as a DELETE, so they are removed when
	// the transaction ends.
	for object in f.read_objects(row_key_prefix(table_id), row_key_prefix(table_id + 1))! {
		f.btree.expire(object.key, object.tid, f.transaction_id)!
	}

	f.tables.delete(table_name)
	f.schema_changed()
}

fn (mut f Storage) delete_schema(schema_name string, tid u64) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.btree.expire('S${schema_name}'.bytes(), tid, f.transaction_id)!

	f.schemas.delete(schema_name)
	f.schema_changed()
}

fn (mut f Storage) delete_sequence(name Identifier, tid u64) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	value_obj := f.sequence_value_object(name.storage_id())!
	f.btree.expire('Q${name.storage_id()}'.bytes(), tid, f.transaction_id)!
	f.btree.expire(value_obj.key, value_obj.tid, f.transaction_id)!
}

fn (mut f Storage) delete_row(table_name string, mut row Row) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.check_concurrent_definition(f.table(table_name))!
	f.check_concurrent_references(f.table(table_name))!
	page_number := f.btree.expire(row.object_key(f.table(table_name))!, row.tid, f.transaction_id)!

	// A negative page_number means the object didn't exist so there's nothing to
	// save. This should not be possible because the delete_row will only be
	// issued on a row that already exists, but I guess to be safe let's not let
	// it panic.
	if page_number < 0 {
		return sqlstate_xx001('DELETE: integrity issue, preventing panic')
	}
}

fn (mut f Storage) write_row(mut r Row, t Table) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.check_concurrent_definition(t)!
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

// update_row replaces a row with a new version that has the same key. A row
// that gets a new PRIMARY KEY is deleted and written again instead (see
// UpdateStatementSearched).
fn (mut f Storage) update_row(mut new Row, t Table) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.check_concurrent_definition(t)!
	f.check_concurrent_references(t)!
	f.assign_row_id(mut new, t)
	f.btree.update(new_page_object(new.object_key(t)!, f.transaction_id, 0, new.bytes(t)))!
}

// check_concurrent_definition returns a SQLSTATE 40001 if another active
// transaction has changed or dropped the definition of t. Otherwise, a row
// written with the old definition would not have the columns (or pass the
// constraints) of the new one, or would be written into a dropped table. It must
// be called from inside an isolation block.
fn (mut f Storage) check_concurrent_definition(t Table) ! {
	f.check_concurrent_objects(table_object_key(t.id), table_object_key(t.id))!
}

// check_concurrent_rows returns a SQLSTATE 40001 if another active transaction
// has written or deleted a row of t. Those rows are not visible, so ALTER TABLE
// and DROP TABLE would otherwise miss them. It must be called from inside an
// isolation block.
fn (mut f Storage) check_concurrent_rows(t Table) ! {
	f.check_concurrent_objects(row_key_prefix(t.id), row_key_prefix(t.id + 1))!
}

// check_concurrent_referenced_tables returns a SQLSTATE 40001 if another active
// transaction has changed, dropped or written a row of a table that's
// referenced by a FOREIGN KEY of definition (other than the old_keys it already
// had). Those changes are not visible, so the rows of definition would otherwise
// not be checked against them. It must be called from inside an isolation
// block.
fn (mut f Storage) check_concurrent_referenced_tables(definition Table, old_keys []ForeignKey) ! {
	old := old_keys.map(it.str())
	for key in definition.foreign_keys {
		referenced := f.tables[key.referenced_table.storage_id()] or { continue }
		if key.str() !in old {
			f.check_concurrent_definition(referenced)!
			f.check_concurrent_rows(referenced)!
		}
	}
}

// check_concurrent_references returns a SQLSTATE 40001 if another active
// transaction has created, changed or dropped a table with a FOREIGN KEY that
// references t. That definition is not visible, so deleting or updating a row
// of t would otherwise not check the rows that reference it. It must be called
// from inside an isolation block.
fn (mut f Storage) check_concurrent_references(t Table) ! {
	mut iter := f.btree.new_range_iterator('T'.bytes(), 'U'.bytes())
	for {
		object := iter.next() or { break }
		if !f.is_concurrent_write(object) {
			continue
		}

		referencing := new_table_from_bytes(object.key, object.value, object.tid, t.name.catalog_name)!
		for key in referencing.foreign_keys {
			if key.referenced_table.storage_id() == t.name.storage_id() {
				return sqlstate_40001('avoiding concurrent write on referencing table definition')
			}
		}
	}
	if err := iter.err {
		return err
	}
}

fn (mut f Storage) check_concurrent_objects(start []u8, end []u8) ! {
	mut iter := f.btree.new_range_iterator(start, end)
	for {
		object := iter.next() or { break }
		if f.is_concurrent_write(object) {
			return sqlstate_40001('avoiding concurrent write on table definition')
		}
	}
	if err := iter.err {
		return err
	}
}

fn (mut f Storage) read_rows(table_name Identifier) ![]Row {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	mut rows := []Row{}

	table := f.table(table_name.storage_id())
	for object in f.read_objects(row_key_prefix(table.id), row_key_prefix(table.id + 1))! {
		rows << new_row_from_bytes(table, object.value, object.tid)
	}

	return rows
}

fn (mut f Storage) read_objects(start []u8, end []u8) ![]PageObject {
	mut objs := []PageObject{}
	mut iter := f.btree.new_range_iterator(start, end)
	for {
		object := iter.next() or { break }
		if object_is_visible(object.tid, object.xid, f.transaction_id, mut
			f.header.active_transaction_ids)
		{
			objs << object
		}
	}
	if err := iter.err {
		return err
	}

	return objs
}

// isolation_start signals the start of an operation that shall be atomic until
// isolation_end is invoked. If there is no active transaction, a new
// transaction will be created. Otherwise, this isolation block will be part of
// the current transaction.
fn (mut f Storage) isolation_start() ! {
	fault_point('isolation_start')!

	match f.transaction_state {
		.not_active {
			// Fallthrough to the logic below.
		}
		.active {
			return
		}
	}

	// An isolation block inside another one is part of its implicit
	// transaction.
	if f.isolation_depth > 0 {
		f.isolation_depth++
		return
	}

	// A reader holds a shared lock, so it must not write to the header. It
	// doesn't need its own transaction ID either: no writer can run while the
	// lock is held, and with an ID of 0 only committed objects (and objects
	// deleted by transactions that are still active) are visible.
	if f.read_only {
		f.transaction_id = 0
		f.isolation_depth = 1
		return
	}

	f.header.transaction_id++

	f.transaction_id = f.header.transaction_id
	f.header.active_transaction_ids.add(f.transaction_id)!
	f.isolation_depth = 1
}

// end_isolation is isolation_end for a defer, which can't return an error. The
// error is kept for take_isolation_error instead, so that the statement fails
// (and is discarded) rather than the process stopping.
fn (mut f Storage) end_isolation() {
	f.isolation_end() or {
		if f.isolation_error == none {
			f.isolation_error = err
		}
	}
}

// take_isolation_error returns (and forgets) the error from end_isolation, if
// there was one.
fn (mut f Storage) take_isolation_error() ! {
	if err := f.isolation_error {
		f.isolation_error = none
		return err
	}
}

// isolation_end must be called at some point after isolation_start to signal
// the end of the atomic blocks. At the moment blocks cannot be nested so the
// state of the active or implicit transaction state is expected to be
// maintained.
fn (mut f Storage) isolation_end() ! {
	// The implicit transaction ends with the outermost isolation block. This
	// is counted before anything can fail, so that the next statement still
	// starts its own transaction.
	if f.transaction_state == .not_active {
		f.isolation_depth--
	}

	fault_point('isolation_end')!

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
		.active {
			// Do nothing. COMMIT, ROLLBACK or some other transaction terminator
			// will take care of this later.
			return
		}
	}

	if f.isolation_depth > 0 || f.read_only {
		return
	}

	// Revist any remaining pages to clean out any expired rows.
	mut blob_refs := []PageObject{}
	for page_number, _ in f.transaction_pages {
		mut page := f.btree.pager.fetch_page(page_number)!
		for obj in page.objects() {
			// Only remove the objects expired in this transaction.
			if obj.xid == f.transaction_id {
				page.delete(obj.key, obj.tid)
				if obj.is_blob_ref {
					blob_refs << obj
				}
			}
		}

		f.btree.pager.store_page(page_number, page)!
	}

	for obj in blob_refs {
		f.btree.remove_blob(obj)!
	}

	f.transaction_pages = map[int]bool{}

	f.header.active_transaction_ids.remove(f.transaction_id)
}
