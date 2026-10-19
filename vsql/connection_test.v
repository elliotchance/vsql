module vsql

import os
import sync

const verbose = os.getenv('VERBOSE') != ''

fn test_concurrent_writes() ! {
	file_name := 'test_concurrent_writes.vsql'
	if os.exists(file_name) {
		os.rm(file_name) or { return err }
	}

	// A shared mutex is required if we intend to open_database() to the same
	// file within multiple goroutines. See ConnectionOptions.
	mut options := default_connection_options()
	options.mutex = sync.new_rwmutex()

	mut db := open_database(file_name, options)!
	db.query('CREATE TABLE foo (x INT)')!

	mut waits := []thread{}
	for i in 0 .. 10 {
		waits << spawn fn (file_name string, i int, options ConnectionOptions) {
			mut db := open_database(file_name, options) or { panic(err) }
			for j in 0 .. 100 {
				if verbose {
					println('${i}.${j}: INSERT start')
				}
				db.query('INSERT INTO foo (x) VALUES (1)') or { panic(err) }
				if verbose {
					println('${i}.${j}: INSERT done')
				}
			}
		}(file_name, i, options)
	}
	waits.wait()

	result := db.query('SELECT * FROM foo')!
	mut total := 0
	for row in result {
		total += row.get_int('X')!
	}

	assert total == 1000
}

fn test_datetime_types_survive_reopen() ! {
	file_name := 'test_datetime_types_survive_reopen.vsql'
	if os.exists(file_name) {
		os.rm(file_name) or { return err }
	}

	mut db := open(file_name)!
	db.query('CREATE TABLE t (x TIMESTAMP WITH TIME ZONE, y TIME WITH TIME ZONE, z TIMESTAMP(3), w TIME(2))')!
	db.query("INSERT INTO t (x, y, z, w) VALUES (TIMESTAMP '2022-06-30 21:47:32+05:00', TIME '01:02:03+05:00', TIMESTAMP '2022-06-30 21:47:32.123', TIME '01:02:03.45')")!

	// A new connection reads the table definition back from the file.
	mut db2 := open(file_name)!
	result := db2.query('SELECT * FROM t')!
	mut rows := 0
	for row in result {
		rows++
		assert row.get_string('X')! == '2022-06-30T21:47:32.000000+0500'
		assert row.get_string('Y')! == '01:02:03+0500'
		assert row.get_string('Z')! == '2022-06-30T21:47:32.123'
		assert row.get_string('W')! == '01:02:03.45'
	}
	assert rows == 1
}

fn test_row_ids_survive_reopen() ! {
	file_name := 'test_row_ids_survive_reopen.vsql'
	if os.exists(file_name) {
		os.rm(file_name) or { return err }
	}

	// Inserting many rows quickly must not create duplicate row IDs. A rolled
	// back row ID must not be reused either.
	mut db := open(file_name)!
	db.query('CREATE TABLE t (x INT)')!
	for i in 0 .. 100 {
		db.query('INSERT INTO t (x) VALUES (${i})')!
	}
	db.query('START TRANSACTION')!
	db.query('INSERT INTO t (x) VALUES (-1)')!
	db.query('ROLLBACK')!

	// A new connection continues from the last row ID in the file.
	mut db2 := open(file_name)!
	db2.query('INSERT INTO t (x) VALUES (100)')!

	mut f := os.open(file_name)!
	header := read_header(mut f)!
	f.close()
	assert header.row_id == 102

	mut xs := []int{}
	for row in db2.query('SELECT * FROM t')! {
		xs << row.get_int('X')!
	}
	assert xs == []int{len: 101, init: index}
}

fn test_duplicate_column_names() ! {
	mut db := open(':memory:')!
	db.query('CREATE TABLE a (id INT)')!
	db.query('CREATE TABLE b (id INT)')!
	db.query('INSERT INTO a (id) VALUES (1)')!
	db.query('INSERT INTO b (id) VALUES (2)')!

	result := db.query('SELECT a.id, b.id FROM a JOIN b ON TRUE')!
	assert result.columns.map(it.name.sub_entity_name) == ['ID', 'ID']
	for row in result {
		// get returns the first column with the name.
		assert row.get_int('ID')! == 1
		assert row.get_column(result.columns[0])!.int_value() == 1
		assert row.get_column(result.columns[1])!.int_value() == 2
	}
}

