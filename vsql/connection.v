// connection.v is the main file and library entry point allows the database to
// be opened.

module vsql

import builtin.closure
import os
import sync
import sync.stdatomic
import time

// The concepts are described by:
//
// ISO/IEC 9075-1:2003(E), 4.2.3, SQL-implementations
// ISO/IEC 9075-1:2003(E), 4.2.3.2, SQL-servers

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
	// V never frees a closure on its own, and every expression that's compiled
	// makes some (see CompileResult). So each statement runs in a frame of
	// lifetime, and the closures it made are released when it ends, see
	// PreparedStmt.query. frame_work runs frame_stmt, it's made once so that it
	// isn't a closure that's leaked for each statement.
	lifetime     closure.Lifetime
	frame_work   fn () = unsafe { nil }
	frame_active bool
	frame_ran    bool
	frame_stmt   &PreparedStmt = unsafe { nil }
	frame_params map[string]Value
	frame_result Result
	frame_err    IError = none
	// parser_stack is kept between statements, see parse_statement.
	parser_stack []YYSymType
	catalogs     map[string]&CatalogConnection
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
	// subquery_scopes has one scope for each subquery (in an expression, such as
	// EXISTS) that's being planned or evaluated, the innermost last. A subquery
	// can refer to the columns of the queries that contain it, see SubqueryScope.
	subquery_scopes []SubqueryScope
	// subquery_results has the result of each subquery that has been evaluated
	// in the statement that's executing, by its query (see run_subquery). They're
	// cleared when each statement starts.
	subquery_results map[voidptr]SubqueryResult
	// subquery_tables has the id of each table that's read by a subquery that's
	// planned while collect_subquery_tables is set (see tables_of_subqueries).
	collect_subquery_tables bool
	subquery_tables         []string
	// flagging is true while PreparedStmt.features resolves the names of a
	// statement, see Connection.resolved_features.
	flagging bool
	// flagged_features and flagged_tables are what's been found while flagging.
	// flagged_tables has the tables read by a subquery, or by any part of the
	// query when flag_query_tables is set (for an INSERT).
	flagged_features  []string
	flagged_tables    []string
	flag_query_tables bool
	// next_value_not_allowed is set (to "UNION", etc.) while a query that can't
	// contain a NEXT VALUE FOR is being planned, see Compiler.
	next_value_not_allowed string
	// collect_columns is set while the sort keys of a cursor are being compiled
	// (see DeclareCursor.sort_columns). collected_columns then has the id of each
	// column that a column reference identifies, and correlated_columns has the
	// ids of the columns that each column of a correlation name comes from.
	collect_columns    bool
	collected_columns  map[string]bool
	correlated_columns map[string][]string
	// collected_subquery is set if a subquery is planned while collect_columns
	// is set. The columns that a subquery uses aren't all known until it runs.
	collected_subquery bool
	// in_derived_table is set while a derived table is being planned, but not a
	// subquery in one, see values_aggregation_query.
	in_derived_table bool
	// direct_query_transaction is true when an SQL-transaction was started by
	// a query in direct (see Connection.direct) that hasn't changed anything.
	direct_query_transaction bool
	// direct_query_headers has the header of each catalog (by name) that was
	// read by the first query of that SQL-transaction, see check_direct_query.
	direct_query_headers map[string]Header
	// cursors are the standing cursors that have been declared, by name (see
	// DeclareCursor).
	cursors map[string]&Cursor
	// statement_timestamp is the time (in UTC) and statement_time_zone is the
	// time zone (in minutes) of the statement that's executing. Every <datetime
	// value function> in the statement returns this time, see
	// set_statement_timestamp.
	statement_timestamp time.Time
	statement_time_zone i16
	// next_transaction is set by SET TRANSACTION for the next SQL-transaction,
	// whether it's started by START TRANSACTION or implicitly by a statement.
	next_transaction ?TransactionCharacteristics
	// read_only is the access mode of the current SQL-transaction, see
	// begin_transaction.
	read_only bool
	// isolation_level is the isolation level of the current SQL-transaction.
	isolation_level IsolationLevel = .serializable
	// default_isolation_level is ConnectionOptions.isolation_level, see
	// enduring_characteristics.
	default_isolation_level IsolationLevel = .serializable
	// cancel_state is whether a statement is executing (statement_running) and
	// whether it's been asked to stop (statement_canceled), see cancel. It's
	// changed by other threads, so it's only used atomically.
	cancel_state &stdatomic.AtomicVal[u32] = stdatomic.new_atomic[u32](statement_idle)
