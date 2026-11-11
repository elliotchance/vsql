// index.v contains CREATE INDEX and DROP INDEX, which aren't part of the SQL
// standard (V002 and V003, see the SQL Flagger), and how the entries of each
// index are kept up to date as rows are written.

module vsql

import time

// index_file_format_version is the version of the file format that the first
// index raises the Write Version of the file to, because an older version of
// vsql wouldn't change the index when it changes a row. See "Compatibility" in
// the "File Format" docs.
const index_file_format_version = u16(2)

// An Index is a copy of the values of some columns of a table, kept in order of
// those values, with the row ID of each row. It's stored as an Index Object (the
// definition) and an Index Entry Object for each row, see "File Format" in the
// docs.
pub struct Index {
mut:
	// tid is the transaction ID that created this index.
	tid u64
	// id is unique for each index in the file and never reused. Its entries are
	// keyed by it, see index_entry_prefix.
	id u64
	// table_id is the id of the table, which the index is keyed by, see
	// index_object_key.
	table_id u64
pub:
	// name includes the catalog and schema, which are always the same as the
	// table.
	name Identifier
	// table_name is the table that the index is on.
	table_name Identifier
	// columns are the columns of the table in the index, in order.
	columns []IndexColumn
	// unique is true for a UNIQUE index, where no two rows can have the same
	// values (unless any of them are NULL).
	unique bool
}

// An IndexColumn is a column of an Index.
pub struct IndexColumn {
pub:
	// name is the name of the column in the table.
	name string
	// desc is true when the values are in descending order (DESC).
	desc bool
}

pub fn (c IndexColumn) str() string {
	return if c.desc {
		'${delimit_identifier(c.name)} DESC'
	} else {
		delimit_identifier(c.name)
	}
}

// bytes is how the index is stored in the file: its CREATE INDEX statement,
// like:
//
//   CREATE UNIQUE INDEX "FOO_BAR" ON "PUBLIC"."FOO" ("BAR", "BAZ" DESC)
//
// The name isn't qualified, because an index is always in the schema of its
// table. The table is found by the table ID in the key (see index_object_key),
// not the name.
fn (i Index) bytes() []u8 {
	unique := if i.unique { 'UNIQUE ' } else { '' }
	return 'CREATE ${unique}INDEX ${delimit_identifier(i.name.entity_name)} ON ${i.table_name.storage_sql()} (${i.columns.map(it.str()).join(', ')})'.bytes()
}

// str returns the CREATE INDEX statement, including the ';'. It's the same as
// the definition that's stored in the file.
pub fn (i Index) str() string {
	return i.bytes().bytestr() + ';'
}

// sort_key sorts indexes by the name of their table, then their name.
fn (i Index) sort_key() string {
	return '${i.table_name.entity_name}\0${i.name.entity_name}'
}

// index_object_key is the key of the definition of an index. The index objects
// of a table are in the range from index_object_key(table_id, 0) to
// index_object_key(table_id + 1, 0).
fn index_object_key(table_id u64, index_id u64) []u8 {
	mut key := new_empty_bytes()
	key.write_u8(`N`)
	key.write_u64(table_id)
	key.write_u64(index_id)

	return key.bytes()
}

// index_entry_prefix is the start of the key of every entry of an index. The
// entries are in the range from index_entry_prefix(id) to
// index_entry_prefix(id + 1).
fn index_entry_prefix(index_id u64) []u8 {
	mut key := new_empty_bytes()
	key.write_u8(`X`)
	key.write_u64(index_id)

	return key.bytes()
}

// entry_key is the key of the entry of a row (whose id is set) in the index: the
// value of each column (see entry_values), then the row ID.
fn (i Index) entry_key(t Table, row Row) ![]u8 {
	mut key := i.entry_values(t, row)!
	key << row.id

	return key
}

// entry_values is the start of the key of the entry of a row in the index,
// without the row ID. Each value is a byte that's 0 for NULL (which sorts before
// any other value, like ORDER BY) or 1, then the value encoded like a PRIMARY
// KEY (see write_key_value). Every byte of a DESC column is flipped, so that it
// sorts the other way. The rows that have the same values have entries that
// start with the same bytes, because each value has a known length (see
// key_value_length).
fn (i Index) entry_values(t Table, row Row) ![]u8 {
	return i.entry_prefix(t, row, i.columns.len)
}

