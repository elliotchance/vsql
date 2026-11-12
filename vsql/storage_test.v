module vsql

// storage_test.v tests the file, the WAL, the B-tree and rows where SQL can't
// reach, including the panics for what can't happen.

import encoding.binary
import hash.crc32
import os

// A file can't have more than 256 transactions at the same time, because that's
// how many fit in its header.
fn test_too_many_transactions() {
	mut ids := TransactionIDs{}
	for i in 0 .. 256 {
		ids.add(u64(i + 1)) or { panic(err) }
	}

	ids.add(257) or {
		assert sqlstate_from_int(err.code()) == '0B000'
		assert err.msg() == 'invalid transaction initiation: max concurrent transactions reached'
		return
	}
	assert false, '257th transaction was added'
}

// Every error has a SQLSTATE, including the ones that aren't caused by SQL,
// such as a file that isn't a vsql database (E171).
fn test_sqlstate_for_other_errors() ! {
	assert header_error('nope'.bytes()) == 'XX001 not a vsql database, or it was created by a version of vsql before the file format had a magic number'

	mut data := new_header(4096).bytes()
	binary.big_endian_put_u16_at(mut data, file_format_version + 1, header_magic.len)
	assert header_error(data) == '0A000 database needs file format ${file_format_version + 1} to be read, but this version of vsql only supports up to ${file_format_version}, upgrade vsql to open it'

	binary.big_endian_put_u16_at(mut data, oldest_file_format_version - 1, header_magic.len)
	assert header_error(data) == '0A000 database uses file format ${oldest_file_format_version - 1}, which is older than this version of vsql supports (${oldest_file_format_version}), you will need to recreate it'

	data = new_header(4096).bytes()
	binary.big_endian_put_u32_at(mut data, 0, header_magic.len + 8)
	assert header_error(data) == 'XX001 invalid page size 0'

	mut db := open(':memory:')!
	db.add_catalog('FOO', ':memory:', default_connection_options())!
	mut got := ''
	db.add_catalog('FOO', ':memory:', default_connection_options()) or {
		got = '${sqlstate_from_int(err.code())} ${err.msg()}'
	}
	assert got == '42P04 duplicate catalog: FOO'

	got = ''
	create_plan(CommitStatement{}, map[string]Value{}, mut db) or {
		got = sqlstate_from_int(err.code())
	}
	assert got == 'XX000'

	// An error from the os module has no SQLSTATE, but one that already has a
	// SQLSTATE keeps it.
	assert sqlstate_from_int(io_error(error_with_code('no space left on device', 28)).code()) == '58030'
	assert sqlstate_from_int(io_error(sqlstate_22012()).code()) == '22012'
}

fn header_error(data []u8) string {
	new_header_from_bytes(data) or { return '${sqlstate_from_int(err.code())} ${err.msg()}' }

	return ''
}

// A page can't be larger than 65535 bytes, because the Used field of the page
// header is a u16 (#519).
fn test_page_size_limits() ! {
	data := new_header(65536).bytes()
	assert header_error(data) == 'XX001 invalid page size 65536'

	for page_size in [16, 65536] {
		mut options := default_connection_options()
		options.page_size = page_size
		message := '54000 page size ${page_size} must be more than 16 and at most 65535 bytes'

		if _ := open_database(':memory:', options) {
			assert false, 'opened :memory: with a page size of ${page_size}'
		} else {
			assert '${sqlstate_from_int(err.code())} ${err.msg()}' == message
		}

		// The file isn't created.
		path := os.join_path(os.temp_dir(), 'vsql-sql-test-page-size-${os.getpid()}.vsql')
		if _ := open_database(path, options) {
			assert false, 'created a file with a page size of ${page_size}'
		} else {
			assert '${sqlstate_from_int(err.code())} ${err.msg()}' == message
		}
		assert !os.exists(path)
	}

	// The largest page holds a value that fills most of it.
	path := os.join_path(os.temp_dir(), 'vsql-sql-test-page-size-${os.getpid()}.vsql')
	defer {
		os.rm(path) or {}
		os.rm(session_path(path)) or {}
	}
	mut options := default_connection_options()
	options.page_size = 65535
	mut db := open_database(path, options)!
	db.query('CREATE TABLE t (x VARCHAR(65000))')!
	db.query("INSERT INTO t (x) VALUES ('${'a'.repeat(60000)}')")!
	db.close()

	db = open_database(path, default_connection_options())!
	defer {
		db.close()
	}
	mut result := db.query('SELECT CHAR_LENGTH(x) AS l FROM t')!
	assert result.next()?.get_int('L')! == 60000
}