pub mut:
	// condition_area_limit is the most warnings that are kept during the current
	// SQL-transaction, which is set by DIAGNOSTICS SIZE (see
	// initiate_transaction).
	condition_area_limit int = max_conditions
	// now allows you to override the wall clock that is used. The Time must be
	// in UTC with a separate offset for the current local timezone (in positive
	// or negative minutes).
	now fn () (time.Time, i16) @[required]
	// warnings are SQLSTATE errors that do not stop the execution. For example,
	// if a value must be truncated during a runtime CAST.
	//
	// Warnings are not ever reset, although only 100 of the most recent warnings
	// (or the DIAGNOSTICS SIZE of the SQL-transaction) are retained. This is to be able to collect all warnings during some
	// arbitrary process defined by the application. Instead, you should call
	// clear_warnings() before starting a block of work.
	warnings []IError
	// more_conditions is true if a warning has been dropped from warnings since
	// the last clear_warnings(), because there were more than the limit.
	//
	// ISO/IEC 9075-2:2016(E), 23.1, <get diagnostics statement>, General Rules, 2.b
	more_conditions bool
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
		check_page_size(options.page_size)!
		// A log left behind by a file that was deleted must not be copied into
		// this one.
		os.rm(wal_path(path)) or {}
		init_database_file(path, options.page_size)!
		init_schema = true
	}

	mut conn := open_connection(path, options)!
	if init_schema {
		// The file is kept, but the connection must release its session lock.
		conn.query('CREATE SCHEMA public') or {
			conn.close()
			return err
		}
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

// open_connection initiates an SQL-session. Its SQL-session context starts
// with the catalog of the file (and the PUBLIC schema) as the defaults, the
// time zone of the system, no warnings, cursors or prepared statements, and
// no statement that's being executed.
//
// ISO/IEC 9075-2:2016(E), 18.1, <connect statement>, General Rules, 13, 13.f, 13.g, 13.j, 13.k and 13.m
fn open_connection(path string, options ConnectionOptions) !&Connection {
	catalog_name := catalog_name_from_path(path)

	mut conn := &Connection{
		current_catalog:         catalog_name
		current_schema:          default_schema_name
		now:                     default_now
		isolation_level:         options.isolation_level
		default_isolation_level: options.isolation_level
	}

	conn.lifetime = closure.new_lifetime()
	conn.frame_work = fn [mut conn] () {
		conn.frame_ran = true
		mut p := conn.frame_stmt
		conn.frame_result = p.query_statement(conn.frame_params) or {
			conn.frame_err = err
			Result{}
		}
	}

	register_builtin_funcs(mut conn)!
	register_operators(mut conn)

	conn.add_catalog(catalog_name, path, options)!

	return conn
}

// close releases the session lock of each file catalog. The connection must not
// be used after it's closed.
pub fn (mut conn Connection) close() {
	for _, mut catalog in conn.catalogs {
		if catalog.path != ':memory:' {
			catalog.storage.session.close()
			catalog.storage.isolation.release()
		}
	}
}

pub fn (mut conn Connection) add_catalog(catalog_name string, path string, options ConnectionOptions) ! {
	if catalog_name in conn.catalogs {
		return sqlstate_42p04(catalog_name)
	}

	// A file uses the page size it was created with.
	if path == ':memory:' {
		check_page_size(options.page_size)!
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
		catalog.storage.cache_size = options.cache_size
		catalog.storage.full_fsync = options.full_fsync
		catalog.storage.isolation = IsolationLock{
			path: isolation_path(path)
		}
		catalog.recover_log() or {
			catalog.storage.session.close()
			return err
		}
	}

	register_information_schema(mut catalog)!

	in_transaction := conn.in_transaction()

	// A catalog added during a transaction joins it, so it must be locked
	// first, see isolation.v.
	if in_transaction && conn.isolation_level.locks_transaction() {
		catalog.lock_transaction(conn.read_only) or {
			catalog.storage.session.close()
			return err
		}
	}
	conn.catalogs[catalog_name] = catalog

	if path == ':memory:' {
		conn.query("SET CATALOG '${catalog_name}'")!
		conn.query('CREATE SCHEMA public')!
		conn.query("SET CATALOG '${conn.current_catalog}'")!
	}

	if in_transaction {
		catalog.start_transaction()!
		catalog.finish_write(true)!
	}
}

// recover_log copies the log into the database file when it's the first
// connection to the file, because the power may have failed since the last
// connection, which loses changes to the database file that weren't synced. If
// there's another connection, then the power hasn't failed since it opened.
fn (mut conn CatalogConnection) recover_log() ! {
	if !wal_has_statements(conn.path) || !conn.storage.session.try_exclusive()! {
		return
	}

	// The session lock must go back to shared even if copying the log fails,
	// otherwise no other connection can open the database.
	conn.replay_log() or {
		conn.storage.session.shared() or {}
		return err
	}
	conn.storage.session.shared()!
}

// replay_log copies the log into the database file, see recover_log.
fn (mut conn CatalogConnection) replay_log() ! {
	conn.options.mutex.@lock()
	defer {
		conn.options.mutex.unlock()
	}

	conn.storage.open_file(conn.path)!
	defer {
		conn.storage.close_file()
	}

	flock_lock_exclusive(mut conn.storage.data_lock, conn.storage.file, conn.path)!
	defer {
		flock_unlock_exclusive(mut conn.storage.data_lock, conn.storage.file, conn.path)
	}

	wal_replay(mut conn.storage.file, conn.path, conn.options.full_fsync) or { return io_error(err) }
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
	flock_lock_shared(mut conn.storage.data_lock, conn.storage.file, conn.path) or {
		conn.storage.close_file()
		conn.options.mutex.runlock()
		return err
	}

	// A statement that was committed to the write-ahead log but not copied
	// into the database file (because the process stopped) must be copied
	// before the file can be read. That needs the file to be locked
	// exclusively.
	if wal_needs_recovery(conn.path) {
		flock_unlock_shared(mut conn.storage.data_lock, conn.storage.file, conn.path)
		flock_lock_exclusive(mut conn.storage.data_lock, conn.storage.file, conn.path) or {
			conn.storage.close_file()
			conn.options.mutex.runlock()
			return err
		}
		wal_recover(mut conn.storage.file, conn.path, conn.options.full_fsync) or {
			flock_unlock_exclusive(mut conn.storage.data_lock, conn.storage.file, conn.path)
			conn.storage.close_file()
			conn.options.mutex.runlock()
			return io_error(err)
		}
		flock_unlock_exclusive(mut conn.storage.data_lock, conn.storage.file, conn.path)
		flock_lock_shared(mut conn.storage.data_lock, conn.storage.file, conn.path) or {
			conn.storage.close_file()
			conn.options.mutex.runlock()
			return err
		}
	}
	conn.storage.open(conn.catalog_name, false) or {
		flock_unlock_shared(mut conn.storage.data_lock, conn.storage.file, conn.path)
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
	flock_lock_exclusive(mut conn.storage.data_lock, conn.storage.file, conn.path) or {
		conn.storage.close_file()
		conn.options.mutex.unlock()
		return err
	}
	wal_recover(mut conn.storage.file, conn.path, conn.options.full_fsync) or {
		flock_unlock_exclusive(mut conn.storage.data_lock, conn.storage.file, conn.path)
		conn.storage.close_file()
		conn.options.mutex.unlock()
		return io_error(err)
	}
	conn.storage.open(conn.catalog_name, true) or {
		flock_unlock_exclusive(mut conn.storage.data_lock, conn.storage.file, conn.path)
		conn.storage.close_file()
		conn.options.mutex.unlock()
		return err
	}
	if !conn.storage.header.is_writable() || fault_reached('write_version') {
		flock_unlock_exclusive(mut conn.storage.data_lock, conn.storage.file, conn.path)
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
		flock_unlock_exclusive(mut conn.storage.data_lock, conn.storage.file, conn.path)
		conn.storage.close_file()
		conn.options.mutex.unlock()
	}

	if err := commit_err {
		return err
	}
}

// take_isolation_error returns the first error from the end of an isolation
// block in any catalog, see Storage.end_isolation.
fn (mut conn Connection) take_isolation_error() ! {
	mut first_err := ?IError(none)
	for _, mut catalog in conn.catalogs {
		catalog.storage.take_isolation_error() or {
			if first_err == none {
				first_err = err
			}
		}
	}

	if err := first_err {
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
	flock_unlock_shared(mut conn.storage.data_lock, conn.storage.file, conn.path)
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
	stmt, explain, tokens, features := parse_sql(sql_stmt, mut conn.parser_stack)!
	elapsed_parse := t.elapsed()

	return PreparedStmt{
		stmt:               stmt
		explain:            explain
		writes:             has_next_value(tokens)
		dynamic_parameters: tokens.filter(it.token == token_operator_question_mark).len
		features:           features
		c:                  &conn
		elapsed_parse:      elapsed_parse
	}
}

// parse_sql parses a statement. It returns the statement, whether it's
// EXPLAINed, its tokens (without the EXPLAIN) and the features that it uses.
fn parse_sql(sql_stmt string, mut stack []YYSymType) !(Stmt, bool, []Token, []string) {
	mut tokens, lexical_features := tokenize_with_features(sql_stmt)!

	// EXPLAIN is super helpful, but not part of the SQL standard so we only
	// treat it as a prefix that is trimmed off before parsing. A statement that
	// is only white space and comments has no tokens, which is a syntax error.
	mut explain := false
	if tokens.len > 0 && tokens[0].value is IdentifierChain {
		if tokens[0].value.identifier.to_upper() == 'EXPLAIN' {
			explain = true
			tokens = tokens[1..].clone()
		}
	}

	stmt, mut features := parse_statement(tokens, sql_stmt, mut stack)!
	features << lexical_features
	// Only a query, searched DELETE or searched UPDATE can be explained, any
	// other statement is an error when it's executed (so isn't flagged).
	if explain {
		match stmt {
			QueryExpression { features << vsql_explain_query }
			DeleteStatementSearched { features << vsql_explain_delete }
			UpdateStatementSearched { features << vsql_explain_update }
			else {}
		}
	}

	return stmt, explain, tokens, features
}

fn parse_tokens(tokens []Token) !Stmt {
	mut stack := []YYSymType{}
	stmt, _ := parse_statement(tokens, '', mut stack)!

	return stmt
}

// parse_statement parses a statement, and also returns the features outside of
// Core SQL that it uses (see flag). source is the text of the tokens, if a syntax
// error should say where it is (see describe_syntax_error).
//
// stack is the stack of the parser, which is kept by a connection so that it's
// only made once.
fn parse_statement(tokens []Token, source string, mut stack []YYSymType) !(Stmt, []string) {
	mut lexer := Lexer{
		tokens: tokens
		source: source
	}
	mut parser := YYParserImpl{
		stack: stack
	}
	defer {
		stack = parser.stack
	}
	parser.parse(mut lexer)!
	lexer.features << token_features(tokens)

	return yy_stmt(parser.lval.v), lexer.features
}

// query executes a statement. If there is a result set it will be returned.
pub fn (mut conn Connection) query(sql_stmt string) !Result {
	mut prepared := conn.prepare(sql_stmt)!

	return prepared.query(map[string]Value{})
}

// The values of Connection.cancel_state.
const statement_idle = u32(0)
const statement_running = u32(1)
const statement_canceled = u32(2)

// cancel asks the statement that's executing on the connection (on another
// thread) to stop, and returns true if there was one. It's the only function
// that may be called while the connection is being used by another thread. The
// statement fails soon after with a 57014 query canceled, which (like any other
// error) leaves the database as it was before the statement. Nothing happens
// if a statement isn't executing, so a statement that starts after cancel
// returns isn't canceled.
pub fn (conn &Connection) cancel() bool {
	mut state := conn.cancel_state

	return state.compare_and_swap(statement_running, statement_canceled)
}

// check_canceled raises 57014 query canceled if the statement that's executing
// has been canceled. It's checked for each row (or batch of rows) that's
// processed, so that a long statement stops soon after it's canceled.
fn (conn &Connection) check_canceled() ! {
	mut state := conn.cancel_state
	if state.load() == statement_canceled {
		return sqlstate_57014()
	}
}

// in_transaction is true while START TRANSACTION is active. Every catalog is in
// the same SQL-transaction.
pub fn (conn Connection) in_transaction() bool {
	for _, catalog in conn.catalogs {
		if catalog.storage.transaction_state == .active {
			return true
		}
	}

	return false
}

// current_catalog_name is the CURRENT_CATALOG of the connection.
pub fn (conn Connection) current_catalog_name() string {
	return conn.current_catalog
}

// rollback_after_error rolls back the current transaction (if any) after a
// statement raised an exception condition in class 40 (transaction rollback),
// such as a serialization failure (ISO/IEC 9075-2:2016(E), 4.41.5, Implicit
// rollbacks). Any other exception only cancels the statement that raised it,
// see PreparedStmt.query. If the rollback fails, the
// transaction is still active.
fn (mut conn Connection) rollback_after_error() ! {
	if !conn.in_transaction() {
		return
	}

	RollbackStatement{}.execute(mut conn, map[string]Value{}, time.Duration(0))!
	conn.finish_write(true)!
}

// register_func adds a function, unless one with the same name and argument
// types already exists. Only the arguments choose which function is called, so
// the return type doesn't matter (ISO/IEC 9075-2:2016(E), 11.60, <SQL-invoked
// routine>, Syntax Rules, 20). CHARACTER arguments are CHARACTER VARYING, see
// find_function.
fn (mut conn Connection) register_func(func Func) ! {
	for f in conn.funcs {
		if f.name == func.name && f.arg_types.len == func.arg_types.len
			&& f.arg_types.map(function_arg_type(it)) == func.arg_types.map(function_arg_type(it)) {
			return sqlstate_42723('${func.name}(${func.arg_types.map(it.str()).join(', ')})')
		}
	}

	conn.funcs << func
}

fn function_arg_type(t Type) SQLType {
	return if t.typ == .is_character { .is_varchar } else { t.typ }
}

pub fn (mut conn Connection) catalog() &CatalogConnection {
	return conn.catalogs[conn.current_catalog] or {
		panic('unknown catalog: ${conn.current_catalog}')
	}
}

// catalog_for returns the catalog of a fully qualified identifier, such as one
// from resolve_schema_identifier(), which has already checked that it exists.
fn (mut conn Connection) catalog_for(ident Identifier) &CatalogConnection {
	return conn.catalogs[ident.catalog_name] or {
		panic('unknown catalog: ${ident.catalog_name}')
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

			// All CHARACTER types are considered to be CHARACTER VARYING.
			if t.typ == .is_character {
				real_arg_type = Type{SQLType.is_varchar, t.scale, 0, false}
			}

			// Only compare the SQLType so that the precision/scale/null isn't
			// part of the comparison.
			c := implicit_numeric_cast_cost(real_arg_type.typ, f.arg_types[i].typ) or {
				cost = -1
				break
			}

			// Aggregate functions are not (yet) implicitly cast, except the binary
			// set functions (see register_builtin_funcs).
			if c > 0 && f.is_agg && f.name !in binary_set_functions {
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
pub fn (mut conn Connection) register_function(prototype string, func fn (FunctionContext, []Value) !Value) ! {
	// The prototype is "name(type, ...) type".
	open_paren := prototype.index('(') or { -1 }
	close_paren := prototype.last_index(')') or { -1 }
	if open_paren < 1 || close_paren < open_paren || prototype[close_paren + 1..].trim_space() == '' {
		return sqlstate_42601('invalid function prototype: ${prototype}')
	}

	function_name := new_function_identifier(prototype[..open_paren].trim_space())!.entity_name
	mut arg_types := []Type{}
	for arg in prototype[open_paren + 1..close_paren].split(',') {
		if arg.trim_space() != '' {
			arg_types << type_from_name(arg.trim_space().to_upper(), 0, 0)!
		}
	}

	return_type := type_from_name(prototype[close_paren + 1..].trim_space().to_upper(), 0, 0)!
	conn.register_func(Func{function_name, arg_types, false, func, return_type, true, false})!
}

// register_virtual_table will register a function that can provide data at
// runtime to a virtual table.
pub fn (mut conn Connection) register_virtual_table(create_table string, data VirtualTableProviderFn) ! {
	// Registering virtual tables does not need use query cache.
	mut tokens := tokenize(create_table)!
	mut lexer := Lexer{
		tokens: tokens
		source: create_table
	}
	mut parser := yy_new_parser()
	parser.parse(mut lexer)!
	stmt := yy_stmt((parser as YYParserImpl).lval.v)

	if stmt is TableDefinition {
		stmt.check_limits(stmt.table_name)!

		// The schemas aren't loaded until the connection reads the file.
		conn.open_read_connection()!
		table_name := conn.resolve_schema_identifier(stmt.table_name) or {
			conn.release_read_connection()
			return err
		}
		check_writable_schema(table_name) or {
			conn.release_read_connection()
			return err
		}

		// A virtual table would hide a table with the same name.
		mut catalog := conn.catalog_for(table_name)
		id := table_name.storage_id()
		exists := id in catalog.storage.tables || id in catalog.virtual_tables
		conn.release_read_connection()
		if exists {
			return sqlstate_42p07('table', table_name.str()) // duplicate table
		}

		catalog.virtual_tables[id] = VirtualTable{
			create_table_sql:  create_table
			create_table_stmt: TableDefinition{
				...stmt
				table_name: table_name
			}
			data:              data
		}

		return
	}

	return sqlstate_42601('must provide a CREATE TABLE statement')
}

// schemas returns the schemas in this catalog (database). This includes the
// INFORMATION_SCHEMA (and the schema of any other virtual table), which has
// is_virtual set.
pub fn (mut conn CatalogConnection) schemas() ![]Schema {
	conn.open_read_connection()!
	defer {
		conn.release_read_connection()
	}

	mut schemas := []Schema{}
	for _, schema in conn.storage.schemas {
		schemas << schema
	}
	for _, virtual_table in conn.virtual_tables {
		name := virtual_table.create_table_stmt.table_name.schema_name
		if !schemas.any(it.name == name) {
			schemas << Schema{
				name:       name
				is_virtual: true
			}
		}
	}

	conn.storage.take_isolation_error()!

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

	conn.storage.take_isolation_error()!

	return sequences
}

// indexes returns the indexes (see CREATE INDEX) of the tables in the provided
// schema, sorted by table name and then index name. If the schema does not exist
// an empty list will be returned.
pub fn (mut conn CatalogConnection) indexes(schema string) ![]Index {
	conn.open_read_connection()!
	defer {
		conn.release_read_connection()
	}

	mut indexes := []Index{}
	for _, index in conn.storage.indexes {
		if index.name.schema_name == schema {
			indexes << index
		}
	}
	indexes.sort(a.sort_key() < b.sort_key())

	conn.storage.take_isolation_error()!

	return indexes
}

// identity_sequence returns the sequence of the identity column of a table, with
// its current value.
fn (mut conn CatalogConnection) identity_sequence(table Table) !Sequence {
	conn.open_read_connection()!
	defer {
		conn.release_read_connection()
	}

	sequence := conn.storage.identity_sequence(table)!
	conn.storage.take_isolation_error()!

	return sequence
}

// schema_tables returns tables for the provided schema. This includes virtual
// tables (such as the views of the INFORMATION_SCHEMA, or one registered with
// register_virtual_table()), which have is_virtual set. If the schema does not
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
	for _, virtual_table in conn.virtual_tables {
		if virtual_table.create_table_stmt.table_name.schema_name == schema {
			tables << virtual_table.table()
		}
	}

	conn.storage.take_isolation_error()!

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

	if ident.schema_name !in conn.catalog_for(ident).storage.schemas
		&& ident.schema_name != information_schema_name {
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
		return sqlstate_3d000(ident.catalog_name)
	}

	if id in catalog.storage.tables {
		return ident
	}

	if allow_virtual && id in catalog.virtual_tables {
		return ident
	}

	// A table that's going to be changed can't be in the INFORMATION_SCHEMA.
	if !allow_virtual {
		check_writable_schema(ident)!
	}

	return sqlstate_42p01_table(ident) // table does not exist
}

// ConnectionOptions can modify the behavior of a connection when it is opened.
// You should not create the ConnectionOptions instance manually. Instead, use
// default_connection_options() as a starting point and modify the attributes.
pub struct ConnectionOptions {
pub mut:
	// page_size is the size of each page in bytes, which must be more than 16
	// and at most 65535. It's only used for :memory: databases and new files, a
	// file always uses the page size it was created with.
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
	// create_index_timeout is how long CREATE INDEX waits for other
	// transactions that have changed the table to finish (the index can't
	// include rows that it can't see yet), before it fails with a 55P03 lock
	// not available. The default is 60 seconds.
	create_index_timeout time.Duration
	// cache_size is the number of pages of a file that are kept in memory while
	// a statement runs, so that a page that's used again (such as by a scan or
	// a search of the B-tree) doesn't need to be read from the file again. The
	// default is 2000 (8 MiB with the default page_size). 0 doesn't keep any.
	// Pages are only kept for one statement, since another connection may
	// change the file between statements.
	cache_size int
	// lock_timeout is how long a REPEATABLE READ or SERIALIZABLE transaction
	// (including a statement that changes the database outside of a
	// transaction) waits for another connection's transaction to finish, before
	// it fails with a 40001 serialization failure. The default is 5 seconds.
	lock_timeout time.Duration
	// isolation_level is the isolation level of an SQL-transaction that doesn't
	// have one from START TRANSACTION or SET TRANSACTION, including a statement
	// outside of a transaction. The default is SERIALIZABLE, like the standard.
	// A READ COMMITTED transaction doesn't stop other connections from
	// committing while it runs (see isolation.v), but it fails with 40001 if it
	// commits while another connection has a REPEATABLE READ or SERIALIZABLE
	// transaction. Only the options that the connection is opened with are
	// used, not the ones given to add_catalog.
	isolation_level IsolationLevel = .serializable
	// full_fsync only makes a difference on macOS, where it's off by default.
	// A file is synced (with fsync) when a statement is committed, but on
	// macOS that only hands the changes to the drive, which may keep them in
	// its cache for a while, and may write it in a different order. If the
	// power fails (or the operating system stops), statements that were
	// committed may be lost, and the database file may even be left corrupt.
	// Stopping the process is always safe. full_fsync uses F_FULLFSYNC instead,
	// which also waits for the drive to write its cache. It is much slower
	// (7 to 15 times slower for "vsql bench" on a Mac). On Linux and
	// Windows, syncing a file already writes the cache of the drive, so
	// full_fsync is accepted but does nothing.
	full_fsync bool
}

// default_connection_options returns the sensible defaults used by open() and
// the correct base to provide your own option overrides. See ConnectionOptions.
pub fn default_connection_options() ConnectionOptions {
	return ConnectionOptions{
		page_size:            4096
		mutex:                sync.new_rwmutex()
		create_index_timeout: 60 * time.second
		cache_size:           2000
		lock_timeout:         5 * time.second
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
	conn.more_conditions = false
}

// begin_row must be called before evaluating the expressions for each new row
// so that NEXT VALUE FOR returns a new value.
//
// ISO/IEC 9075-2:2016(E), 4.27, Sequence generators
//
// The rows of a subquery (in an expression) don't begin a new row because
// they're part of the row that contains the subquery, and NEXT VALUE FOR can't
// be used in a subquery.
fn (mut conn Connection) begin_row() {
	if conn.subquery_scopes.len == 0 {
		conn.row_sequence_values = map[string]i64{}
	}
}

fn (mut conn Connection) add_warning(warning IError) {
	conn.warnings << warning
	if conn.warnings.len > conn.condition_area_limit {
		conn.warnings = conn.warnings[conn.warnings.len - conn.condition_area_limit..]
		conn.more_conditions = true
	}
}
