module vsql

// large_value_test.v tests how strings that are longer than a quarter of a page
// are stored outside of their rows (see large_value.v).

import os

// large_value_objects are the Large Value Objects in the file, whether they're
// visible or not.
fn large_value_objects(mut db Connection) ![]PageObject {
	mut catalog := db.catalog()
	catalog.open_read_connection()!
	defer {
		catalog.release_read_connection()
	}

	return catalog.storage.raw_objects('L'.bytes(), 'M'.bytes())
}

fn large_value_path(name string) string {
	return os.join_path(os.temp_dir(), 'vsql-large-value-${name}-${os.getpid()}.vsql')
}

fn remove_large_value_files(path string) {
	os.rm(path) or {}
	os.rm(session_path(path)) or {}
	os.rm(path + '.wal') or {}
}

// A long BLOB is a reference in the row, and isn't read until it's needed. A
// Lob reads only the chunks of the part that's asked for. A long VARCHAR is
// read with the row.
fn test_large_value_is_read_when_needed() ! {
	path := large_value_path('read')
	remove_large_value_files(path)
	defer {
		remove_large_value_files(path)
	}

	mut db := open(path)!
	defer {
		db.close()
	}
	data := []u8{len: 5000, init: u8(index % 251)}
	db.query('CREATE TABLE t (id INT, b BLOB, v VARCHAR(5000), s VARCHAR(10))')!
	db.query("INSERT INTO t VALUES (1, X'${data.hex()}', '${'x'.repeat(5000)}', 'short')")!
	chunk_size := large_value_chunk_size(4096)
	objects := large_value_objects(mut db)!
	assert objects.len == 2 * ((5000 + chunk_size - 1) / chunk_size)

	// The value is read after the statement, so the file is locked again.
	result := db.query('SELECT * FROM t')!
	for row in result {
		b := row.get('B')!
		assert b.is_large && !b.large_value().loaded
		assert row.get('V')!.is_large && row.get('V')!.large_value().loaded

		lob := row.get_lob('B')!
		assert lob.len() == 5000
		mut buf := []u8{len: 10}
		assert lob.read_at(2500, mut buf)! == 10
		assert buf == data[2500..2510]
		assert !b.large_value().loaded
		assert lob.read_at(4995, mut buf)! == 5
		assert buf[..5] == data[4995..]
		assert lob.read_at(5000, mut buf)! == 0

		assert row.get_string('B')! == data.hex().to_upper()
		assert b.large_value().loaded
		assert lob.read_at(0, mut buf)! == 10
		assert buf == data[..10]

		// A short value is in the row, and can be read the same way.
		short := row.get_lob('S')!
		assert short.len() == 5
		assert short.read_at(1, mut buf)! == 4
		assert buf[..4].bytestr() == 'hort'
		assert short.read_at(5, mut buf)! == 0
		if _ := row.get_lob('ID') {
			assert false, 'got a Lob for an INTEGER'
		}
	}

	db.query('INSERT INTO t (id) VALUES (2)')!
	for row in db.query('SELECT b FROM t WHERE id = 2')! {
		null := row.get_lob('B')!
		assert null.len() == 0
		mut buf := []u8{len: 10}
		assert null.read_at(0, mut buf)! == 0
	}
}

// Updating another column keeps the large values. A replaced or deleted large
// value is removed when the transaction commits, and a ROLLBACK keeps it.
fn test_large_value_lifetime() ! {
	path := large_value_path('lifetime')
	remove_large_value_files(path)
	defer {
		remove_large_value_files(path)
	}

	mut db := open(path)!
	defer {
		db.close()
	}
	long := 'y'.repeat(3000)
	db.query('CREATE TABLE t (id INT, c CLOB)')!
	db.query("INSERT INTO t VALUES (1, '${long}')")!
	before := large_value_objects(mut db)!
	db.query('UPDATE t SET id = 2')!
	assert large_value_objects(mut db)!.map(it.key) == before.map(it.key)

	db.query('START TRANSACTION')!
	db.query("UPDATE t SET c = 'short'")!
	db.query('ROLLBACK')!
	assert large_value_objects(mut db)!.map(it.key) == before.map(it.key)

	db.query("UPDATE t SET c = '${'z'.repeat(3000)}'")!
	after := large_value_objects(mut db)!
	assert after.len == before.len
	assert after.map(it.key) != before.map(it.key)

	db.query('DELETE FROM t')!
	assert large_value_objects(mut db)!.len == 0

	// A file only needs the newer file format once it has a large value.
	header := db.catalog().storage.header
	assert header.read_version == data_types_file_format_version
}

// A large value that's read after the row was deleted by another transaction
// that committed (so it was removed) is a 0F001 error, rather than a different
// value.
fn test_large_value_removed_before_read() ! {
	path := large_value_path('removed')
	remove_large_value_files(path)
	defer {
		remove_large_value_files(path)
	}

	mut db1 := open(path)!
	defer {
		db1.close()
	}
	mut db2 := open(path)!
	defer {
		db2.close()
	}
	db1.query('CREATE TABLE t (b BLOB)')!
	db1.query("INSERT INTO t VALUES (X'${'ab'.repeat(3000)}')")!
	result := db1.query('SELECT * FROM t')!
	db2.query('DELETE FROM t')!
	for row in result {
		if _ := row.get_string('B') {
			assert false, 'read a value that was removed'
		} else {
			assert '${sqlstate_from_int(err.code())} ${err.msg()}' == '0F001 invalid LOB locator: the value is no longer available'
		}
		assert row.get('B')!.string_value() == ''
	}
}