// entry_prefix is the start of the key of the entry of a row in the index, with
// only the values of its first n columns (see entry_values). Every entry for a
// row with those values starts with it. Only those columns need to be in row.
fn (i Index) entry_prefix(t Table, row Row, n int) ![]u8 {
	mut key := index_entry_prefix(i.id)
	for column in i.columns[..n] {
		value := row.data.value(column.name)
		mut part := new_empty_bytes()
		if value.is_null {
			part.write_u8(0)
		} else {
			part.write_u8(1)
			write_key_value(mut part, value, t.column(column.name)!.typ.typ)
		}
		for b in part.bytes() {
			key << if column.desc { ~b } else { b }
		}
	}

	return key
}

// entry_row_id is the row ID at the end of the key of an entry (see entry_key),
// after the value of each column.
fn (i Index) entry_row_id(t Table, key []u8) ![]u8 {
	mut pos := index_entry_prefix(i.id).len
	for column in i.columns {
		flip := if column.desc { u8(255) } else { u8(0) }
		is_null := key[pos] ^ flip == 0
		pos++
		if !is_null {
			pos += key_value_length(key[pos..], t.column(column.name)!.typ.typ, flip)
		}
	}

	return key[pos..]
}

// key_value_length is the number of bytes at the start of key that a value of
// type typ was written in by write_key_value. Each byte of key is xor'ed with
// flip first, see Index.entry_key.
fn key_value_length(key []u8, typ SQLType, flip u8) int {
	return match typ {
		.is_boolean {
			1
		}
		.is_smallint {
			2
		}
		.is_integer, .is_real {
			4
		}
		.is_bigint, .is_double_precision, .is_date, .is_time_with_time_zone,
		.is_time_without_time_zone, .is_timestamp_with_time_zone,
		.is_timestamp_without_time_zone {
			8
		}
		.is_numeric, .is_decimal {
			// The sign, then (for a non-zero) the exponent and each digit until
			// a 0, which is flipped for a negative number. See write_key_numeric.
			sign := key[0] ^ flip
			if sign == 1 {
				1
			} else {
				end := if sign == 0 { u8(255) } else { u8(0) }
				mut n := 3
				for key[n] ^ flip != end {
					n++
				}
				n + 1
			}
		}
		.is_character, .is_varchar {
			// Each space is followed by a byte that's only 1 at the end, see
			// write_key_string.
			mut n := 0
			for {
				n++
				if key[n - 1] ^ flip == ` ` {
					n++
					if key[n - 1] ^ flip == 1 {
						break
					}
				}
			}
			n
		}
	}
}

fn new_index_from_bytes(key []u8, data []u8, tid u64, table Table) !Index {
	stmt := parse_definition(data)!
	if stmt is CreateIndexStatement {
		mut buf := new_bytes(key[1..])
		table_id := buf.read_u64()

		return Index{
			tid:        tid
			id:         buf.read_u64()
			table_id:   table_id
			name:       Identifier{
				catalog_name: table.name.catalog_name
				schema_name:  table.name.schema_name
				entity_name:  stmt.index_name.entity_name
			}
			table_name: table.name
			columns:    stmt.columns
			unique:     stmt.unique
		}
	}

	return sqlstate_xx001('not an index definition: ${data.bytestr()}')
}

// table_indexes are the indexes of a table, sorted by name.
fn (f Storage) table_indexes(table_id u64) []Index {
	mut indexes := []Index{}
	for _, index in f.indexes {
		if index.table_id == table_id {
			indexes << index
		}
	}
	indexes.sort(a.name.entity_name < b.name.entity_name)

	return indexes
}

// load_indexes reads the indexes that are visible to the current transaction
// from the file, once the tables have been loaded. It must be called from inside
// an isolation block.
fn (mut f Storage) load_indexes() ! {
	mut tables := map[u64]Table{}
	for _, table in f.tables {
		tables[table.id] = table
	}

	f.save_schema()
	f.indexes = map[string]Index{}
	for object in f.read_objects('N'.bytes(), 'O'.bytes())! {
		mut buf := new_bytes(object.key[1..])
		table := tables[buf.read_u64()] or { continue }
		index := new_index_from_bytes(object.key, object.value, object.tid, table)!
		f.indexes[index.name.storage_id()] = index
	}
}

