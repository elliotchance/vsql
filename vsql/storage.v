// storage.v acts as the gateway for common operations against the raw objects
// on from the pager, such as fetching tables and rows.
//
// Storage is maintained over individual operations on the file because it
// caches the schema.

module vsql

import os

// The concept is described by ISO/IEC 9075-1:2003(E), 4.2.11, SQL-data.

enum TransactionState {
	not_active
	// reading is an SQL-transaction (started by START TRANSACTION, not an
	// implicit transaction) that hasn't changed anything yet. It doesn't have a
	// transaction ID, so it doesn't need a write lock or a change to the
	// header, and it works on a database that can only be read. Each statement
	// reads like a statement on its own (see isolation_start), and a
	// SERIALIZABLE transaction is kept isolated by the isolation lock (see
	// isolation.v). A REPEATABLE READ transaction is only in this state if the
	// database could only be read when it started, see snapshot_pending. The
	// first statement that changes the database makes it active, see
	// CatalogConnection.open_write_connection.
	reading
	// Whilst in a transaction (specifically START TRANSACTION, not an implicit
	// transaction) that has changed the database. This is important to stop a
	// nested transaction from starting or closing an unstarted transaction.
	active
}

struct Storage {
mut:
	header Header
	// cache_size is the number of pages the pager of each operation keeps in
	// memory, see ConnectionOptions.cache_size.
	cache_size int
	// btree is replaced for each operation (because it needs a new pager for
	// each operation).
	btree Btree
	// We keep the table definitions in memory because they are needed for most
	// operations (including read and writing rows). All tables must be loaded
	// when the database is opened.
	tables map[string]Table
	// file is opened by the first statement and stays open (but is only locked
	// during each statement) until the connection is closed, because opening
	// and closing it takes longer than the statement. It's unbuffered, so
	// nothing read before the lock is used. file_identity is used to open it
	// again if the file at the path is replaced, see lock_file.
	file          os.File
	file_identity FileIdentity
	// log is the write-ahead log, which also stays open.
	log WalLog
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
	// transaction_keys contains the key of every object that has been created
	// or expired during an explicit transaction. Another connection can split
	// a page while the transaction is active, which moves its objects to a
	// page that isn't in transaction_pages, see transaction_page_numbers.
	transaction_keys map[string]bool
	// Like the tables we keep the schemas in memory.
	schemas map[string]Schema
	// The indexes are also kept in memory, because every write to a table must
	// change its indexes. They're keyed by the storage_id of their name (which
	// is in the schema of their table).
	indexes map[string]Index
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
	// isolation is locked by REPEATABLE READ and SERIALIZABLE transactions, and
	// when committing changes, see isolation.v.
	isolation IsolationLock
	// commit_locked is true when the current statement has checked that it can
	// commit, see lock_commit.
	commit_locked bool
	// wal_prepared is the current statement once it has been added to the
	// write-ahead log, but not committed yet, see prepare_commit.
	wal_prepared ?WalPrepared
	// snapshot_isolation is true while a REPEATABLE READ transaction is active,
	// which sees transaction_snapshot (see take_snapshot).
	snapshot_isolation   bool
	transaction_snapshot TransactionSnapshot
	// snapshot_pending is true for a REPEATABLE READ transaction that hasn't
	// taken its snapshot yet, because the database could only be read when it
	// started (see CatalogConnection.start_transaction). It takes it when it
	// first changes the database (see begin_transaction). Until then, nothing
	// it can't see may have committed since snapshot_header, which was the
	// header when it started, since a COMMIT may remove the versions of rows
	// that it would have to see (see remove_expired). So a statement fails
	// with a serialization failure if a transaction has ended since then, see
	// open.
	snapshot_pending bool
	snapshot_header  Header
}

