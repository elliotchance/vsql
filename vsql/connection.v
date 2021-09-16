// connection.v is the main file and library entry point allows the database to
// be opened.

module vsql

import os

[heap]
pub struct Connection {
mut:
	storage        Storage
	funcs          map[string]Func
	virtual_tables map[string]VirtualTable
	query_cache    &QueryCache
}

pub fn open(path string) ?Connection {
	return open_database(path, default_connection_options())
}

pub fn open_database(path string, options ConnectionOptions) ?Connection {
	if path == ':memory:' {
		return open_memory_database(options)
	}

	// This is a rudimentary way to ensure that small changes to storage.v are
	// compatible as things change so rapidly. Sorry if you had a database in a
	// previous version, you'll need to recreate it.
	current_version := i8(4)

	// If the file doesn't exist we initialize it and reopen it.
	if !os.exists(path) {
		mut tmpf := os.create(path) ?
		tmpf.write_raw(current_version) ?
		tmpf.write([]byte{len: options.page_size - 1}) ?
		tmpf.close()
	}

	// Now open the prepared or existing file and read all of the table
	// definitions.
	mut pager := new_file_pager(path, options.page_size) ?
	mut f := Storage{
		btree: new_btree(pager)
	}

	// TODO(elliotchance): Move this to a read/write header. See
	//  https://github.com/elliotchance/vsql/issues/42.
	mut version := []byte{len: options.page_size}
	pager.file.seek(0, .start) ?
	pager.file.read(mut version) ?
	f.version = i8(version[0])

	// Check file version compatibility.
	if f.version != current_version {
		return error('need version $current_version but database is $f.version')
	}

	return open_connection(pager, options)
}

pub fn open_memory_database(options ConnectionOptions) ?Connection {
	return open_connection(new_memory_pager(options.page_size), options)
}

fn open_connection(pager Pager, options ConnectionOptions) ?Connection {
	mut conn := Connection{
		storage: new_storage(pager) ?
		query_cache: options.query_cache
	}
	register_builtin_funcs(mut conn) ?

	return conn
}

pub fn (mut c Connection) prepare(sql string) ?PreparedStmt {
	t := start_timer()
	stmt, params := c.query_cache.parse(sql) ?
	elapsed_parse := t.elapsed()

	return PreparedStmt{stmt, params, &c, elapsed_parse}
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
