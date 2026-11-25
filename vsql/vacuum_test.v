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
