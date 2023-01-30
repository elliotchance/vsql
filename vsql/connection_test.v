module vsql

import os
import sync

fn test_concurrent_writes() ! {
	verbose_env := $env('VERBOSE')
	verbose := verbose_env != ''

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
		waits << spawn fn (file_name string, verbose bool, i int, options ConnectionOptions) {
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
		}(file_name, verbose, i, options)
	}
	waits.wait()

	result := db.query('SELECT * FROM foo')!
	mut total := 0
	for row in result {
		total += row.get_int('X')!
	}

	assert total == 1000
}
