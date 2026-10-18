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
