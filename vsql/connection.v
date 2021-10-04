// connection.v is the main file and library entry point allows the database to
// be opened.

module vsql

import os

[heap]
pub struct Connection {
	// path is the file name of the database. It can be the special name
	// ':memory:'.
	path string
mut:
	// storage will be replaced when the file is reopend for reading or writing.
	storage Storage
	// funcs only needs to be initialized once on open()
	funcs map[string]Func
	// virtual_tables can be created independent from the physical schema.
	virtual_tables map[string]VirtualTable
	// query_cache is maintained over file reopens.
	query_cache &QueryCache
	// options are used when aquiring each file connection.
	options ConnectionOptions
	// file is a copy of the file handle opened by the pager so that we can
	// release the lock.
	file os.File
}

pub fn open(path string) ?Connection {
	return open_database(path, default_connection_options())
}

pub fn open_database(path string, options ConnectionOptions) ?Connection {
	if path == ':memory:' {
		return open_connection(path, options)
	}

	// If the file doesn't exist we initialize it and reopen it.
	if !os.exists(path) {
		init_database_file(path, options.page_size) ?
	}

	return open_connection(path, options)
}

fn open_connection(path string, options ConnectionOptions) ?Connection {
	mut conn := Connection{
		path: path
		query_cache: options.query_cache
		options: options
	}

	if path == ':memory:' {
		conn.storage = new_storage(new_memory_pager(options.page_size)) ?
	}

	register_builtin_funcs(mut conn) ?

	return conn
}

fn (mut c Connection) open_read_connection() ? {
	if c.path == ':memory:' {
		return
	}

	mut pager := new_file_pager(c.path, c.options.page_size) ?
	c.file = pager.file

	c.storage = new_storage(pager) ?
	flock_lock_shared(c.file)

	c.storage.load_schema() ?
}

fn (mut c Connection) open_write_connection() ? {
	if c.path == ':memory:' {
		return
	}

	mut pager := new_file_pager(c.path, c.options.page_size) ?
	c.file = pager.file

	c.storage = new_storage(pager) ?
	flock_lock_exclusive(c.file)

	c.storage.load_schema() ?
}

fn (mut c Connection) release_connection() {
	if c.path == ':memory:' {
		return
	}

	c.storage.flush()
	c.storage.close()

	flock_unlock(c.file)
}

pub fn (mut c Connection) prepare(sql string) ?PreparedStmt {
	t := start_timer()
	stmt, params, explain := c.query_cache.parse(sql) ?
	elapsed_parse := t.elapsed()

	return PreparedStmt{stmt, params, explain, &c, elapsed_parse}
}

pub fn (mut c Connection) query(sql string) ?Result {
	mut prepared := c.prepare(sql) ?
	defer {
		c.storage.flush()
	}

	return prepared.query(map[string]Value{})
}

pub fn (mut c Connection) register_func(func Func) ? {
	c.funcs[func.name] = func
}

pub fn (mut c Connection) register_function(prototype string, func fn ([]Value) ?Value) ? {
	// TODO(elliotchance): A rather crude way to decode the prototype...
	parts := prototype.replace('(', '|').replace(')', '|').split('|')
	function_name := identifier_name(parts[0].trim_space())
	raw_args := parts[1].split(',')
	mut arg_types := []Type{}
	for arg in raw_args {
		if arg.trim_space() != '' {
			arg_types << new_type(arg.trim_space().to_upper(), 0)
		}
	}

	c.register_func(Func{function_name, arg_types, func}) ?
}

pub fn (mut c Connection) register_virtual_table(create_table string, data fn (mut t VirtualTable)) ? {
	// Registering virtual tables does not need use query cache.
	mut tokens := tokenize(create_table)
	stmt := parse(tokens) ?

	if stmt is CreateTableStmt {
		table_name := identifier_name(stmt.table_name)
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
	query_cache &QueryCache
	// Warning: This only works for :memory: databases. Configuring it for
	// file-based databases will either be ignored or causes crashes.
	page_size int
}

fn default_connection_options() ConnectionOptions {
	return ConnectionOptions{
		query_cache: new_query_cache()
		page_size: 4096
	}
}