fn test_empty_pages_after_rollback() ! {
	file_name := 'test_empty_pages_after_rollback.vsql'
	if os.exists(file_name) {
		os.rm(file_name) or { return err }
	}

	// Rolling back enough rows leaves several empty leaf pages in the B-tree.
	mut db := open(file_name)!
	db.query('CREATE TABLE t (id INT NOT NULL, s VARCHAR(200), PRIMARY KEY (id))')!
	db.query('START TRANSACTION')!
	for i in 0 .. 60 {
		db.query("INSERT INTO t (id, s) VALUES (${i}, '${'y'.repeat(100)}')")!
	}
	db.query('ROLLBACK')!

	mut result := db.query('SELECT COUNT(*) FROM t')!
	assert (result.next() or { return error('no rows') }).get_int('COL1')! == 0
}

fn test_split_with_stale_parent_key() ! {
	file_name := 'test_split_with_stale_parent_key.vsql'
	if os.exists(file_name) {
		os.rm(file_name) or { return err }
	}

	// Deleting the first row of a page leaves the old key in the parent. A new
	// first row that splits the page must replace that key rather than add a
	// second one for the same page, which would make it appear twice.
	mut db := open(file_name)!
	db.query('CREATE TABLE t (id INT NOT NULL, s VARCHAR(1000), PRIMARY KEY (id))')!
	for i in 2 .. 41 {
		db.query("INSERT INTO t (id, s) VALUES (${i}, '${'y'.repeat(200)}')")!
	}
	db.query('DELETE FROM t WHERE id = 2')!
	db.query("INSERT INTO t (id, s) VALUES (1, '${'y'.repeat(1000)}')")!

	mut result := db.query('SELECT COUNT(*) FROM t')!
	assert (result.next() or { return error('no rows') }).get_int('COL1')! == 39
}

fn test_rollback_after_split() ! {
	file_name := 'test_rollback_after_split.vsql'
	if os.exists(file_name) {
		os.rm(file_name) or { return err }
	}

	// The rolled back INSERTs split pages, so some of the rows end up on pages
	// that were created by the split. ROLLBACK must remove those as well.
	mut db := open(file_name)!
	db.query('CREATE TABLE t (id INT NOT NULL, s VARCHAR(900), PRIMARY KEY (id))')!
	for i in 0 .. 10 {
		db.query("INSERT INTO t (id, s) VALUES (${i}, '${'y'.repeat(300)}')")!
	}
	db.query('START TRANSACTION')!
	for i in 0 .. 30 {
		db.query("INSERT INTO t (id, s) VALUES (${100 + i * 7 % 30}, '${'z'.repeat(800)}')")!
	}
	db.query('ROLLBACK')!

	mut result := db.query('SELECT COUNT(*) FROM t')!
	assert (result.next() or { return error('no rows') }).get_int('COL1')! == 10
}

fn test_large_rows() ! {
	file_name := 'test_large_rows.vsql'
	if os.exists(file_name) {
		os.rm(file_name) or { return err }
	}

	// Rows larger than half a page are moved to blob storage, and must be put
	// back together when they are read.
	mut db := open(file_name)!
	db.query('CREATE TABLE t (id INT NOT NULL, s VARCHAR(20000), PRIMARY KEY (id))')!
	db.query("INSERT INTO t (id, s) VALUES (1, '${'a'.repeat(5000)}')")!
	db.query("INSERT INTO t (id, s) VALUES (2, '${'b'.repeat(100)}')")!

	db.query('START TRANSACTION')!
	db.query("UPDATE t SET s = '${'c'.repeat(12000)}' WHERE id = 1")!
	db.query("UPDATE t SET s = '${'d'.repeat(9000)}' WHERE id = 1")!
	db.query("UPDATE t SET s = '${'e'.repeat(3000)}' WHERE id = 2")!
	db.query('COMMIT')!

	db.query('START TRANSACTION')!
	db.query("UPDATE t SET s = '${'f'.repeat(7000)}' WHERE id = 1")!
	db.query('DELETE FROM t WHERE id = 2')!
	db.query('ROLLBACK')!

	db = open(file_name)!
	mut result := db.query('SELECT id, CHAR_LENGTH(s), SUBSTRING(s FROM 1 FOR 1) FROM t')!
	mut rows := []string{}
	for row in result {
		rows << '${row.get_int('ID')!} ${row.get_int('COL2')!} ${row.get_string('COL3')!}'
	}
	assert rows == ['1 9000 d', '2 3000 e']

	// Deleting the rows also removes their blobs.
	db.query('DELETE FROM t')!
	mut f := os.open(file_name)!
	defer {
		f.close()
	}
	mut pager := new_file_pager(mut f, default_connection_options().page_size, 0)!
	for i in 0 .. pager.total_pages() {
		page := pager.fetch_page(i)!
		if page.kind == kind_leaf {
			for object in page.objects() {
				assert object.key[0] !in [`B`, `F`, `R`]
			}
		}
	}
}