// create_index adds the index (to table t), with an entry for each row that's
// visible. The caller must make sure that there are no rows of the table that
// aren't visible, see has_concurrent_changes. When check_unique, a UNIQUE index
// can't be created when two rows have the same values (that aren't NULL), and
// then nothing is changed. The index of a UNIQUE constraint isn't checked here,
// because the constraint is checked instead (and it might be deferred).
fn (mut f Storage) create_index(definition Index, t Table, check_unique bool) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	mut rows := []Row{}
	mut seen := map[string]bool{}
	for object in f.read_objects(row_key_prefix(t.id), row_key_prefix(t.id + 1))! {
		row := new_row_from_bytes(t, object.value, object.tid).for_storage()
		if check_unique && definition.unique && !definition.has_null(row) {
			values := definition.entry_values(t, row)!.bytestr()
			if values in seen {
				return definition.unique_violation(t)
			}
			seen[values] = true
		}
		rows << row
	}

	// The Write Version is never lowered, even when the last index is dropped.
	if f.header.write_version < index_file_format_version {
		f.header.write_version = index_file_format_version
	}

	f.check_concurrent_name(`N`, definition.name)!

	f.header.index_id++
	index := Index{
		...definition
		tid:      f.transaction_id
		id:       f.header.index_id
		table_id: t.id
	}
	f.btree.add(new_page_object(index_object_key(t.id, index.id), f.transaction_id, 0,
		index.bytes()))!

	for row in rows {
		f.btree.add(new_page_object(index.entry_key(t, row)!, f.transaction_id, 0, []u8{}))!
	}

	f.save_schema()
	f.indexes[index.name.storage_id()] = index
	f.schema_changed()
}

// delete_index expires the definition and every entry of the index, like
// delete_table does for a table and its rows.
fn (mut f Storage) delete_index(index Index) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.btree.expire(index_object_key(index.table_id, index.id), index.tid, f.transaction_id)!
	f.expire_objects(index_entry_prefix(index.id), index_entry_prefix(index.id + 1))!

	f.save_schema()
	f.indexes.delete(index.name.storage_id())
	f.schema_changed()
}

// expire_objects expires every object from start to end (inclusive) that's
// visible.
fn (mut f Storage) expire_objects(start []u8, end []u8) ! {
	for object in f.read_objects(start, end)! {
		f.btree.expire(object.key, object.tid, f.transaction_id)!
	}
}

// add_index_entries adds the entry of a new row (or a new version of a row,
// whose id is set) to each index of t. If the entry already exists, because it
// was expired by the current transaction, it gets a new version.
fn (mut f Storage) add_index_entries(t Table, row Row) ! {
	for index in f.table_indexes(t.id) {
		f.btree.update(new_page_object(index.entry_key(t, row)!, f.transaction_id, 0,
			[]u8{}))!
	}
}

// delete_index_entries expires the entry of a row (whose id is set) in each
// index of t.
fn (mut f Storage) delete_index_entries(t Table, row Row) ! {
	for index in f.table_indexes(t.id) {
		key := index.entry_key(t, row)!
		f.expire_objects(key, key)!
	}
}

// update_index_entries replaces the entry of the old version of a row with the
// new version (which has the same id), in each index where it's different.
// Otherwise, the entry is the same for both versions, so it isn't changed.
fn (mut f Storage) update_index_entries(t Table, old Row, new Row) ! {
	for index in f.table_indexes(t.id) {
		old_key := index.entry_key(t, Row{
			...old
			id: new.id
		})!
		new_key := index.entry_key(t, new)!
		if old_key != new_key {
			f.expire_objects(old_key, old_key)!
			f.btree.update(new_page_object(new_key, f.transaction_id, 0, []u8{}))!
		}
	}
}

// has_null is true when any of the columns of the index are NULL in row. A
// UNIQUE index allows any number of rows like that.
fn (i Index) has_null(row Row) bool {
	return i.columns.any(row.data.value(it.name).is_null)
}

// unique_violation is the error for a row that has the same values as another
// row of t in a UNIQUE index.
fn (i Index) unique_violation(t Table) IError {
	return sqlstate_23505('UNIQUE INDEX ${i.name.entity_name} on ${t.name}', i.name)
}