// A cache_size of 0 reads every page from the file.
fn test_page_cache_off() ! {
	path := os.join_path(os.temp_dir(), 'vsql-sql-test-cache-off-${os.getpid()}.vsql')
	defer {
		os.rm(path) or {}
		os.rm(session_path(path)) or {}
	}
	mut options := sql_test_options()
	options.cache_size = 0
	mut db := open_database(path, options)!
	defer {
		db.close()
	}
	db.query('CREATE TABLE t (x INT)')!
	for i in 0 .. 50 {
		db.query('INSERT INTO t (x) VALUES (${i})')!
	}
	mut result := db.query('SELECT COUNT(*) AS c FROM t')!
	assert result.next()?.get_int('C')! == 50
}

fn test_panics() ! {
	$if windows {
		return
	}

	mut code, mut stderr := run_in_child(fn () {
		mut db := open(':memory:') or { panic(err) }
		db.current_catalog = 'NOPE'
		_ := db.catalog()
	})!
	assert code in panic_exit_codes
	assert stderr.contains('unknown catalog: NOPE')

	code, stderr = run_in_child(fn () {
		mut db := open(':memory:') or { panic(err) }
		_ := db.catalog_for(Identifier{ catalog_name: 'NOPE' })
	})!
	assert code in panic_exit_codes
	assert stderr.contains('unknown catalog: NOPE')

	code, stderr = run_in_child(fn () {
		_ := yy_as[Identifier](YYSym(true))
	})!
	assert code in panic_exit_codes
	assert stderr.contains('V panic: expected vsql.Identifier')

	code, stderr = run_in_child(fn () {
		_ := yy_unbox[Stmt](YYSym(yy_box(Table{})))
	})!
	assert code in panic_exit_codes
	assert stderr.contains('V panic: expected vsql.Stmt')

	code, stderr = run_in_child(fn () {
		mut page := new_page(kind_leaf, 64)
		page.add(new_page_object('k'.bytes(), 1, 0, []u8{len: 100})) or {}
	})!
	assert code in panic_exit_codes
	assert stderr.contains('page cannot fit object of 124 b in page using 16 b')
}

// crash_point stops the process the VSQL_CRASH_AT'th time it's reached, without
// flushing anything, see cmd/tests/crash-recovery.sh.
fn test_crash_point() ! {
	$if windows {
		return
	}

	code, stderr := run_in_child(fn () {
		mut state := unsafe { &CrashPoint(crash_point_state) }
		unsafe {
			*state = CrashPoint{
				at: 2
			}
		}
		crash_point()
		eprintln('first crash point passed')
		crash_point()
		eprintln('second crash point passed')
	})!
	assert code == 1
	assert stderr == 'first crash point passed\n'
}

// The database file isn't synced for each statement, so when the power fails it
// may have lost statements that are in the log. This puts the file back to how it
// was on the disk to simulate that.
// crc32_update reads 8 bytes at a time, so it's checked against hash.crc32 for
// every length that leaves a different number of bytes after the last 8, and
// for a checksum that's continued.
fn test_crc32_update() {
	mut data := []u8{}
	for i in 0 .. 100 {
		assert crc32_update(0, data) == crc32.sum(data)
		data << u8(i * 37 + 11)
	}
	for at in [0, 3, 8, 50, 100] {
		assert crc32_update(crc32_update(0, data[..at]), data[at..]) == crc32.sum(data)
	}
}