// StatementSnapshot is the state of Storage that is kept in memory, from before
// a statement that changes the database. A statement that fails must not
// change anything (ISO/IEC 9075-2:2016(E), 4.39.5), so this is put back, and
// the pages it changed are never written.
struct StatementSnapshot {
mut:
	header            Header
	tables            map[string]Table
	schemas           map[string]Schema
	indexes           map[string]Index
	transaction_state TransactionState
	transaction_id    u64
	transaction_pages map[int]bool
	transaction_keys  map[string]bool
	isolation_depth   int
	// snapshot_isolation and transaction_snapshot are put back because a
	// START TRANSACTION, COMMIT or ROLLBACK that fails doesn't change them.
	snapshot_isolation   bool
	transaction_snapshot TransactionSnapshot
	// in_statement is true between begin_statement and the end of the
	// statement.
	in_statement bool
	// schema_saved is true once tables, schemas and indexes have been copied
	// (see save_schema), and pages_saved once transaction_pages has been (see
	// save_transaction_pages). They aren't copied by begin_statement because
	// most statements don't change them.
	schema_saved bool
	pages_saved  bool
	// added_pages and added_keys are what the statement added to
	// transaction_pages and transaction_keys (see add_transaction_pages), so
	// that they can be removed if it fails. They're used instead of copying
	// them, because they get bigger with every statement of a transaction.
	added_pages []int
	added_keys  []string
}

// begin_statement must be called at the start of a statement that changes the
// database, once the file is locked. The statement must end with either
// commit_statement or discard_statement.
fn (mut f Storage) begin_statement() {
	f.snapshot = StatementSnapshot{
		header:               Header{
			...f.header
			reserved: f.header.reserved.clone()
		}
		transaction_state:    f.transaction_state
		transaction_id:       f.transaction_id
		isolation_depth:      f.isolation_depth
		snapshot_isolation:   f.snapshot_isolation
		transaction_snapshot: f.transaction_snapshot
		in_statement:         true
	}
	f.btree.written_pages = map[int]bool{}
	f.btree.written_keys = map[string]bool{}
	f.sequence_values = map[string]PageObject{}
}

// save_schema must be called before tables, schemas or indexes are changed, so
// that they can be put back if the statement fails.
fn (mut f Storage) save_schema() {
	if f.snapshot.in_statement && !f.snapshot.schema_saved {
		f.snapshot.tables = f.tables.clone()
		f.snapshot.schemas = f.schemas.clone()
		f.snapshot.indexes = f.indexes.clone()
		f.snapshot.schema_saved = true
	}
}

// save_transaction_pages must be called before transaction_pages (or
// transaction_keys) is replaced, so that it can be put back if the statement
// fails. Adding to them is add_transaction_pages.
fn (mut f Storage) save_transaction_pages() {
	if f.snapshot.in_statement && !f.snapshot.pages_saved {
		f.snapshot.transaction_pages = f.transaction_pages.clone()
		f.snapshot.transaction_keys = f.transaction_keys.clone()
		f.snapshot.pages_saved = true
	}
}

// add_transaction_pages adds the pages and keys that the B-tree wrote to the
// transaction. Only the ones that are new are remembered, so that they can be
// removed if the statement fails (see discard_statement).
fn (mut f Storage) add_transaction_pages(keys bool) {
	for page_number, _ in f.btree.written_pages {
		if page_number !in f.transaction_pages {
			f.transaction_pages[page_number] = true
			if f.snapshot.in_statement {
				f.snapshot.added_pages << page_number
			}
		}
	}

	if keys {
		for key, _ in f.btree.written_keys {
			if key !in f.transaction_keys {
				f.transaction_keys[key] = true
				if f.snapshot.in_statement {
					f.snapshot.added_keys << key
				}
			}
		}
	}
}

// transaction_page_numbers returns the pages that can have objects created or
// expired by the explicit transaction: the pages that it changed, and the page
// that each key it wrote is on now. Another connection can split a page while
// the transaction is active (it doesn't hold the file between statements),
// which moves objects into a new page that this connection never wrote. COMMIT
// and ROLLBACK would otherwise miss them, leaving a rolled back change visible,
// or an expired version that stops the row from being changed again. A split
// keeps the versions of a key together (see split_objects), so they're all on
// the page that the key is found on.
fn (mut f Storage) transaction_page_numbers() ![]int {
	mut pages := f.transaction_pages.clone()
	for key, _ in f.transaction_keys {
		path, _ := f.btree.search_page(key.bytes())!
		pages[path.last()] = true
	}

	return pages.keys()
}

