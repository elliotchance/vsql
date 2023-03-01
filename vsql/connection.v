// connection.v is the main file and library entry point allows the database to
// be opened.

module vsql

import os
import sync
import time

pub const default_schema_name = 'PUBLIC'

// A Connection allows querying and other introspection for a database file. Use
// open() or open_database() to create a Connection.
//
// snippet: v.Connection
[heap]
pub struct CatalogConnection {
	// path is the file name of the database. It can be the special name
	// ':memory:'.
	path         string
	catalog_name string
mut:
	// storage will be replaced when the file is reopend for reading or writing.
	storage Storage
	// options are used when aquiring each file connection.
	options ConnectionOptions
	// virtual_tables can be created independent from the physical schema.
	virtual_tables map[string]VirtualTable
}

// A Connection allows querying and other introspection for a database file. Use
// open() or open_database() to create a Connection.
//
// snippet: v.Connection
[heap]
pub struct Connection {
mut:
	catalogs map[string]&CatalogConnection
	// funcs only needs to be initialized once on open()
	funcs []Func
	// query_cache is maintained over file reopens.
	query_cache &QueryCache
	// cast_rules are use for CAST() (see cast.v)
	cast_rules map[string]CastFunc
	// unary_operators and binary_operators are for operators (see operators.v)
	unary_operators  map[string]UnaryOperatorFunc
	binary_operators map[string]BinaryOperatorFunc
	// current_schema is where to search for unquailified table names. It will
	// have an initial value of 'PUBLIC'.
	current_schema string
	// current_catalog (also known as the database). It will have an inital value
	// derived from the first database file loaded.
	current_catalog string
pub mut:
	// now allows you to override the wall clock that is used. The Time must be
	// in UTC with a separate offset for the current local timezone (in positive
	// or negative minutes).
	//
	// snippet: v.ConnectionOptions.now
	now fn () (time.Time, i16)
}

