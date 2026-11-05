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
//   CREATE INDEX "FOO_BAR" ON "PUBLIC"."FOO" ("BAR", "BAZ" DESC)
//
// The name isn't qualified, because an index is always in the schema of its
// table. The table is found by the table ID in the key (see index_object_key),
// not the name.
fn (i Index) bytes() []u8 {
	return 'CREATE INDEX ${delimit_identifier(i.name.entity_name)} ON ${i.table_name.storage_sql()} (${i.columns.map(it.str()).join(', ')})'.bytes()
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
// value of each column, then the row ID. Each value is a byte that's 0 for NULL
// (which sorts before any other value, like ORDER BY) or 1, then the value
// encoded like a PRIMARY KEY (see write_key_value). Every byte of a DESC column
// is flipped, so that it sorts the other way.
fn (i Index) entry_key(t Table, row Row) ![]u8 {
	mut key := index_entry_prefix(i.id)
	for column in i.columns {
		value := row.data[column.name]
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
	key << row.id

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
// aren't visible, see has_concurrent_changes.
fn (mut f Storage) create_index(definition Index, t Table) ! {
	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	// The Write Version is never lowered, even when the last index is dropped.
	if f.header.write_version < index_file_format_version {
		f.header.write_version = index_file_format_version
	}

	f.header.index_id++
	index := Index{
		...definition
		tid:      f.transaction_id
		id:       f.header.index_id
		table_id: t.id
	}
	f.btree.add(new_page_object(index_object_key(t.id, index.id), f.transaction_id, 0,
		index.bytes()))!

	for object in f.read_objects(row_key_prefix(t.id), row_key_prefix(t.id + 1))! {
		row := new_row_from_bytes(t, object.value, object.tid).for_storage()
		f.btree.add(new_page_object(index.entry_key(t, row)!, f.transaction_id, 0, []u8{}))!
	}

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

// CREATE INDEX name ON table (column [ASC | DESC], ...)
//
// The index is in the schema of the table. Its name must be unique among the
// indexes of the schema, but it can be the same as the name of another kind of
// object, such as a table.
struct CreateIndexStatement {
	index_name Identifier
	table_name Identifier
	columns    []IndexColumn
}

fn (stmt CreateIndexStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// The index can't be created while another transaction has changes to the
	// table that it can't see, so it waits for them to finish (with the file
	// unlocked in between, so that they can).
	for {
		done, timeout := stmt.create(mut conn)!
		if done {
			break
		}

		conn.finish_write(false)!
		if t.elapsed() >= timeout {
			return sqlstate_55p03('cannot create index ${stmt.index_name.entity_name} while another transaction has changes to ${stmt.table_name}')
		}
		time.sleep(10 * time.millisecond)
	}

	return new_result_msg('CREATE INDEX 1', elapsed_parse, t.elapsed())
}

// create creates the index and returns true. Or, it returns false (and how long
// to wait) when another transaction has changes to the table, see
// Storage.has_concurrent_changes. Then, the statement hasn't changed anything,
// but the file is still locked until finish_write.
fn (stmt CreateIndexStatement) create(mut conn Connection) !(bool, time.Duration) {
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
		return false, catalog.options.create_index_timeout
	}

	catalog.storage.create_index(Index{
		name:       name
		table_name: table_name
		columns:    stmt.columns
	}, table)!

	return true, 0
}

fn (stmt CreateIndexStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN CREATE INDEX')
}

// DROP INDEX [schema.]name
struct DropIndexStatement {
	index_name Identifier
}

fn (stmt DropIndexStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	name := conn.resolve_schema_identifier(stmt.index_name)!
	mut catalog := conn.catalog_for(name)
	index := catalog.storage.indexes[name.storage_id()] or {
		return sqlstate_42704('index', name.str())
	}
	catalog.storage.delete_index(index)!

	return new_result_msg('DROP INDEX 1', elapsed_parse, t.elapsed())
}

fn (stmt DropIndexStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN DROP INDEX')
}