// commit_statement keeps the changes made by the current statement. For a file,
// they are written through the write-ahead log, see wal_prepare and wal_finish.
fn (mut f Storage) commit_statement(path string) ! {
	f.prepare_commit(path)!
	f.finish_commit(path)!
}

// prepare_commit is the first half of commit_statement, which does everything
// that's likely to fail without committing anything, see wal_prepare. It must
// be followed by finish_commit, or by discard_statement to give up.
fn (mut f Storage) prepare_commit(path string) ! {
	if path == ':memory:' {
		return
	}

	f.header.root_page = f.btree.pager.root_page()
	f.wal_prepared = wal_prepare(mut f.file, path, mut f.log, f.header, f.file_pager,
		f.transaction_state == .active) or {
		return io_error(err)
	}
}

// finish_commit is the second half of commit_statement, after prepare_commit.
fn (mut f Storage) finish_commit(path string) ! {
	f.snapshot.in_statement = false
	if path == ':memory:' {
		mut pager := f.btree.pager
		if mut pager is MemoryPager {
			pager.commit()
		}

		return
	}

	mut prepared := f.wal_prepared or { WalPrepared{} }
	f.wal_prepared = none
	wal_finish(mut f.file, path, mut prepared) or { return io_error(err) }
	f.log.finished(prepared)
}

