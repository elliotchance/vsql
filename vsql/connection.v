// connection.v is the main file and library entry point allows the database to
// be opened.

module vsql

import os
import sync
import time

pub const default_schema_name = 'PUBLIC'

// A Connection allows querying and other introspection for a database file. Use
// open() or open_database() to create a Connection.
@[heap]
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
@[heap]
pub struct Connection {
mut:
	catalogs map[string]&CatalogConnection
	// funcs only needs to be initialized once on open()
	funcs []Func
	// cast_rules are use for CAST() (see cast.v)
	cast_rules map[string]CastFunc
	// unary_operators and binary_operators are for operators (see operators.v)
	unary_operators  map[string]UnaryOperatorFunc
	binary_operators map[string]BinaryOperatorFunc
	// current_schema is where to search for unqualified table names. It will
	// have an initial value of 'PUBLIC'.
	current_schema string
	// current_catalog (also known as the database). It will have an initial value
	// derived from the first database file loaded.
	current_catalog string
pub mut:
	// now allows you to override the wall clock that is used. The Time must be
	// in UTC with a separate offset for the current local timezone (in positive
	// or negative minutes).
	now fn () (time.Time, i16) @[required]
	// warnings are SQLSTATE errors that do not stop the execution. For example,
	// if a value must be truncated during a runtime CAST.
	//
	// Warnings are not ever reset, although only 100 of the most recent warnings
	// are retained. This is to be able to collect all warnings during some
	// arbitrary process defined by the application. Instead, you should call
	// clear_warnings() before starting a block of work.
	warnings []IError
}

// open is the convenience function for open_database() with default options.
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
		current_catalog: catalog_name
		current_schema:  default_schema_name
		now:             default_now
	}

	register_builtin_funcs(mut conn)!
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
		path:         path
		storage:      new_storage(btree)
		options:      options
	}

	conn.catalogs[catalog_name] = catalog

	if path == ':memory:' {
		conn.query("SET CATALOG '${catalog_name}'")!
		conn.query('CREATE SCHEMA public')!
		conn.query("SET CATALOG '${conn.current_catalog}'")!
	}
}

fn (mut conn Connection) open_read_connection() ! {
	for _, mut catalog in conn.catalogs {
		catalog.open_read_connection()!
	}
}

fn (mut conn CatalogConnection) open_read_connection() ! {
	if conn.path == ':memory:' {
		return
	}

	conn.options.mutex.@rlock()

	flock_lock_shared(conn.storage.file, conn.path)!
	conn.storage.open(conn.path, conn.catalog_name)!
}

fn (mut conn Connection) open_write_connection() ! {
	for _, mut catalog in conn.catalogs {
		catalog.open_write_connection()!
	}
}

fn (mut conn CatalogConnection) open_write_connection() ! {
	if conn.path == ':memory:' {
		return
	}

	conn.options.mutex.@lock()

	flock_lock_exclusive(conn.storage.file, conn.path)!
	conn.storage.open(conn.path, conn.catalog_name)!
}

fn (mut conn Connection) release_write_connection() {
	for _, mut catalog in conn.catalogs {
		catalog.release_write_connection()
	}
}

fn (mut conn CatalogConnection) release_write_connection() {
	if conn.path == ':memory:' {
		return
	}

	conn.storage.close() or {
		// This was a hack to get around the fact we can't return an option from
		// this function because it messes with the behavior of defer.
		//
		// TODO(elliotchance): I'm not sure what a fair thing to do is here, but
		//  certainly takling down the server or application is not the best
		//  call.
		panic(err)
	}

	flock_unlock_exclusive(conn.storage.file, conn.path)

	conn.options.mutex.unlock()
}

fn (mut conn Connection) release_read_connection() {
	for _, mut catalog in conn.catalogs {
		catalog.release_read_connection()
	}
}