fn test_wal_recovers_statements_lost_from_the_file() ! {
	path := os.join_path(os.temp_dir(), 'vsql-wal-${os.getpid()}.vsql')
	defer {
		for file in [path, wal_path(path), session_path(path)] {
			os.rm(file) or {}
		}
	}

	mut db := open(path)!
	db.query('CREATE TABLE t (x INT)')!
	db.close()

	// Opening the file empties the log, so now the file has everything.
	db = open(path)!
	assert !wal_has_statements(path)
	on_disk := os.read_bytes(path)!

	db.query('INSERT INTO t (x) VALUES (1)')!
	db.query('INSERT INTO t (x) VALUES (2)')!
	assert wal_has_statements(path)
	assert !wal_needs_recovery(path)

	// Nothing is copied while there's another connection.
	mut other := open(path)!
	assert wal_has_statements(path)
	other.close()
	db.close()

	os.write_file_array(path, on_disk)!
	db = open(path)!
	assert !wal_has_statements(path)
	assert db.query('SELECT * FROM t')!.rows.len == 2

	// The log can be used again.
	db.query('INSERT INTO t (x) VALUES (3)')!
	db.close()
	db = open(path)!
	assert db.query('SELECT * FROM t')!.rows.len == 3
	db.close()

	// A log isn't kept for a file that has been deleted.
	db = open(path)!
	db.query('INSERT INTO t (x) VALUES (4)')!
	db.close()
	os.rm(path)!
	db = open(path)!
	db.query('CREATE TABLE t (x INT)')!
	assert db.query('SELECT * FROM t')!.rows.len == 0
	db.close()
}

// When copying the log fails, or the session lock can't be changed back to
// shared afterwards, the connection fails but the file can still be opened.
fn test_wal_recover_log_fails() ! {
	path := os.join_path(os.temp_dir(), 'vsql-wal-fails-${os.getpid()}.vsql')
	defer {
		for file in [path, wal_path(path), session_path(path)] {
			os.rm(file) or {}
		}
	}

	mut db := open(path)!
	db.query('CREATE TABLE t (x INT)')!
	db.close()

	for fault in ['recover', 'session_shared'] {
		arm_fault(fault, 1)!
		if _ := open(path) {
			assert false, fault
		}
		disarm_faults()

		db = open(path)!
		db.query('INSERT INTO t (x) VALUES (1)')!
		db.close()
	}

	db = open(path)!
	assert db.query('SELECT * FROM t')!.rows.len == 2
	db.close()
}

// expire returns -1 when there's no object with the key and tid.
fn test_btree_expire_missing_object() ! {
	mut btree := new_btree(new_memory_pager(), 256)
	btree.add(new_page_object('a'.bytes(), 1, 0, 'x'.bytes()))!

	assert btree.expire('b'.bytes(), 1, 2)! == -1
	assert btree.expire('a'.bytes(), 2, 3)! == -1
	assert btree.expire('a'.bytes(), 1, 2)! >= 0
}

// Merging the values of two rows (such as for a join) keeps the order of the
// keys, and a value of the second row replaces one with the same key.
fn test_row_data_merged() {
	a := new_row_data_from_map({
		'X': new_integer_value(1)
		'Y': new_integer_value(2)
	})
	b := new_row_data_from_map({
		'Y': new_integer_value(3)
		'Z': new_integer_value(4)
	})
	merged := a.merged(b)
	assert merged.keys == ['X', 'Y', 'Z']
	assert merged.values.map(it.int_value()) == [i64(1), 3, 4]
	assert a.value('Y').int_value() == 2
}

// A row only has the columns that the table had when it was written, so the
// columns after them are NULL.
fn test_row_with_fewer_columns() ! {
	x := Column{
		name: Identifier{
			entity_name:     'T'
			sub_entity_name: 'X'
		}
		typ:  new_type('INTEGER', 0, 0)
	}
	y := Column{
		name: Identifier{
			entity_name:     'T'
			sub_entity_name: 'Y'
		}
		typ:  new_type('INTEGER', 0, 0)
	}

	row := new_row({
		'X': new_integer_value(123)
	})
	data := row.bytes(Table{ columns: [x] })!
	read := new_row_from_bytes(Table{ columns: [x, y] }, data, 1)

	assert read.data.value(x.name.id()).int_value() == 123
	assert read.data.value(y.name.id()).is_null
	assert read.data.value(y.name.id()).typ.typ == .is_integer
}