// discard_statement forgets the changes made by the current statement, because
// it failed. Except that values issued by sequences are kept: "changes to the
// current base value of a sequence generator are not controlled by
// SQL-transactions" (ISO/IEC 9075-2:2016(E), 4.27.2).
fn (mut f Storage) discard_statement(path string) ! {
	sequence_values := f.sequence_values.clone()

	// The frames already in the log are ignored without a commit frame, and
	// the log stays open for the next statement.
	f.wal_prepared = none

	f.header = f.snapshot.header
	if f.snapshot.schema_saved {
		f.tables = f.snapshot.tables.clone()
		f.schemas = f.snapshot.schemas.clone()
		f.indexes = f.snapshot.indexes.clone()
	}
	f.transaction_state = f.snapshot.transaction_state
	f.transaction_id = f.snapshot.transaction_id
	f.isolation_depth = f.snapshot.isolation_depth
	f.snapshot_isolation = f.snapshot.snapshot_isolation
	f.transaction_snapshot = f.snapshot.transaction_snapshot
	// A transaction that still hasn't changed anything has no rows for a
	// deferred constraint to check, and COMMIT doesn't lock its file to check
	// them (see TransactionState).
	if f.transaction_state == .reading {
		f.deferred_checks = map[string]string{}
	}
	if f.snapshot.pages_saved {
		f.transaction_pages = f.snapshot.transaction_pages.clone()
		f.transaction_keys = f.snapshot.transaction_keys.clone()
	}
	// The copy may have been made after the statement added to them.
	for page_number in f.snapshot.added_pages {
		f.transaction_pages.delete(page_number)
	}
	for key in f.snapshot.added_keys {
		f.transaction_keys.delete(key)
	}
	f.snapshot.in_statement = false
	f.btree.pager.discard()
	f.btree.written_pages = map[int]bool{}
	f.btree.written_keys = map[string]bool{}
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
// on the file that is opened. It does nothing if the file is already open.
fn (mut f Storage) open_file(path string) ! {
	fault_point('open')!
	if f.file.is_opened {
		return
	}

	// The "b" is needed on Windows, otherwise the file is opened in text mode.
	f.file = os.open_file(path, 'rb+') or { return sqlstate_58030('unable to open ${path}: ${err}') }
	f.file.set_unbuffered()
	f.file_identity = open_file_identity(f.file)
}

// open must be called after open_file and the file being locked. exclusive
// must only be true if the file is locked exclusively.
fn (mut f Storage) open(catalog_name string, exclusive bool) ! {
	fault_point('read_header')!
	mut header := read_header(mut f.file)!
	f.read_only = !exclusive

	f.file_pager = new_file_pager(mut f.file, header.page_size, header.root_page,
		f.cache_size)!
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

	if f.transaction_state == .reading && f.snapshot_pending
		&& header.has_ended_since(f.snapshot_header) {
		return sqlstate_40001('another connection has committed since this transaction started reading')
	}

	// Avoid reloading the schema if it hasn't changed.
	if header.schema_version == f.header.schema_version {
		f.header = header
		return
	}
	f.header = header

	f.load_schema(catalog_name)!
}

// load_schema reads the tables, schemas and indexes that are visible to the current
// transaction from the file.
fn (mut f Storage) load_schema(catalog_name string) ! {
	// The schema must be read in an isolation block, which may or may not
	// belong to an active transaction.
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.save_schema()
	f.tables = map[string]Table{}
	mut iter := f.btree.new_range_iterator('T'.bytes(), 'U'.bytes())
	for {
		object := iter.next() or { break }
		if f.is_visible(object.tid, object.xid) {
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
		if f.is_visible(object.tid, object.xid) {
			schema := new_schema_from_bytes(object.value, object.tid)!
			f.schemas[schema.name] = schema
		}
	}
	if err := iter.err {
		return err
	}

	f.load_indexes()!
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
		if tid != 0 && (f.transaction_state != .active || tid != f.transaction_id) {
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

	// A dead REPEATABLE READ transaction may have been the only one that
	// needed the versions that were kept for it.
	f.remove_retained_versions(header.active_transaction_ids)!

	// The dead transactions may have created or dropped tables, so any cached
	// schema must be reloaded.
	header.schema_version++
}

// schema_changed must be called when the schema is changed, so that other
// connections load it again. A REPEATABLE READ transaction can only change the
// schema if no other transaction has changed it since it started (or since its
// own last change), because the schema it can see might not be the latest one.
// That's stricter than it needs to be (any change to the schema counts), but
// it also covers names that are only unique once both transactions commit.
fn (mut f Storage) schema_changed() ! {
	if f.snapshot_isolation {
		if f.header.schema_version != f.transaction_snapshot.schema_version {
			return sqlstate_40001('avoiding concurrent change to the schema')
		}
		f.transaction_snapshot.schema_version = f.header.schema_version + 1
	}

	// We don't need to read the header again because write operations on a file
	// are exclusive so the version (and the header itself) we already have can
	// be incremented.
	f.header.schema_version++
}

// close_files closes the database file and the log, when the connection is
// closed, or when the file is replaced.
fn (mut f Storage) close_files() {
	f.file.close()
	f.log.file.close()
}

// table returns the definition of a table, which the caller has already found
// (such as with Connection.resolve_table_identifier). A Table contains pointers
// (in the search condition of a CHECK constraint), so V would otherwise need an
// "or" block that's never used.
fn (f Storage) table(storage_id string) Table {
	// With "or", an empty Table is only made when there's no table, rather
	// than for every lookup.
	return f.tables[storage_id] or { Table{} }
}

// is_referenced is true if a foreign key of any table (including the table
// itself) references the table.
fn (f &Storage) is_referenced(referenced_id string) bool {
	for _, table in f.tables {
		for key in table.foreign_keys {
			if key.referenced_table.storage_id() == referenced_id {
				return true
			}
		}
	}

	return false
}

// references is true when the table has a FOREIGN KEY that references the
// table with referenced_id (see Identifier.storage_id). It doesn't copy the
// table, so it's cheaper than looking at the foreign keys of table().
fn (f &Storage) references(storage_id string, referenced_id string) bool {
	foreign_keys := (f.tables[storage_id] or { return false }).foreign_keys
	for key in foreign_keys {
		if key.referenced_table.storage_id() == referenced_id {
			return true
		}
	}

	return false
}

fn (mut f Storage) create_table(definition Table) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.check_concurrent_referenced_tables(definition, [])!
	f.check_concurrent_name(`T`, definition.name)!

	f.header.table_id++
	table := Table{
		...definition
		tid: f.transaction_id
		id:  f.header.table_id
	}

	obj := new_page_object(table_object_key(table.id), f.transaction_id, 0, table.bytes())
	f.btree.add(obj)!

	if column := table.identity_column() {
		f.add_identity(table.id, (column.identity or { &IdentityColumn{} }).sequence)!
	}

	f.save_schema()
	f.tables[table.name.storage_id()] = table
	f.schema_changed()!

	// The fault makes a table like one from before indexes, which doesn't have
	// the indexes of its constraints until they're needed.
	if !fault_reached('constraint_index') {
		f.build_constraint_indexes(Table{}, table)!
	}
}

// schema_index_names are the names of the indexes in the schema of the table.
fn (f Storage) schema_index_names(table_name Identifier) []string {
	mut names := []string{}
	for _, index in f.indexes {
		if index.name.schema_name == table_name.schema_name {
			names << index.name.entity_name
		}
	}

	return names
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

	old := f.table(definition.name.storage_id())
	f.check_concurrent_rows(definition)!
	f.check_concurrent_referenced_tables(definition, old.foreign_keys)!

	table := Table{
		...definition
		tid: f.transaction_id
	}
	f.btree.update(new_page_object(table_object_key(table.id), f.transaction_id, 0,
		table.bytes()))!

	f.save_schema()
	f.tables[table.name.storage_id()] = table
	f.schema_changed()!
	f.build_constraint_indexes(old, table)!
}

fn (mut f Storage) create_schema(schema_name string) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	key := 'S${schema_name}'.bytes()
	if f.has_concurrent_objects(key, key)! {
		return sqlstate_40001('avoiding concurrent write on schema ${schema_name}')
	}

	schema := Schema{
		tid:  f.transaction_id
		name: schema_name
	}

	obj := new_page_object(key, f.transaction_id, 0, schema.bytes())
	f.btree.add(obj)!

	f.save_schema()
	f.schemas[schema_name] = schema
	f.schema_changed()!
}

fn (mut f Storage) create_sequence(sequence Sequence) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	// A sequence that another transaction is creating or dropping isn't visible,
	// see check_concurrent_name.
	key := 'Q${sequence.name.storage_id()}'.bytes()
	if f.has_concurrent_objects(key, key)! {
		return sqlstate_40001('avoiding concurrent write on sequence ${sequence.name}')
	}

	// The sequence defintion.
	obj1 := new_page_object(key, f.transaction_id, 0, sequence.definition_bytes())
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

	definition_key := 'Q${name.storage_id()}'.bytes()
	definition_objects := f.read_objects(definition_key, definition_key)!
	if definition_objects.len == 0 {
		return sqlstate_42p01('sequence', name.str()) // sequence does not exist
	}
	value_object := f.sequence_value_object(name.storage_id())!

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

// sequence_value_object returns the current version of the value of a
// sequence, see current_object.
fn (mut f Storage) sequence_value_object(storage_id string) !PageObject {
	return f.current_object('V${storage_id}'.bytes(), 'value for sequence ${storage_id}')
}

// current_object returns the version of the value of a sequence (or of an
// identity column) that's visible now. The value isn't part of any transaction
// (see sequence_next_value), so a REPEATABLE READ transaction uses the latest
// one, rather than the one in its snapshot. If there isn't one, but there was
// when it started, another transaction has dropped the sequence since then.
fn (mut f Storage) current_object(key []u8, description string) !PageObject {
	objects := f.read_current_objects(key, key)!
	if objects.len == 0 {
		if f.snapshot_isolation {
			return sqlstate_40001('avoiding concurrent write on sequence')
		}
		return sqlstate_xx001('no ${description}')
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

	return (column.identity or { &IdentityColumn{} }).sequence.with_value(value_object.value)
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
	return f.current_object(identity_key(table_id), 'identity value for table ${table_id}')
}

fn (mut f Storage) delete_table(table_name string, tid u64) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.check_concurrent_rows(f.table(table_name))!
	f.check_concurrent_references(f.table(table_name))!

	table_id := f.table(table_name).id
	for index in f.table_indexes(table_id) {
		f.delete_index(index)!
	}
	f.btree.expire(table_object_key(table_id), tid, f.transaction_id)!
	if _ := f.table(table_name).identity_column() {
		f.delete_identity(table_id)!
	}

	// The rows are expired the same way as a DELETE, so they are removed when
	// the transaction ends.
	for object in f.read_objects(row_key_prefix(table_id), row_key_prefix(table_id + 1))! {
		f.btree.expire(object.key, object.tid, f.transaction_id)!
	}

	f.save_schema()
	f.tables.delete(table_name)
	f.schema_changed()!
}

fn (mut f Storage) delete_schema(schema_name string, tid u64) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.btree.expire('S${schema_name}'.bytes(), tid, f.transaction_id)!

	f.save_schema()
	f.schemas.delete(schema_name)
	f.schema_changed()!
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
	f.delete_index_entries(f.table(table_name), row)!

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
	obj := new_page_object(r.object_key(t)!, f.transaction_id, 0, r.bytes(t)!)
	f.btree.add(obj)!
	f.add_index_entries(t, r)!
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

// update_row replaces a row (the old version) with a new version that has the
// same key. A row that gets a new PRIMARY KEY is deleted and written again
// instead (see UpdateStatementSearched).
fn (mut f Storage) update_row(old Row, mut new Row, t Table) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.check_concurrent_definition(t)!
	f.check_concurrent_references(t)!
	f.assign_row_id(mut new, t)
	f.btree.update(new_page_object(new.object_key(t)!, f.transaction_id, 0, new.bytes(t)!))!
	f.update_index_entries(t, old, new)!
}

