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
	// write_pending is true when a statement has released its write connection,
	// but finish_write hasn't decided whether to keep its changes yet.
	write_pending bool
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
	// row_sequence_values holds the values returned by NEXT VALUE FOR for the row
	// currently being evaluated. All NEXT VALUE FOR expressions for the same
	// sequence must return the same value within a row. See begin_row().
	row_sequence_values map[string]i64
	// dry_run is set when expressions are only being evaluated to check for
	// errors (such as an UPDATE that matched no rows). Expressions must not have
	// side effects, like advancing a sequence.
	dry_run bool
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

// session_path is the file that every connection to the database at path holds
// a shared lock on. See Storage.recover().
fn session_path(path string) string {
	return '${path}.session'
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

	mut catalog := &CatalogConnection{
		catalog_name: catalog_name
		path:         path
		storage:      new_storage(btree)
		options:      options
	}

	if path != ':memory:' {
		catalog.storage.session = session_lock(session_path(path))!
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

	conn.storage.open_file(conn.path) or {
		conn.options.mutex.runlock()
		return err
	}
	flock_lock_shared(conn.storage.file, conn.path) or {
		conn.storage.close_file()
		conn.options.mutex.runlock()
		return err
	}

	// A statement that was committed to the write-ahead log but not copied
	// into the database file (because the process stopped) must be copied
	// before the file can be read. That needs the file to be locked
	// exclusively.
	if wal_needs_recovery(conn.path) {
		flock_unlock_shared(conn.storage.file, conn.path)
		flock_lock_exclusive(conn.storage.file, conn.path) or {
			conn.storage.close_file()
			conn.options.mutex.runlock()
			return err
		}
		wal_recover(mut conn.storage.file, conn.path) or {
			flock_unlock_exclusive(conn.storage.file, conn.path)
			conn.storage.close_file()
			conn.options.mutex.runlock()
			return err
		}
		flock_unlock_exclusive(conn.storage.file, conn.path)
		flock_lock_shared(conn.storage.file, conn.path) or {
			conn.storage.close_file()
			conn.options.mutex.runlock()
			return err
		}
	}
	conn.storage.open(conn.path, conn.catalog_name, false) or {
		flock_unlock_shared(conn.storage.file, conn.path)
		conn.storage.close_file()
		conn.options.mutex.runlock()
		return err
	}
}

fn (mut conn Connection) open_write_connection() ! {
	for _, mut catalog in conn.catalogs {
		catalog.open_write_connection()!
	}
}

fn (mut conn CatalogConnection) open_write_connection() ! {
	if conn.path == ':memory:' {
		conn.storage.begin_statement()
		return
	}

	conn.options.mutex.@lock()

	conn.storage.open_file(conn.path) or {
		conn.options.mutex.unlock()
		return err
	}
	flock_lock_exclusive(conn.storage.file, conn.path) or {
		conn.storage.close_file()
		conn.options.mutex.unlock()
		return err
	}
	wal_recover(mut conn.storage.file, conn.path) or {
		flock_unlock_exclusive(conn.storage.file, conn.path)
		conn.storage.close_file()
		conn.options.mutex.unlock()
		return err
	}
	conn.storage.open(conn.path, conn.catalog_name, true) or {
		flock_unlock_exclusive(conn.storage.file, conn.path)
		conn.storage.close_file()
		conn.options.mutex.unlock()
		return err
	}
	if !conn.storage.header.is_writable() {
		flock_unlock_exclusive(conn.storage.file, conn.path)
		conn.storage.close_file()
		conn.options.mutex.unlock()
		return sqlstate_25006('database needs file format ${conn.storage.header.write_version} to be changed, but this version of vsql only supports up to ${file_format_version}')
	}

	conn.storage.begin_statement()
}

fn (mut conn Connection) release_write_connection() {
	for _, mut catalog in conn.catalogs {
		catalog.release_write_connection()
	}
}

// release_write_connection is called (usually deferred) at the end of a
// statement that changes the database. It's not known yet whether the statement
// succeeded, so the file stays locked until finish_write.
fn (mut conn CatalogConnection) release_write_connection() {
	conn.write_pending = true
}

// finish_write must be called once a statement has finished. If it opened a
// write connection, the changes it made are kept if it succeeded, or discarded
// if it failed, and the file is unlocked.
fn (mut conn Connection) finish_write(success bool) ! {
	mut first_err := ?IError(none)
	for _, mut catalog in conn.catalogs {
		catalog.finish_write(success) or {
			if first_err == none {
				first_err = err
			}
		}
	}

	if err := first_err {
		return err
	}
}

fn (mut conn CatalogConnection) finish_write(success bool) ! {
	if !conn.write_pending {
		return
	}
	conn.write_pending = false

	mut commit_err := ?IError(none)
	if success {
		conn.storage.commit_statement(conn.path) or {
			conn.storage.discard_statement(conn.path) or {}
			commit_err = err
		}
	} else {
		conn.storage.discard_statement(conn.path) or { commit_err = err }
	}

	if conn.path != ':memory:' {
		flock_unlock_exclusive(conn.storage.file, conn.path)
		conn.storage.close_file()
		conn.options.mutex.unlock()
	}

	if err := commit_err {
		return err
	}
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

	// Readers must not write anything, including the header, since other
	// readers may be reading the file at the same time.
	flock_unlock_shared(conn.storage.file, conn.path)
	conn.storage.close_file()

	conn.options.mutex.runlock()
}

// has_next_value returns true if the tokens contain a NEXT VALUE FOR, which
// modifies the sequence.
fn has_next_value(tokens []Token) bool {
	for i in 1 .. tokens.len {
		if tokens[i - 1].token == token_next && tokens[i].token == token_value {
			return true
		}
	}

	return false
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

	stmt := parse_tokens(tokens)!
	elapsed_parse := t.elapsed()

	return PreparedStmt{stmt, map[string]Value{}, explain, has_next_value(tokens), &conn, elapsed_parse}
}

fn parse_tokens(tokens []Token) !Stmt {
	mut lexer := Lexer{tokens, 0}
	mut parser := yy_new_parser()
	parser.parse(mut lexer)!

	return (parser as YYParserImpl).lval.v as Stmt
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
	// An exact match on the argument types always wins. Otherwise, numeric
	// arguments may be implicitly cast to a wider numeric parameter type. The
	// standard defines the numeric functions for any <numeric value expression>
	// (6.30), so this lets ABS(-3) or LN(10) use the NUMERIC or DOUBLE PRECISION
	// implementation. If there are several candidates the cheapest one wins, so
	// an exact numeric prefers NUMERIC over DOUBLE PRECISION.
	mut best := ?Func(none)
	mut best_cost := -1
	for f in conn.funcs {
		if func_name != f.name || arg_types.len != f.arg_types.len {
			continue
		}

		mut cost := 0
		for i, t in arg_types {
			mut real_arg_type := t

			// TODO(elliotchance); For now, we just consider all CHARACTER types as
			//  CHARACTER VARYING.
			if t.typ == .is_character {
				real_arg_type = Type{SQLType.is_varchar, t.scale, 0, false}
			}

			// Only compare the SQLType so that the precision/scale/null isn't
			// part of the comparison.
			c := implicit_numeric_cast_cost(real_arg_type.typ, f.arg_types[i].typ) or {
				cost = -1
				break
			}

			// Aggregate functions are not (yet) implicitly cast.
			if c > 0 && f.is_agg {
				cost = -1
				break
			}

			cost += c
		}

		if cost == 0 {
			return f
		}

		if cost > 0 && (best_cost < 0 || cost < best_cost) {
			best = f
			best_cost = cost
		}
	}

	if f := best {
		return f
	}

	return sqlstate_42883('function does not exist: ${func_name}(${arg_types.map(it.str()).join(', ')})')
}

// implicit_numeric_cast_cost returns 0 if the types are the same, or a
// positive cost if from can be implicitly cast to the numeric type to when
// choosing a function. Casting an exact numeric to an approximate numeric costs
// more than widening within the same category.
fn implicit_numeric_cast_cost(from SQLType, to SQLType) ?int {
	if from == to {
		return 0
	}

	if !from.is_number() || !to.is_number() {
		return none
	}

	from_category, from_supertype := from.supertype()
	to_category, to_supertype := to.supertype()

	if from_category == to_category {
		if to in [.is_numeric, .is_decimal] || to_supertype > from_supertype {
			return 1
		}

		return none
	}

	// Exact numeric to approximate numeric.
	if to_category > from_category {
		return 2
	}

	return none
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
	conn.register_func(Func{function_name, arg_types, false, func, return_type, true})!
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

		mut catalog := conn.catalog()
		catalog.virtual_tables[table_name.storage_id()] = VirtualTable{
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

// begin_row must be called before evaluating the expressions for each new row
// so that NEXT VALUE FOR returns a new value.
//
// ISO/IEC 9075-2:2016(E), 4.27, Sequence generators
fn (mut conn Connection) begin_row() {
	conn.row_sequence_values = map[string]i64{}
}

fn (mut conn Connection) add_warning(warning IError) {
	conn.warnings << warning
	if conn.warnings.len > 100 {
		conn.warnings = conn.warnings[conn.warnings.len - 100..]
	}
}