// check_unique_indexes returns an error if a row in rows has the same values
// for the columns of a UNIQUE index of t as another row in t, or might once
// another transaction finishes. A row with a NULL in any of the columns never
// conflicts. Like check_unique_constraints, the rows must have already been
// written, so that UPDATE t SET u = u + 1 works. The index of a UNIQUE
// constraint is checked by check_unique_constraints instead.
fn (mut f Storage) check_unique_indexes(t Table, rows []Row) ! {
	indexes := f.table_indexes(t.id).filter(it.unique && !t.is_constraint_index(it))
	if indexes.len == 0 || rows.len == 0 {
		return
	}

	for index in indexes {
		for row in rows {
			if f.has_duplicate_entry(index, t, row)! {
				return index.unique_violation(t)
			}
		}
	}
}

// has_duplicate_entry is true when another row of t (including another new
// row) has an entry in the index with the same values as row, which has already
// been written. It's an error if another transaction is creating or deleting
// one, since it might or might not exist once that transaction finishes. A row
// with a NULL in any of the columns never has a duplicate. Only the entries
// with the same values are read.
fn (mut f Storage) has_duplicate_entry(index Index, t Table, row Row) !bool {
	if index.has_null(row) {
		return false
	}

	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	mut r := row
	r.object_key(t)!
	values := index.entry_values(t, r)!
	mut iter := f.btree.new_range_iterator(values, next_key(values))
	for {
		object := iter.next() or { break }

		// The entry of the row itself isn't a duplicate.
		if object.key[values.len..] == r.id {
			continue
		}

		if f.is_concurrent_write(object) {
			return sqlstate_40001('avoiding concurrent write on individual row')
		}

		if object.xid == 0 {
			return true
		}
	}
	if err := iter.err {
		return err
	}

	return false
}

// is_constraint_index is true when the index belongs to a UNIQUE constraint of
// t, which has the same name. It's created and dropped with the constraint, see
// build_constraint_indexes.
fn (t Table) is_constraint_index(index Index) bool {
	return t.unique_constraints.any(it.name == index.name.entity_name)
}

// is_foreign_key_index is true when the index is the one that a FOREIGN KEY of
// t made for itself (see foreign_key_index), which has the name of the
// constraint and only its columns, in ascending order.
fn (t Table) is_foreign_key_index(index Index) bool {
	return t.foreign_keys.any(is_own_foreign_key_index(it, index))
}

// is_own_foreign_key_index is whether index is the one that key made for itself,
// see Table.is_foreign_key_index.
fn is_own_foreign_key_index(key ForeignKey, index Index) bool {
	return !index.unique && index.name.entity_name == key.name
		&& index.columns.map(if it.desc { '' } else { it.name }) == key.columns
}

// constraint_index is the index of the UNIQUE constraint of t, see
// build_constraint_indexes. A table in a file from before indexes doesn't have
// one until it's needed, so it's created then.
fn (mut f Storage) constraint_index(t Table, constraint UniqueConstraint) !Index {
	name := t.constraint_identifier(constraint.name)
	return f.indexes[name.storage_id()] or {
		f.create_constraint_index(t, name, constraint.columns, true)!
	}
}

// foreign_key_index is the index that a FOREIGN KEY of t uses to find the rows
// that reference a row, see build_constraint_indexes. Like constraint_index,
// it's created when it's needed if there isn't one.
fn (mut f Storage) foreign_key_index(t Table, key ForeignKey) !Index {
	return f.find_foreign_key_index(t, key, '') or {
		f.create_constraint_index(t, t.constraint_identifier(key.name), key.columns, false)!
	}
}

// find_foreign_key_index is the first index of t (by name), other than the one
// named except, whose first columns are the columns of a FOREIGN KEY of t (in
// any order), so it has the entries of every row that references a row in the
// order of that row's key.
fn (f Storage) find_foreign_key_index(t Table, key ForeignKey, except string) ?Index {
	mut columns := key.columns.clone()
	columns.sort()
	for index in f.table_indexes(t.id) {
		if index.columns.len < columns.len || index.name.entity_name == except {
			continue
		}

		mut leading := index.columns[..columns.len].map(it.name)
		leading.sort()
		if leading == columns {
			return index
		}
	}

	return none
}

