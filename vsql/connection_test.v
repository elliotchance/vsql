module vsql

import os

fn test_concurrent_writes() ? {
	file_name := 'test_concurrent_writes.vsql'
	if os.exists(file_name) {
		os.rm(file_name) ?
	}

	mut db := open(file_name) ?
	db.query('CREATE TABLE foo (x INT)') ?

	mut waits := []thread{}
	for i in 0 .. 10 {
		waits << go fn (file_name string) {
			mut db := open(file_name) or { panic(err) }
			for i in 0 .. 10 {
				db.query('INSERT INTO foo (x) VALUES (1)') or { panic(err) }
			}
		}(file_name)
	}
	waits.wait()

	result := db.query('SELECT * FROM foo') ?
	mut total := 0
	for row in result {
		total += int(row.get_f64('X') ?)
	}

	assert total == 100
}
