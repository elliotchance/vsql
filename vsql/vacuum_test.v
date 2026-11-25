module vsql

import os

// VACUUM makes the file as small as it can be, and the rows are the same after
// it's opened again.
fn test_vacuum_shrinks_file() ! {
	file_name := 'test_vacuum_shrinks_file.vsql'
	if os.exists(file_name) {
		os.rm(file_name)!
	}

	mut db := open(file_name)!
	db.query('CREATE TABLE t (id INT PRIMARY KEY, body VARCHAR(200))')!
	db.query('CREATE INDEX t_body ON t (body)')!
	for round in 0 .. 5 {
		mut values := []string{}
		for i in 0 .. 1000 {
			id := round * 1000 + i
			values << "(${id}, 'row ${id} ${'x'.repeat(100)}')"
		}
		db.query('INSERT INTO t (id, body) VALUES ${values.join(', ')}')!
	}

	// Only every 10th row is left, so no page is empty.
	db.query('DELETE FROM t WHERE MOD(id, 10) <> 0')!
	before := os.file_size(file_name)
	vacuum := db.query('VACUUM')!
	after := os.file_size(file_name)
	assert after < before / 4, '${before} -> ${after}'

	// The result has the pages of the B-tree that were read, which doesn't
	// include the free pages, and how many pages were removed from the file.
	page_size := default_connection_options().page_size
	total := (before - header_size) / page_size
	removed := (before - after) / page_size
	message := vacuum.msg.split(' ')
	assert message.len == 3 && message[0] == 'VACUUM', message.str()
	assert message[1].int() > 0 && message[1].int() < total, '${message} of ${total} pages'
	assert message[2].i64() == removed, '${message} ${removed}'
	db.close()

	mut db2 := open(file_name)!
	mut result := db2.query("SELECT COUNT(*), SUM(id) FROM t WHERE body >= 'row'")!
	row := result.next()?
	assert row.get('COL1')!.int_value() == 500
	assert row.get('COL2')!.int_value() == 1247500
	db2.query("INSERT INTO t (id, body) VALUES (5000, 'new')")!
	db2.close()

	os.rm(file_name)!
}

// vacuum_check returns the number of rows, the sum of their IDs, and the sum
// of the lengths of their large values, read through the table and then the
// index, which must agree.
fn vacuum_check(mut db Connection) ![]i64 {
	mut table := db.query('SELECT COUNT(*), SUM(id), SUM(CHAR_LENGTH(c)) FROM t')!
	row := table.next() or { return error('no row') }
	mut index := db.query("SELECT COUNT(*), SUM(id) FROM t WHERE body >= ''")!
	row2 := index.next() or { return error('no row') }
	assert row.get('COL1')!.int_value() == row2.get('COL1')!.int_value()
	assert row.get('COL2')!.int_value() == row2.get('COL2')!.int_value()

	return [row.get('COL1')!.int_value(), row.get('COL2')!.int_value(), row.get('COL3')!.int_value()]
}

// COMPACT and FREE PAGES keep every row, index entry and large value, with
// a B-tree that's more than one level deep, and pages moved from the end of the
// file. The file is smaller, and still works after it's opened again.
fn test_vacuum_modes_keep_rows() ! {
	for mode in ['COMPACT', 'FREE PAGES', 'FULL'] {
		file_name := 'test_vacuum_modes_keep_rows.vsql'
		if os.exists(file_name) {
			os.rm(file_name)!
		}

		mut options := default_connection_options()
		options.page_size = 512
		mut db := open_database(file_name, options)!
		db.query('CREATE TABLE t (id INT PRIMARY KEY, body VARCHAR(100), c CLOB)')!
		db.query('CREATE INDEX t_body ON t (body)')!
		for round in 0 .. 20 {
			mut values := []string{}
			for i in 0 .. 100 {
				id := round * 100 + i
				c := if id % 7 == 0 { "REPEAT('c', ${id})" } else { 'NULL' }
				values << "(${id}, 'row ${(id * 7919) % 2000} ${'x'.repeat(id % 50)}', ${c})"
			}
			db.query('INSERT INTO t (id, body, c) VALUES ${values.join(', ')}')!
		}
		db.query('DELETE FROM t WHERE MOD(id, 3) <> 0')!
		db.query("UPDATE t SET body = 'updated ' || body WHERE MOD(id, 5) = 0")!
		db.query('DELETE FROM t WHERE id >= 1500')!
		expected := vacuum_check(mut db)!

		before := os.file_size(file_name)
		db.query('VACUUM ${mode}')!
		after := os.file_size(file_name)
		assert after < before, '${mode}: ${before} -> ${after}'
		assert vacuum_check(mut db)! == expected, mode

		// Every page can be used again, and the pages that are still free
		// aren't in the B-tree.
		db.query("INSERT INTO t (id, body, c) VALUES (5000, 'new', REPEAT('n', 3000))")!
		db.query('DELETE FROM t WHERE id = 5000')!
		assert vacuum_check(mut db)! == expected, mode
		db.close()

		mut db2 := open_database(file_name, options)!
		assert vacuum_check(mut db2)! == expected, mode
		db2.query('VACUUM ${mode}')!
		assert vacuum_check(mut db2)! == expected, mode
		db2.close()

		os.rm(file_name)!
	}
}