// open is the convenience function for open_database() with default options.
//
// snippet: v.open
pub fn open(path string) !&Connection {
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
//
// - Fine: Multiple goroutines sharing an open_database() on the same file.
//
// - Bad: Multiple goroutines open_database() the same file.
//
// See ConnectionOptions and default_connection_options().
//
// snippet: v.open_database
pub fn open_database(path string, options ConnectionOptions) !&Connection {
	mut init_schema := false

	// If the file doesn't exist we initialize it and reopen it.
	if !os.exists(path) && path != ':memory:' {
		init_database_file(path, options.page_size)!
		init_schema = true
	}

	mut conn := open_connection(path, options)!
	if init_schema {
		conn.query('CREATE SCHEMA public')!
	}

	return conn
}

pub fn catalog_name_from_path(path string) string {
	return os.base(path).split('.')[0]
}

fn open_connection(path string, options ConnectionOptions) !&Connection {
	catalog_name := catalog_name_from_path(path)

	mut conn := &Connection{
		query_cache: options.query_cache
		current_catalog: catalog_name
		current_schema: vsql.default_schema_name
		now: fn () (time.Time, i16) {
			return time.utc(), i16(time.offset() / 60)
		}
	}

	register_builtin_funcs(mut conn)!
	register_cast_rules(mut conn)
	register_operators(mut conn)

	conn.add_catalog(catalog_name, path, options)!

	return conn
}

pub fn (mut conn Connection) add_catalog(catalog_name string, path string, options ConnectionOptions) ! {
	if catalog_name in conn.catalogs {
		return error('catalog already exists: ${catalog_name}')
	}

	// This is really only used when path == ':memory:' but we must supply
	// something to satisfy V's checker. It will be replaced if it's using file
	// storage.
	mut pager := new_memory_pager()
	btree := new_btree(pager, options.page_size)

	catalog := &CatalogConnection{
		catalog_name: catalog_name
		path: path
		storage: new_storage(btree)
		options: options
	}

	conn.catalogs[catalog_name] = catalog

	if path == ':memory:' {
		conn.query("SET CATALOG '${catalog_name}'")!
		conn.query('CREATE SCHEMA public')!
		conn.query("SET CATALOG '${conn.current_catalog}'")!
	}
}

fn (mut c Connection) open_read_connection() ! {
	for _, mut catalog in c.catalogs {
		catalog.open_read_connection()!
	}
}

fn (mut c CatalogConnection) open_read_connection() ! {
	if c.path == ':memory:' {
		return
	}

	c.options.mutex.@rlock()

	flock_lock_shared(c.storage.file, c.path)!
	c.storage.open(c.path, c.catalog_name)!
}

fn (mut c Connection) open_write_connection() ! {
	for _, mut catalog in c.catalogs {
		catalog.open_write_connection()!
	}
}

fn (mut c CatalogConnection) open_write_connection() ! {
	if c.path == ':memory:' {
		return
	}

	c.options.mutex.@lock()

	flock_lock_exclusive(c.storage.file, c.path)!
	c.storage.open(c.path, c.catalog_name)!
}

fn (mut c Connection) release_write_connection() {
	for _, mut catalog in c.catalogs {
		catalog.release_write_connection()
	}
}

fn (mut c CatalogConnection) release_write_connection() {
	if c.path == ':memory:' {
		return
	}

	c.storage.close() or {
		// This was a hack to get around the fact we can't return an option from
		// this function because it messes with the behavior of defer.
		//
		// TODO(elliotchance): I'm not sure what a fair thing to do is here, but
		//  certainly takling down the server or application is not the best
		//  call.
		panic(err)
	}

	flock_unlock_exclusive(c.storage.file, c.path)

	c.options.mutex.unlock()
}

fn (mut c Connection) release_read_connection() {
	for _, mut catalog in c.catalogs {
		catalog.release_read_connection()
	}
}

fn (mut c CatalogConnection) release_read_connection() {
	if c.path == ':memory:' {
		return
	}

	c.storage.close() or {
		// This was a hack to get around the fact we can't return an option from
		// this function because it messes with the behavior of defer.
		//
		// TODO(elliotchance): I'm not sure what a fair thing to do is here, but
		//  certainly takling down the server or application is not the best
		//  call.
		panic(err)
	}

	flock_unlock_shared(c.storage.file, c.path)

	c.options.mutex.runlock()
}

// prepare returns a precompiled statement that can be executed multiple times
// with different provided parameters.
//
// snippet: v.Connection.prepare
pub fn (mut c Connection) prepare(sql string) !PreparedStmt {
	t := start_timer()
	stmt, params, explain := c.query_cache.parse(sql) or {
		mut catalog := c.catalog()
		catalog.storage.transaction_aborted()
		return err
	}
	elapsed_parse := t.elapsed()

	return PreparedStmt{stmt, params, explain, &c, elapsed_parse}
}

// query executes a statement. If there is a result set it will be returned.
//
// snippet: v.Connection.query
pub fn (mut c Connection) query(sql string) !Result {
	mut catalog := c.catalog()

	if catalog.storage.transaction_state == .aborted {
		return sqlstate_25p02()
	}

	mut prepared := c.prepare(sql) or {
		catalog.storage.transaction_aborted()
		return err
	}

	return prepared.query(map[string]Value{}) or {
		catalog.storage.transaction_aborted()
		return err
	}
}

fn (mut c Connection) transaction_aborted() {
	for _, mut catalog in c.catalogs {
		catalog.storage.transaction_aborted()
	}
}

fn (mut c Connection) register_func(func Func) ! {
	c.funcs << func
}

pub fn (mut c Connection) catalog() &CatalogConnection {
	return c.catalogs[c.current_catalog] or { panic('unknown catalog: ${c.current_catalog}') }
}

fn (c Connection) find_function(func_name string, arg_types []Type) !Func {
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

	return sqlstate_42883('function does not exist: ${func_name}(${arg_types.map(it.str()).join(', ')})')
}

// register_function will register a function that can be used in SQL
// expressions.
//
// snippet: v.Connection.register_function
pub fn (mut c Connection) register_function(prototype string, func fn ([]Value) !Value) ! {
	// TODO(elliotchance): A rather crude way to decode the prototype...
	parts := prototype.replace('(', '|').replace(')', '|').split('|')
	function_name := new_function_identifier(parts[0].trim_space())!.entity_name
	raw_args := parts[1].split(',')
	mut arg_types := []Type{}
	for arg in raw_args {
		if arg.trim_space() != '' {
			arg_types << new_type(arg.trim_space().to_upper(), 0, 0)
		}
	}

	return_type := new_type(parts[2].trim_space().to_upper(), 0, 0)
	c.register_func(Func{function_name, arg_types, false, func, return_type})!
}

// register_virtual_table will register a function that can provide data at
// runtime to a virtual table.
//
// snippet: v.Connection.register_virtual_table
pub fn (mut c Connection) register_virtual_table(create_table string, data VirtualTableProviderFn) ! {
	// Registering virtual tables does not need use query cache.
	mut tokens := tokenize(create_table)
	stmt := parse(tokens)!

	if stmt is CreateTableStmt {
		mut table_name := c.resolve_schema_identifier(stmt.table_name)!

		c.catalogs[c.current_catalog].virtual_tables[table_name.storage_id()] = VirtualTable{
			create_table_sql: create_table
			create_table_stmt: stmt
			data: data
		}

		return
	}

	return error('must provide a CREATE TABLE statement')
}

// schemas returns the schemas in this catalog (database).
//
// snippet: v.Connection.schemas
pub fn (mut c CatalogConnection) schemas() ![]Schema {
	c.open_read_connection()!
	defer {
		c.release_read_connection()
	}

	mut schemas := []Schema{}
	for _, schema in c.storage.schemas {
		schemas << schema
	}

	return schemas
}

// schema_tables returns tables for the provided schema. If the schema does not
// exist and empty list will be returned.
//
// snippet: v.Connection.schema_tables
pub fn (mut c CatalogConnection) sequences(schema string) ![]Sequence {
	c.open_read_connection()!
	defer {
		c.release_read_connection()
	}

	mut sequences := []Sequence{}
	for _, sequence in c.storage.sequences()! {
		if sequence.name.schema_name == schema {
			sequences << sequence
		}
	}

	return sequences
}

// schema_tables returns tables for the provided schema. If the schema does not
// exist and empty list will be returned.
//
// snippet: v.Connection.schema_tables
pub fn (mut c CatalogConnection) schema_tables(schema string) ![]Table {
	c.open_read_connection()!
	defer {
		c.release_read_connection()
	}

	mut tables := []Table{}
	for _, table in c.storage.tables {
		if table.name.schema_name == schema {
			tables << table
		}
	}

	return tables
}

// resolve_identifier returns a new identifier that would represent the
// canonical (fully qualified) form.
fn (c Connection) resolve_identifier(identifier Identifier) Identifier {
	return Identifier{
		custom_id: identifier.custom_id
		catalog_name: if identifier.catalog_name == '' && !identifier.entity_name.starts_with('$') {
			c.current_catalog
		} else {
			identifier.catalog_name
		}
		schema_name: if identifier.schema_name == '' && !identifier.entity_name.starts_with('$') {
			c.current_schema
		} else {
			identifier.schema_name
		}
		entity_name: identifier.entity_name
		sub_entity_name: identifier.sub_entity_name
	}
}

// resolve_catalog_identifier returns the fully qualified and validates it.
fn (c Connection) resolve_catalog_identifier(identifier Identifier) !Identifier {
	ident := c.resolve_identifier(identifier)

	if ident.catalog_name !in c.catalogs {
		return sqlstate_3d000(ident.catalog_name) // catalog does not exist
	}

	return ident
}

// resolve_schema_identifier returns the fully qualified and validates it.
fn (mut c Connection) resolve_schema_identifier(identifier Identifier) !Identifier {
	ident := c.resolve_catalog_identifier(identifier)!

	if ident.schema_name !in c.catalog().storage.schemas {
		return sqlstate_3f000(ident.schema_name) // schema does not exist
	}

	return ident
}

// resolve_table_identifier returns a new identifer that would represent the
// canonical (fully qualified) form of the provided identifier or an error.
fn (mut c Connection) resolve_table_identifier(identifier Identifier, allow_virtual bool) !Identifier {
	ident := c.resolve_schema_identifier(identifier)!
	id := ident.storage_id()
	mut catalog := c.catalogs[ident.catalog_name] or {
		return error('unknown catalog: ${ident.catalog_name}')
	}

	if id in catalog.storage.tables {
		return ident
	}

	if allow_virtual && id in catalog.virtual_tables {
		return ident
	}

	return sqlstate_42p01('table', ident.str()) // table does not exist
}

// ConnectionOptions can modify the behavior of a connection when it is opened.
// You should not create the ConnectionOptions instance manually. Instead, use
// default_connection_options() as a starting point and modify the attributes.
//
// snippet: v.ConnectionOptions
pub struct ConnectionOptions {
pub mut:
	// query_cache contains the precompiled prepared statements that can be
	// reused. This makes execution much faster as parsing the SQL is extremely
	// expensive.
	//
	// By default each connection will be given its own query cache. However,
	// you can safely share a single cache over multiple connections and you are
	// encouraged to do so.
	//
	// snippet: v.ConnectionOptions.query_cache
	query_cache &QueryCache = unsafe { nil }
	// Warning: This only works for :memory: databases. Configuring it for
	// file-based databases will either be ignored or causes crashes.
	//
	// snippet: v.ConnectionOptions.page_size
	page_size int
	// In short, vsql (with default options) when dealing with concurrent
	// read/write access to single file provides the following protections:
	//
	// - Fine: Multiple processes open() the same file.
	//
	// - Fine: Multiple goroutines sharing an open() on the same file.
	//
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
	//
	// snippet: v.ConnectionOptions.mutex
	mutex &sync.RwMutex = unsafe { nil }
}

// default_connection_options returns the sensible defaults used by open() and
// the correct base to provide your own option overrides. See ConnectionOptions.
//
// snippet: v.default_connection_options
pub fn default_connection_options() ConnectionOptions {
	return ConnectionOptions{
		query_cache: new_query_cache()
		page_size: 4096
		mutex: sync.new_rwmutex()
	}
}