// build_constraint_indexes creates an index for each UNIQUE constraint and
// FOREIGN KEY of a new definition of t (whose old definition is old) that
// doesn't have one. These indexes let the constraints be checked without
// reading every row of a table.
//
// A UNIQUE constraint has its own UNIQUE index with the same name as the
// constraint, which is dropped with it. A FOREIGN KEY uses any index whose first
// columns are its columns (see find_foreign_key_index), otherwise it gets a new
// one with the same name as the constraint, which is kept as an ordinary index
// if the constraint is dropped.
//
// A new constraint can't have the same name as an index in the schema of the
// table, because its index would need the name.
fn (mut f Storage) build_constraint_indexes(old Table, t Table) ! {
	for constraint in old.unique_constraints {
		if t.unique_constraints.any(it.name == constraint.name) {
			continue
		}

		name := t.constraint_identifier(constraint.name)
		if index := f.indexes[name.storage_id()] {
			f.delete_index(index)!
		}
	}

	for constraint in t.unique_constraints {
		if !old.unique_constraints.any(it.name == constraint.name) {
			f.create_constraint_index(t, t.constraint_identifier(constraint.name), constraint.columns,
				true)!
		}
	}

	for key in t.foreign_keys {
		f.foreign_key_index(t, key)!
	}
}

// create_constraint_index creates the index of a constraint of t (see
// build_constraint_indexes) and returns it. It's an error if another transaction
// has written or deleted a row of t, because the index wouldn't have its entry.
fn (mut f Storage) create_constraint_index(t Table, name Identifier, columns []string, unique bool) !Index {
	if name.storage_id() in f.indexes {
		return sqlstate_42p07('index', name.str()) // duplicate index
	}

	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	f.check_concurrent_rows(t)!
	f.create_index(Index{
		name:       name
		table_name: t.name
		columns:    columns.map(IndexColumn{ name: it })
		unique:     unique
	}, t, false)!

	return f.indexes[name.storage_id()]
}

// check_drop_index returns an error if a constraint of t needs the index, so it
// can't be dropped: the index of a UNIQUE constraint, or the only index that a
// FOREIGN KEY can use (see build_constraint_indexes).
fn (f Storage) check_drop_index(t Table, index Index) ! {
	if t.is_constraint_index(index) {
		return sqlstate_2bp01('constraint ${requote_identifier(index.name.entity_name)} on ${t.name}')
	}

	for key in t.foreign_keys {
		used := f.find_foreign_key_index(t, key, '') or { continue }
		if used.name.entity_name != index.name.entity_name {
			continue
		}
		f.find_foreign_key_index(t, key, index.name.entity_name) or {
			return sqlstate_2bp01('constraint ${requote_identifier(key.name)} on ${t.name}')
		}
	}
}

// has_concurrent_changes is true when another active transaction has changed
// the definition (or an index) of t, or written or deleted a row of t. An index
// can't be created then, because the index would be missing the rows that it
// can't see.
fn (mut f Storage) has_concurrent_changes(t Table) !bool {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	return f.has_concurrent_objects(table_object_key(t.id), table_object_key(t.id))!
		|| f.has_concurrent_objects(index_object_key(t.id, 0), index_object_key(t.id + 1, 0))!
		|| f.has_concurrent_objects(row_key_prefix(t.id), row_key_prefix(t.id + 1))!
}

// check_indexes returns an error if an index of any table doesn't have exactly
// one entry for each row that's visible, with the values of the row. It's used
// by the tests, after each test, to find an index that wasn't kept up to date.
fn (mut conn Connection) check_indexes() ! {
	conn.open_read_connection()!
	defer {
		conn.release_read_connection()
	}

	for _, mut catalog in conn.catalogs {
		catalog.storage.check_indexes()!
	}
}

fn (mut f Storage) check_indexes() ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	for _, index in f.indexes {
		table := f.tables[index.table_name.storage_id()] or {
			return sqlstate_xx001('index ${index.name} is on table ${index.table_name}, which does not exist')
		}
		mut expected := []string{}
		for object in f.read_objects(row_key_prefix(table.id), row_key_prefix(table.id + 1))! {
			row := new_row_from_bytes(table, object.value, object.tid).for_storage()
			expected << index.entry_key(table, row)!.hex()
		}
		expected.sort()

		actual := f.read_objects(index_entry_prefix(index.id), index_entry_prefix(index.id + 1))!.map(it.key.hex())
		if actual != expected {
			return sqlstate_xx001('index ${index.name} has entries ${actual}, but the rows of ${table.name} need ${expected}')
		}
	}
}