fn (mut conn CatalogConnection) release_read_connection() {
	if conn.path == ':memory:' {
		return
	}

	conn.storage.close() or {
		// This was a hack to get around the fact we can't return an option from
		// this function because it messes with the behavior of defer.
		//
		// TODO(elliotchance): I'm not sure what a fair thing to do is here, but
		//  certainly takling down the server or application is not the best
		//  call.
		panic(err)
	}

	flock_unlock_shared(conn.storage.file, conn.path)

	conn.options.mutex.runlock()
}

// prepare returns a precompiled statement that can be executed multiple times
// with different provided parameters.
pub fn (mut conn Connection) prepare(sql_stmt string) !PreparedStmt {
	t := start_timer()

	mut tokens := tokenize(sql_stmt)

	// EXPLAIN is super helpful, but not part of the SQL standard so we only
	// treat it as a prefix that is trimmed off before parsing.
	mut explain := false
	if tokens[0].sym.v is IdentifierChain {
		if tokens[0].sym.v.identifier.to_upper() == 'EXPLAIN' {
			explain = true
			tokens = tokens[1..].clone()
		}
	}

	mut lexer := Lexer{tokens, 0}
	mut parser := yy_new_parser()
	parser.parse(mut lexer)!

	stmt := (parser as YYParserImpl).lval.v as Stmt
	elapsed_parse := t.elapsed()

	return PreparedStmt{stmt, map[string]Value{}, explain, &conn, elapsed_parse}
}

// query executes a statement. If there is a result set it will be returned.
pub fn (mut conn Connection) query(sql_stmt string) !Result {
	mut catalog := conn.catalog()

	if catalog.storage.transaction_state == .aborted {
		return sqlstate_25p02()
	}

	mut prepared := conn.prepare(sql_stmt) or {
		catalog.storage.transaction_aborted()
		return err
	}

	return prepared.query(map[string]Value{}) or {
		catalog.storage.transaction_aborted()
		return err
	}
}

fn (mut conn Connection) transaction_aborted() {
	for _, mut catalog in conn.catalogs {
		catalog.storage.transaction_aborted()
	}
}

fn (mut conn Connection) register_func(func Func) ! {
	conn.funcs << func
}

pub fn (mut conn Connection) catalog() &CatalogConnection {
	return conn.catalogs[conn.current_catalog] or {
		panic('unknown catalog: ${conn.current_catalog}')
	}
}