// A row is limited to a little under 2 GB, which is too much memory for a test,
// so a smaller limit is used. Only strings are checked.
fn test_row_too_big() ! {
	x := Column{
		name: Identifier{
			entity_name:     'T'
			sub_entity_name: 'X'
		}
		typ:  new_type('CHARACTER VARYING', 10, 0)
	}
	row := new_row({
		'X': new_varchar_value('abcdef')
	})
	table := Table{
		columns: [x]
	}

	// The row ID length (2), column count (2), NULL indicator (1), string
	// length (4) and string (6).
	assert row.bytes_with_limit(table, 15)!.len == 15
	row.bytes_with_limit(table, 14) or {
		assert sqlstate_from_int(err.code()) == '54000'
		assert err.msg() == 'row is bigger than the maximum of 14 bytes'
		return
	}
	assert false
}

// old_sequence is a sequence as it's stored by a version of vsql that had the
// range of a BIGINT as its implicit MINVALUE and MAXVALUE.
fn old_sequence(definition string, current_value i64, unused bool) !Sequence {
	mut value := new_empty_bytes()
	value.write_i64(current_value)
	if unused {
		value.write_bool(false)
		value.write_bool(true)
	}

	return new_sequence_from_bytes('CREATE SEQUENCE "PUBLIC"."S"\n  ${definition}'.bytes(),
		value.bytes(), 0)
}

// A foreign key of a datetime without a time zone that references one with a time
// zone can't be created any more, but a file can already have one. Its value is
// compared in the session time zone.
fn test_old_foreign_key_time_zone() {
	value := new_time_value('12:00:00')!
	assert key_type_value(value, .is_time_with_time_zone, 300).time_value().time_zone == 300
	assert key_type_value(value, .is_time_without_time_zone, 300).time_value().time_zone == 0
}

fn test_old_sequence_implicit_limits() ! {
	// Within the new implicit limits, they're used.
	mut s := old_sequence('START WITH 5\n  INCREMENT BY 1', 4, true)!
	assert !s.has_min_value && !s.has_max_value
	assert s.min() == 1

	// An unused sequence with a START WITH below 1 keeps going down to the
	// smallest BIGINT.
	s = old_sequence('START WITH -5\n  INCREMENT BY 1', -6, true)!
	assert s.min() == min_i64 && s.max() == max_i64
	assert s.next()!.current_value == -5

	// A descending sequence that started at the old default of 1.
	s = old_sequence('START WITH 1\n  INCREMENT BY -1', 0, false)!
	assert s.min() == min_i64 && s.max() == max_i64
	assert s.next()!.current_value == -1

	// The current value of a sequence that has been used is outside the new
	// implicit limits, even though the START WITH isn't.
	s = old_sequence('START WITH -5\n  INCREMENT BY -1', 3, false)!
	assert s.max() == max_i64
	assert s.next()!.current_value == 2
}

// The entries of an index are in the order of the values: NULL first, then
// ascending, or descending for DESC (with NULL last), and then by row ID.
fn test_index_entry_order() {
	table := Table{
		columns: [Column{
			name: Identifier{
				sub_entity_name: 'A'
			}
			typ:  Type{.is_integer, 0, 0, false}
		}]
	}
	values := [Value{
		typ:     Type{.is_integer, 0, 0, false}
		is_null: true
	}, new_integer_value(-5), new_integer_value(0), new_integer_value(7)]
	for desc in [false, true] {
		index := Index{
			id:      1
			columns: [IndexColumn{'A', desc}]
		}
		mut keys := []string{}
		for i, value in values {
			keys << index.entry_key(table, Row{
				id:   [u8(9 - i)]
				data: new_row_data_from_map({
					'A': value
				})
			}) or { panic(err) }.hex()
		}
		mut sorted := keys.clone()
		sorted.sort()
		assert sorted == if desc { keys.reverse() } else { keys }
	}
}