// check_concurrent_definition returns a SQLSTATE 40001 if another active
// transaction has changed or dropped the definition of t, or created or dropped
// an index of t. Otherwise, a row written with the old definition would not
// have the columns (or pass the constraints) of the new one, would be written
// into a dropped table, or wouldn't be in an index that's being created. It must
// be called from inside an isolation block.
fn (mut f Storage) check_concurrent_definition(t Table) ! {
	f.check_concurrent_objects(table_object_key(t.id), table_object_key(t.id))!
	f.check_concurrent_objects(index_object_key(t.id, 0), index_object_key(t.id + 1, 0))!
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
	// Only another transaction can have written a concurrent object, so
	// there's no need to read them.
	if !f.may_have_concurrent_writes() {
		return
	}

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

// check_concurrent_name returns a SQLSTATE 40001 if another active transaction
// has created or dropped a table (when kind is `T`) or an index (`N`) with the
// same name. It isn't visible, so the name would otherwise be used twice once
// both transactions are committed. Whether it will exist depends on how that
// transaction ends, so it's a serialization failure rather than a duplicate
// name, the same as a PRIMARY KEY (see check_primary_key). It must be called
// from inside an isolation block.
fn (mut f Storage) check_concurrent_name(kind u8, name Identifier) ! {
	// Only another transaction can have written a concurrent object, so there's
	// no need to read them.
	if !f.may_have_concurrent_writes() {
		return
	}

	mut iter := f.btree.new_range_iterator([kind], [kind + 1])
	for {
		object := iter.next() or { break }
		if !f.is_concurrent_write(object) {
			continue
		}

		stmt := parse_definition(object.value)!
		mut other := Identifier{}
		if stmt is TableDefinition {
			other = stmt.table_name
		} else if stmt is CreateIndexStatement {
			other = Identifier{
				schema_name: stmt.table_name.schema_name
				entity_name: stmt.index_name.entity_name
			}
		}
		if other.schema_name == name.schema_name && other.entity_name == name.entity_name {
			kind_name := if kind == `T` { 'table' } else { 'index' }
			return sqlstate_40001('avoiding concurrent write on ${kind_name} ${name}')
		}
	}
	if err := iter.err {
		return err
	}
}

fn (mut f Storage) check_concurrent_objects(start []u8, end []u8) ! {
	if f.has_concurrent_objects(start, end)! {
		return sqlstate_40001('avoiding concurrent write on table definition')
	}
}

// has_concurrent_objects is true if another active transaction has created or
// expired an object from start to end (inclusive).
fn (mut f Storage) has_concurrent_objects(start []u8, end []u8) !bool {
	// Only another transaction can have written a concurrent object, so
	// there's no need to read them.
	if !f.may_have_concurrent_writes() {
		return false
	}

	mut iter := f.btree.new_range_iterator(start, end)
	for {
		object := iter.next() or { break }
		if f.is_concurrent_write(object) {
			return true
		}
	}
	if err := iter.err {
		return err
	}

	return false
}

fn (mut f Storage) read_rows(table_name Identifier) ![]Row {
	mut scanner := f.scan_rows(table_name, [])!
	defer {
		scanner.finish()
	}

	return scanner.next_rows(max_int)
}

// RowScanner reads the visible rows of a table, some at a time (see
// Plan.execute), so that they don't all need to be in memory at once. It's in
// an isolation block until finish is called.
struct RowScanner {
	table Table
	ids   []string
	// needed is whether each column is read, or empty for all of them, see
	// new_row_from_bytes_needed.
	needed []bool
mut:
	storage &Storage
	iter    PageIterator
}

fn (mut f Storage) scan_rows(table_name Identifier, needed []bool) !RowScanner {
	f.isolation_start()!
	table := f.table(table_name.storage_id())

	return RowScanner{
		table:   table
		ids:     table.column_ids()
		needed:  needed
		storage: unsafe { &f }
		iter:    f.btree.new_range_iterator(row_key_prefix(table.id), row_key_prefix(table.id + 1))
	}
}

// next_rows returns up to limit more rows, or none after the last row.
fn (mut s RowScanner) next_rows(limit int) ![]Row {
	mut rows := []Row{}
	for rows.len < limit {
		object := s.iter.next() or { break }
		if s.storage.is_visible(object.tid, object.xid) {
			rows << new_row_from_bytes_needed(s.table, s.ids, s.needed, object.value, object.tid)
		}
	}
	if err := s.iter.err {
		return err
	}

	return rows
}

// finish ends the isolation block of scan_rows.
fn (mut s RowScanner) finish() {
	s.storage.end_isolation()
}

// read_current_objects is read_objects, but without the snapshot of a
// REPEATABLE READ transaction, so it's the versions that are visible now.
fn (mut f Storage) read_current_objects(start []u8, end []u8) ![]PageObject {
	snapshot_isolation := f.snapshot_isolation
	f.snapshot_isolation = false
	defer {
		f.snapshot_isolation = snapshot_isolation
	}

	return f.read_objects(start, end)
}

// may_have_concurrent_writes is false when there can't be any objects that
// is_concurrent_write would be true for: no other transaction is active, and
// for a REPEATABLE READ transaction, none could have committed since it
// started.
fn (f &Storage) may_have_concurrent_writes() bool {
	return f.header.active_transaction_ids.has_other(f.transaction_id)
		|| (f.snapshot_isolation && (f.transaction_snapshot.active.len > 0
			|| f.header.transaction_id > f.transaction_snapshot.xmax))
}

fn (mut f Storage) read_objects(start []u8, end []u8) ![]PageObject {
	mut objs := []PageObject{}
	mut iter := f.btree.new_range_iterator(start, end)
	for {
		object := iter.next() or { break }
		if f.is_visible(object.tid, object.xid) {
			objs << object
		}
	}
	if err := iter.err {
		return err
	}

	return objs
}

// isolation_start signals the start of an operation that shall be atomic until
// isolation_end is invoked. If there is no active transaction (including a
// transaction that hasn't changed anything yet, see TransactionState), a new
// transaction will be created. Otherwise, this isolation block will be part of
// the current transaction.
fn (mut f Storage) isolation_start() ! {
	fault_point('isolation_start')!

	match f.transaction_state {
		.not_active, .reading {
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
	if f.transaction_state != .active {
		f.isolation_depth--
	}

	fault_point('isolation_end')!

	// The B-tree is replaced for each operation, so the pages it changed must
	// be kept with the transaction before then. An implicit transaction ends in
	// the same statement, while the file is locked, so its pages can't be split
	// by another connection, and it doesn't need the keys.
	f.add_transaction_pages(f.transaction_state == .active)
	f.btree.written_pages = map[int]bool{}
	f.btree.written_keys = map[string]bool{}

	match f.transaction_state {
		.not_active, .reading {
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

	// Revist any remaining pages to clean out any expired rows. Only the
	// objects expired in this transaction are removed.
	f.remove_expired(f.transaction_pages.keys(), false)!

	f.save_transaction_pages()
	f.transaction_pages = map[int]bool{}

	f.header.active_transaction_ids.remove(f.transaction_id)
}