// CREATE [UNIQUE] INDEX name ON table (column [ASC | DESC], ...)
//
// The index is in the schema of the table. Its name must be unique among the
// indexes of the schema, but it can be the same as the name of another kind of
// object, such as a table.
struct CreateIndexStatement {
	unique        bool
	index_name    Identifier
	table_name    Identifier
	columns       []IndexColumn
	if_not_exists bool // V002-03, an index that already exists isn't an error
}

fn (stmt CreateIndexStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// The index can't be created while another transaction has changes to the
	// table that it can't see, so it waits for them to finish (with the file
	// unlocked in between, so that they can).
	mut created := false
	for {
		done, ok, timeout := stmt.create(mut conn)!
		if done {
			created = ok
			break
		}

		conn.finish_write(false)!
		if t.elapsed() >= timeout {
			return sqlstate_55p03('cannot create index ${stmt.index_name.entity_name} while another transaction has changes to ${stmt.table_name}')
		}
		time.sleep(10 * time.millisecond)
	}

	return new_result_msg('CREATE INDEX ${int(created)}', elapsed_parse, t.elapsed())
}

// create creates the index and returns true, true. With IF NOT EXISTS, an index
// with the same name (in the schema of the table) returns true, false, without
// checking the rest of the statement. Or, it returns false (and how long to
// wait) when another transaction has changes to the table, see
// Storage.has_concurrent_changes. Then, the statement hasn't changed anything,
// but the file is still locked until finish_write.
fn (stmt CreateIndexStatement) create(mut conn Connection) !(bool, bool, time.Duration) {
	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	table_name := conn.resolve_table_identifier(stmt.table_name, false)!
	mut catalog := conn.catalog_for(table_name)
	table := catalog.storage.table(table_name.storage_id())

	name := Identifier{
		catalog_name: table_name.catalog_name
		schema_name:  table_name.schema_name
		entity_name:  stmt.index_name.entity_name
	}
	if name.storage_id() in catalog.storage.indexes {
		if stmt.if_not_exists {
			return true, false, 0
		}

		return sqlstate_42p07('index', name.str()) // duplicate index
	}

	mut seen := map[string]bool{}
	for column in stmt.columns {
		table.column(column.name)!
		if column.name in seen {
			return sqlstate_42601('column ${requote_identifier(column.name)} is in index ${name} more than once')
		}
		seen[column.name] = true
	}

	if catalog.storage.has_concurrent_changes(table)! {
		return false, false, catalog.options.create_index_timeout
	}

	catalog.storage.create_index(Index{
		name:       name
		table_name: table_name
		columns:    stmt.columns
		unique:     stmt.unique
	}, table, true)!

	return true, true, 0
}

fn (stmt CreateIndexStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN CREATE INDEX')
}

// DROP INDEX [IF EXISTS] [schema.]name
struct DropIndexStatement {
	index_name Identifier
	if_exists  bool // V003-02, an index that doesn't exist isn't an error
}

fn (stmt DropIndexStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	// An index can't exist in a schema that doesn't exist.
	name := conn.resolve_schema_identifier(stmt.index_name) or {
		if stmt.if_exists && err is SQLState3F000 {
			return new_result_msg('DROP INDEX 0', elapsed_parse, t.elapsed())
		}

		return err
	}
	mut catalog := conn.catalog_for(name)
	index := catalog.storage.indexes[name.storage_id()] or {
		if stmt.if_exists {
			return new_result_msg('DROP INDEX 0', elapsed_parse, t.elapsed())
		}

		return sqlstate_42704('index', name.str())
	}
	catalog.storage.check_drop_index(catalog.storage.table(index.table_name.storage_id()),
		index)!
	catalog.storage.delete_index(index)!

	return new_result_msg('DROP INDEX 1', elapsed_parse, t.elapsed())
}

fn (stmt DropIndexStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN DROP INDEX')
}
