// connection.v is the main file and library entry point allows the database to
// be opened.

module vsql

import os
import sync
import time

[heap]
pub struct Connection {
	// path is the file name of the database. It can be the special name
	// ':memory:'.
	path string
mut:
	// storage will be replaced when the file is reopend for reading or writing.
	storage Storage
	// funcs only needs to be initialized once on open()
	funcs []Func
	// virtual_tables can be created independent from the physical schema.
	virtual_tables map[string]VirtualTable
	// query_cache is maintained over file reopens.
	query_cache &QueryCache
	// options are used when aquiring each file connection.
	options ConnectionOptions
}

// open is the convenience function for open_database() with default options.
pub fn open(path string) ?&Connection {
	return open_database(path, default_connection_options())
}

// open_database will open an existing database file or create a new file if the
// path does not exist.
//
// If the file does exist, open_database will assume that the file is a valid
// database file (not corrupt). Otherwise unexpected behavior or even a crash
// may occur.
//
// The special file name ":memory:" can be used to create an entirely in-memory
// database. This will be faster but all data will be lost when the connection
// is closed.
//
// open_database can be used concurrently for reading and writing to the same
// file and provides the following default protections:
//
// - Fine: Multiple processes open_database() the same file.
// - Fine: Multiple goroutines sharing an open_database() on the same file.
// - Bad: Multiple goroutines open_database() the same file.
//
// See ConnectionOptions and default_connection_options().
pub fn open_database(path string, options ConnectionOptions) ?&Connection {
	if path == ':memory:' {
		return open_connection(path, options)
	}

	// If the file doesn't exist we initialize it and reopen it.
	if !os.exists(path) {
		init_database_file(path, options.page_size)?
	}

	return open_connection(path, options)
}

fn open_connection(path string, options ConnectionOptions) ?&Connection {
	mut conn := &Connection{
		path: path
		query_cache: options.query_cache
		options: options
		storage: new_storage()
	}

	if path == ':memory:' {
		mut pager := new_memory_pager()
		conn.storage.btree = new_btree(pager, options.page_size)
	}

	register_builtin_funcs(mut conn)?

	return conn
}

fn (mut c Connection) open_read_connection() ? {
	if c.path == ':memory:' {
		return
	}

	c.options.mutex.@rlock()

	flock_lock_shared(c.storage.file, c.path)?
	c.storage.open(c.path)?
}

fn (mut c Connection) open_write_connection() ? {
	if c.path == ':memory:' {
		return
	}

	c.options.mutex.@lock()

	flock_lock_exclusive(c.storage.file, c.path)?
	c.storage.open(c.path)?
}

fn (mut c Connection) release_write_connection() {
	if c.path == ':memory:' {
		return
	}

	c.storage.close() or {
		// This was a hack to get around the fact we can't return an option from
		// this function because it messes with the behavior of defer.
		panic(err)
	}

	flock_unlock_exclusive(c.storage.file, c.path)
	c.options.mutex.unlock()
}

fn (mut c Connection) release_read_connection() {
	if c.path == ':memory:' {
		return
	}

	c.storage.close() or {
		// This was a hack to get around the fact we can't return an option from
		// this function because it messes with the behavior of defer.
		panic(err)
	}

	flock_unlock_shared(c.storage.file, c.path)
	c.options.mutex.runlock()
}

pub fn (mut c Connection) prepare(sql string) ?PreparedStmt {
	t := start_timer()
	stmt, params, explain := c.query_cache.parse(sql) or {
		c.storage.transaction_aborted()
		return err
	}
	elapsed_parse := t.elapsed()

	return PreparedStmt{stmt, params, explain, &c, elapsed_parse}
}

pub fn (mut c Connection) query(sql string) ?Result {
	if c.storage.transaction_state == .aborted {
		return sqlstate_25p02()
	}

	mut prepared := c.prepare(sql) or {
		c.storage.transaction_aborted()
		return err
	}

	return prepared.query(map[string]Value{}) or {
		c.storage.transaction_aborted()
		return err
	}
}

pub fn (mut c Connection) register_func(func Func) ? {
	c.funcs << func
}

fn (c Connection) find_function(func_name string, arg_types []Type) ?Func {
	for f in c.funcs {
		if func_name != f.name || arg_types.len != f.arg_types.len {
			continue
		}

		mut found := true
		for i, t in arg_types {
			// Only compare the SQLType so that the precision/scale/null isn't
			// part of the comparison.
			if t.typ != f.arg_types[i].typ {
				found = false
				break
			}
		}

		if found {
			return f
		}
	}

	return sqlstate_42883(func_name, arg_types)
}

pub fn (mut c Connection) register_function(prototype string, func fn ([]Value) ?Value) ? {
	// TODO(elliotchance): A rather crude way to decode the prototype...
	parts := prototype.replace('(', '|').replace(')', '|').split('|')
	function_name := new_identifier(parts[0].trim_space()).name
	raw_args := parts[1].split(',')
	mut arg_types := []Type{}
	for arg in raw_args {
		if arg.trim_space() != '' {
			arg_types << new_type(arg.trim_space().to_upper(), 0, 0)
		}
	}

	return_type := new_type(parts[2].trim_space().to_upper(), 0, 0)
	c.register_func(Func{function_name, arg_types, false, func, return_type})?
}

pub fn (mut c Connection) register_virtual_table(create_table string, data VirtualTableProviderFn) ? {
	// Registering virtual tables does not need use query cache.
	mut tokens := tokenize(create_table)
	stmt := parse(tokens)?

	if stmt is CreateTableStmt {
		table_name := stmt.table_name
		c.virtual_tables[table_name] = VirtualTable{
			create_table_sql: create_table
			create_table_stmt: stmt
			data: data
		}

		return
	}

	return error('must provide a CREATE TABLE statement')
}

struct ConnectionOptions {
pub mut:
	// query_cache contains the precompiled prepared statements that can be
	// reused. This makes execution much faster as parsing the SQL is extremely
	// expensive.
	//
	// By default each connection will be given its own query cache. However,
	// you can safely share a single cache over multiple connections and you are
	// encouraged to do so.
	query_cache &QueryCache
	// Warning: This only works for :memory: databases. Configuring it for
	// file-based databases will either be ignored or causes crashes.
	page_size int
	// In short, vsql (with default options) when dealing with concurrent
	// read/write access to single file provides the following protections:
	//
	// - Fine: Multiple processes open() the same file.
	// - Fine: Multiple goroutines sharing an open() on the same file.
	// - Bad: Multiple goroutines open() the same file.
	//
	// The mutex option will protect against the third Bad case if you
	// provide the same mutex instance to all open() calls:
	//
	//   mutex := sync.new_rwmutex() // only create one of these
	//
	//   mut options := default_connection_options()
	//   options.mutex = mutex
	//
	// Since locking all database isn't ideal. You could provide a consistent
	// RwMutex that belongs to each file - such as from a map.
	mutex &sync.RwMutex
	// now allows you to override the wall clock that is used. The Time must be
	// in UTC with a separate offset for the current local timezone (in positive
	// or negative minutes).
	now fn () (time.Time, i16)
}

// default_connection_options returns the sensible defaults used by open() and
// the correct base to provide your own option overrides. See ConnectionOptions.
fn default_connection_options() ConnectionOptions {
	return ConnectionOptions{
		query_cache: new_query_cache()
		page_size: 4096
		mutex: sync.new_rwmutex()
		now: fn () (time.Time, i16) {
			return time.utc(), i16(time.offset() / 60)
		}
	}
}