fn test_split_into_three_pages() ! {
	file_name := 'test_split_into_three_pages.vsql'
	if os.exists(file_name) {
		os.rm(file_name) or { return err }
	}

	// The UPDATE adds a second version of the middle row to a full page. Both
	// versions must stay on the same page, so neither of the other rows fit
	// with them and the page has to be split into three.
	mut db := open(file_name)!
	db.query('CREATE TABLE t (id INT NOT NULL, s VARCHAR(2000), PRIMARY KEY (id))')!
	db.query("INSERT INTO t (id, s) VALUES (1, '${'a'.repeat(800)}')")!
	db.query("INSERT INTO t (id, s) VALUES (2, '${'b'.repeat(1900)}')")!
	db.query("INSERT INTO t (id, s) VALUES (3, '${'c'.repeat(800)}')")!
	db.query('START TRANSACTION')!
	db.query("UPDATE t SET s = '${'d'.repeat(1900)}' WHERE id = 2")!
	db.query('COMMIT')!

	db = open(file_name)!
	mut result := db.query('SELECT id, CHAR_LENGTH(s), SUBSTRING(s FROM 1 FOR 1) FROM t')!
	mut rows := []string{}
	for row in result {
		rows << '${row.get_int('ID')!} ${row.get_int('COL2')!} ${row.get_string('COL3')!}'
	}
	assert rows == ['1 800 a', '2 1900 d', '3 800 c']
}

fn test_virtual_table_where() ! {
	mut db := open(':memory:')!
	db.register_virtual_table('CREATE TABLE foo (num INT, word VARCHAR(32))', fn (mut t VirtualTable) ! {
		t.next_values([new_integer_value(1), new_varchar_value('hi')])
		t.next_values([new_integer_value(2), new_varchar_value('there')])
		t.done()
	})!

	mut result := db.query('SELECT word FROM foo WHERE num = 2')!
	mut words := []string{}
	for row in result {
		words << row.get_string('WORD')!
	}
	assert words == ['there']
}

fn test_random_updates() ! {
	file_name := 'test_random_updates.vsql'
	if os.exists(file_name) {
		os.rm(file_name) or { return err }
	}

	// UPDATEs that split pages must not lose a row or its value. This is a
	// simple LCG so the sequence of statements is always the same.
	mut db := open(file_name)!
	db.query('CREATE TABLE t (id INT NOT NULL, v INT, s VARCHAR(400), PRIMARY KEY (id))')!
	mut expected := map[int]int{}
	mut seed := u32(1)
	for _ in 0 .. 1500 {
		seed = seed * 1103515245 + 12345
		id := int(seed >> 16) % 81
		seed = seed * 1103515245 + 12345
		len := 10 + int(seed >> 16) % 290
		v := int(seed >> 8) % 1000
		if id in expected {
			result := db.query("UPDATE t SET v = ${v}, s = '${'q'.repeat(len)}' WHERE id = ${id}")!
			assert result.msg == 'UPDATE 1'
		} else {
			db.query("INSERT INTO t (id, v, s) VALUES (${id}, ${v}, '${'p'.repeat(len)}')")!
		}
		expected[id] = v
	}

	mut actual := map[int]int{}
	for row in db.query('SELECT id, v FROM t')! {
		actual[row.get_int('ID')!] = row.get_int('V')!
	}
	assert actual == expected
}

fn test_virtual_table_on_new_connection() ! {
	file_name := 'test_virtual_table_on_new_connection.vsql'
	if os.exists(file_name) {
		os.rm(file_name) or { return err }
	}

	mut db := open(file_name)!
	db.query('CREATE TABLE t (x INT)')!

	// A new connection to an existing file hasn't read the schemas yet.
	mut db2 := open(file_name)!
	db2.register_virtual_table('CREATE TABLE foo (num INT)', fn (mut t VirtualTable) ! {
		t.next_values([new_integer_value(1)])
		t.done()
	})!

	mut nums := []int{}
	for row in db2.query('SELECT num FROM foo')! {
		nums << row.get_int('NUM')!
	}
	assert nums == [1]
}