fn (conn Connection) find_function(func_name string, arg_types []Type) !Func {
	for f in conn.funcs {
		if func_name != f.name || arg_types.len != f.arg_types.len {
			continue
		}

		mut found := true
		for i, t in arg_types {
			mut real_arg_type := t

			// TODO(elliotchance); For now, we just consider all CHARACTER types as
			//  CHARACTER VARYING.
			if t.typ == .is_character {
				real_arg_type = Type{SQLType.is_varchar, t.scale, 0, false}
			}

			// Only compare the SQLType so that the precision/scale/null isn't
			// part of the comparison.
			if real_arg_type.typ != f.arg_types[i].typ {
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
pub fn (mut conn Connection) register_function(prototype string, func fn ([]Value) !Value) ! {
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
	conn.register_func(Func{function_name, arg_types, false, func, return_type})!
}

// register_virtual_table will register a function that can provide data at
// runtime to a virtual table.
pub fn (mut conn Connection) register_virtual_table(create_table string, data VirtualTableProviderFn) ! {
	// Registering virtual tables does not need use query cache.
	mut tokens := tokenize(create_table)
	mut lexer := Lexer{tokens, 0}
	mut parser := yy_new_parser()
	parser.parse(mut lexer)!
	stmt := (parser as YYParserImpl).lval.v as Stmt

	if stmt is TableDefinition {
		mut table_name := conn.resolve_schema_identifier(stmt.table_name)!

		conn.catalogs[conn.current_catalog].virtual_tables[table_name.storage_id()] = VirtualTable{
			create_table_sql:  create_table
			create_table_stmt: stmt
			data:              data
		}

		return
	}

	return error('must provide a CREATE TABLE statement')
}

// schemas returns the schemas in this catalog (database).
pub fn (mut conn CatalogConnection) schemas() ![]Schema {
	conn.open_read_connection()!
	defer {
		conn.release_read_connection()
	}

	mut schemas := []Schema{}
	for _, schema in conn.storage.schemas {
		schemas << schema
	}

	return schemas
}

// schema_tables returns tables for the provided schema. If the schema does not
// exist and empty list will be returned.
pub fn (mut conn CatalogConnection) sequences(schema string) ![]Sequence {
	conn.open_read_connection()!
	defer {
		conn.release_read_connection()
	}

	mut sequences := []Sequence{}
	for _, sequence in conn.storage.sequences()! {
		if sequence.name.schema_name == schema {
			sequences << sequence
		}
	}

	return sequences
}

// schema_tables returns tables for the provided schema. If the schema does not
// exist and empty list will be returned.
pub fn (mut conn CatalogConnection) schema_tables(schema string) ![]Table {
	conn.open_read_connection()!
	defer {
		conn.release_read_connection()
	}

	mut tables := []Table{}
	for _, table in conn.storage.tables {
		if table.name.schema_name == schema {
			tables << table
		}
	}

	return tables
}

// resolve_identifier returns a new identifier that would represent the
// canonical (fully qualified) form.
fn (conn Connection) resolve_identifier(identifier Identifier) Identifier {
	return Identifier{
		custom_id:       identifier.custom_id
		custom_typ:      identifier.custom_typ
		catalog_name:    if identifier.catalog_name == ''
			&& !identifier.entity_name.starts_with('$') {
			conn.current_catalog
		} else {
			identifier.catalog_name
		}
		schema_name:     if identifier.schema_name == '' && !identifier.entity_name.starts_with('$') {
			conn.current_schema
		} else {
			identifier.schema_name
		}
		entity_name:     identifier.entity_name
		sub_entity_name: identifier.sub_entity_name
	}
}

// resolve_catalog_identifier returns the fully qualified and validates it.
fn (conn Connection) resolve_catalog_identifier(identifier Identifier) !Identifier {
	ident := conn.resolve_identifier(identifier)

	if ident.catalog_name !in conn.catalogs {
		return sqlstate_3d000(ident.catalog_name) // catalog does not exist
	}

	return ident
}

// resolve_schema_identifier returns the fully qualified and validates it.
fn (mut conn Connection) resolve_schema_identifier(identifier Identifier) !Identifier {
	ident := conn.resolve_catalog_identifier(identifier)!

	if ident.schema_name !in conn.catalog().storage.schemas {
		return sqlstate_3f000(ident.schema_name) // schema does not exist
	}

	return ident
}

// resolve_table_identifier returns a new identifer that would represent the
// canonical (fully qualified) form of the provided identifier or an error.
fn (mut conn Connection) resolve_table_identifier(identifier Identifier, allow_virtual bool) !Identifier {
	ident := conn.resolve_schema_identifier(identifier)!
	id := ident.storage_id()
	mut catalog := conn.catalogs[ident.catalog_name] or {
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
pub struct ConnectionOptions {
pub mut:
	// Warning: This only works for :memory: databases. Configuring it for
	// file-based databases will either be ignored or causes crashes.
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
	mutex &sync.RwMutex = unsafe { nil }
}

// default_connection_options returns the sensible defaults used by open() and
// the correct base to provide your own option overrides. See ConnectionOptions.
pub fn default_connection_options() ConnectionOptions {
	return ConnectionOptions{
		page_size: 4096
		mutex:     sync.new_rwmutex()
	}
}

// clear_warnings removes all the existing warnings associated with this
// connection. Warnings are not ever reset, although only 100 of the most recent
// warnings are retained.
//
// This is to be able to collect all warnings during some arbitrary process
// defined by the application. Instead, you should call clear_warnings() before
// starting a block of work.
pub fn (mut conn Connection) clear_warnings() {
	conn.warnings = []IError{}
}

fn (mut conn Connection) add_warning(warning IError) {
	conn.warnings << warning
	if conn.warnings.len > 100 {
		conn.warnings = conn.warnings[conn.warnings.len - 100..]
	}
}
