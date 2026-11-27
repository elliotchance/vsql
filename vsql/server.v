// server.v can be used to start a server that will listen for connections from
// PostgreSQL compatible clients. See pg.v.

module vsql

import encoding.binary
import math
import net
import sync

// ConnectFn opens the database for a client of a Server. database is the
// database name that the client connected with, which may be empty.
pub type ConnectFn = fn (database string) !&Connection

pub struct ServerOptions {
pub:
	// db_file is opened for every client, unless connect is set.
	db_file string
	// host is the address to listen on. If it's empty, 127.0.0.1 is used, which
	// only accepts clients on the same machine. Use 0.0.0.0 (every IPv4
	// interface) or :: (every interface) to accept clients from other machines.
	// An IPv6 address doesn't need brackets.
	host string
	// port to listen on. If it's 0, any free port is used, see Server.port().
	port int
	// verbose prints every message in and out of the server.
	verbose bool
	// connect opens the database for each client, instead of db_file. This can
	// be used to configure the connection (such as with register_function), or
	// to choose the database from the name the client connected with. The
	// server closes the connection when the client disconnects.
	connect ConnectFn = unsafe { nil }
	// select_without_from adds "FROM singlerow" to a query that has a SELECT
	// but no FROM, which isn't valid SQL but is sent by many PostgreSQL clients.
	// The singlerow table is created if it doesn't exist.
	select_without_from bool
	// ignore_pg_set replies "SET" to a PostgreSQL SET of a run-time parameter,
	// such as "SET LOCAL search_path TO public", without running it. These
	// aren't valid SQL but are sent by many PostgreSQL clients. A SET of
	// anything in the SQL standard (such as SET SCHEMA) still runs.
	ignore_pg_set bool
	// rewrite_pg_syntax changes the PostgreSQL syntax that clients use to read
	// the system catalog (such as pg_class, see register_pg_virtual_tables)
	// into SQL before it's run, see rewrite_pg_syntax.
	rewrite_pg_syntax bool
	// lower_case_names sends the name of a column in lower case if it has no
	// lower case letters (such as a name that wasn't quoted), like PostgreSQL
	// does. Clients find the columns of their catalog queries by these names.
	lower_case_names bool
}

// Server accepts connections from PostgreSQL clients, see new_server.
@[heap]
pub struct Server {
	options ServerOptions
mut:
	connect  ConnectFn        = unsafe { nil }
	listener &net.TcpListener = unsafe { nil }
	// mutex is for stopping and serving, so that stop and serve agree on which
	// of them closes the listener.
	mutex    &sync.Mutex = sync.new_mutex()
	stopping bool
	serving  bool
}

// new_server creates a server that can be started with start(), or with
// listen() and serve() to be able to find its port before it accepts clients.
pub fn new_server(options ServerOptions) &Server {
	mut connect := options.connect
	if connect == unsafe { nil } {
		// Each client has its own connection (so they each have their own
		// transaction) in its own thread. They must share the same mutex, see
		// ConnectionOptions.
		mut connection_options := default_connection_options()
		connection_options.mutex = sync.new_rwmutex()
		db_file := options.db_file
		connect = fn [db_file, connection_options] (database string) !&Connection {
			return open_database(db_file, connection_options)
		}
	}

	return &Server{
		options: options
		connect: connect
	}
}

// start listens for clients and serves them until stop() is called.
pub fn (mut s Server) start() ! {
	s.listen()!
	s.serve()!
}

// listen starts listening on the port, but clients aren't accepted until
// serve() is called.
pub fn (mut s Server) listen() ! {
	host := if s.options.host == '' { '127.0.0.1' } else { s.options.host }
	mut family := net.AddrFamily.ip
	mut address := '${host}:${s.options.port}'
	if host.contains(':') {
		family = .ip6
		address = '[${host}]:${s.options.port}'
	}

	s.listener = net.listen_tcp(family, address) or {
		return error('cannot listen on ${address}: ${err}')
	}
}

// address is the address and port the server is listening on, such as
// "127.0.0.1:3210" or "[::]:3210".
pub fn (s &Server) address() !string {
	if s.listener == unsafe { nil } {
		return error('server is not listening')
	}

	return s.listener.addr()!.str()
}

// port is the port the server is listening on, which is only known after
// listen() when ServerOptions.port is 0.
pub fn (s &Server) port() !int {
	if s.listener == unsafe { nil } {
		return error('server is not listening')
	}

	return s.listener.addr()!.port()!
}

// serve accepts clients until stop() is called. Each client is handled in its
// own thread.
pub fn (mut s Server) serve() ! {
	if s.listener == unsafe { nil } {
		return error('server is not listening')
	}

	s.mutex.lock()
	if s.stopping {
		s.mutex.unlock()
		return
	}
	s.serving = true
	s.mutex.unlock()

	for {
		mut conn := s.accept() or {
			s.log('${err}')
			continue
		}

		// stop holds the mutex while it connects to wake this up, so the
		// listener isn't closed (below) before it has connected.
		s.mutex.lock()
		stopping := s.stopping
		s.mutex.unlock()
		if stopping {
			conn.close() or {}
			break
		}

		spawn s.handle_client(mut conn)
	}

	// The listener is closed here, not in stop, because its file descriptor could
	// be reused by a new listener while this is about to wait for a client. It
	// would then accept the clients of the new listener.
	s.listener.close()!
}

// accept waits for the next client. A test can make it fail with the "accept"
// fault, which disconnects the client, see fault.v.
fn (mut s Server) accept() !&net.TcpConn {
	mut conn := s.listener.accept()!

	// A client can wait for as long as it likes between statements, like it can
	// with PostgreSQL. Otherwise V disconnects it after 30 seconds.
	conn.set_read_timeout(net.infinite_timeout)

	fault_point('accept') or {
		conn.close() or {}
		return err
	}

	return conn
}

// stop stops accepting new clients. Clients that are already connected are not
// disconnected.
pub fn (mut s Server) stop() ! {
	if s.listener == unsafe { nil } {
		return
	}
	address := s.address()!

	s.mutex.lock()
	defer {
		s.mutex.unlock()
	}
	if s.stopping {
		return
	}
	s.stopping = true

	if !s.serving {
		s.listener.close()!
		return
	}

	// Connecting wakes up serve, which closes the listener. The mutex is held
	// until it has connected, otherwise serve could wake up for another client,
	// see that it's stopping and close the listener first. Connecting to a
	// closed port takes about 2 seconds on Windows, rather than failing straight
	// away.
	mut wake := net.dial_tcp(address.replace('0.0.0.0:', '127.0.0.1:').replace('[::]:', '[::1]:'))!
	wake.close()!
}

// handle_client runs in its own thread for each client. An error only
// disconnects that client.
fn (s &Server) handle_client(mut c net.TcpConn) {
	mut conn := new_pg_conn(c)
	conn.lower_case_names = s.options.lower_case_names
	database := conn.accept() or {
		s.log('error: ${err}')
		c.close() or {}
		return
	}

	mut db := s.connect(database) or {
		s.log('cannot open database: ${err}')
		conn.write_error_result(err) or {}
		conn.flush() or {}
		c.close() or {}
		return
	}

	s.handle_conn(mut db, mut conn, database) or { s.log('error: ${err}') }

	// A client that disconnects in the middle of a transaction implicitly rolls
	// it back.
	db.rollback_after_error() or { s.log('error: ${err}') }
	db.close()

	c.close() or {}
	s.log('disconnected')
}

fn (s &Server) log(message string) {
	if s.options.verbose {
		println(message)
	}
}

// is_empty_query is true if a query only has white space, comments and
// semicolons. A query that can't be tokenized isn't empty, so that its error is
// returned.
fn is_empty_query(query string) bool {
	tokens := tokenize(query) or { return false }

	return tokens.all(it.token == token_operator_semicolon)
}

// is_pg_set is true if a query is a PostgreSQL SET of a run-time parameter:
// SET [ SESSION | LOCAL ] <name> { TO | = } ... The name is never a keyword, so
// it's never a SET statement in the SQL standard.
fn is_pg_set(query string) bool {
	tokens := tokenize(query) or { return false }
	mut i := 0
	if tokens.len == 0 || tokens[i].token != token_set {
		return false
	}
	i++
	if i < tokens.len && tokens[i].token in [token_session, token_local] {
		i++
	}

	return i + 1 < tokens.len && tokens[i].token == token_literal_identifier
		&& tokens[i + 1].token in [token_to, token_operator_equals]
}

// rewrite_pg_syntax changes the PostgreSQL type of a cast ("x::int8") into an
// SQL type ("x::BIGINT", see pg_type_name), removes "pg_catalog." before a name,
// because the system catalog is in the default schema, and gives an untyped NULL
// column a type (see pg_is_untyped_null). The "::" itself is a cast in vsql
// (V303-01). Text in quotes and comments isn't changed.
fn rewrite_pg_syntax(query string) string {
	mut out := []u8{}
	mut i := 0
	for i < query.len {
		ch := query[i]

		// Copy strings, delimited identifiers and comments as they are.
		mut end := i
		if ch == `'` || ch == `"` {
			end = i + 1
			for end < query.len {
				if query[end] == ch {
					if end + 1 < query.len && query[end + 1] == ch {
						end += 2
						continue
					}
					break
				}
				end++
			}
			end = if end < query.len { end + 1 } else { end }
		} else if query[i..].starts_with('--') {
			end = query.index_after('\n', i) or { query.len }
		} else if query[i..].starts_with('/*') {
			end = query.index_after('*/', i) or { query.len - 2 } + 2
		}
		if end > i {
			out << query[i..end].bytes()
			i = end
			continue
		}

		if i + pg_catalog_prefix.len <= query.len
			&& query[i..i + pg_catalog_prefix.len].to_lower() == pg_catalog_prefix
			&& (i == 0 || !is_pg_name_byte(query[i - 1])) {
			i += pg_catalog_prefix.len
			continue
		}

		// current_schema() is a function in PostgreSQL, but CURRENT_SCHEMA is a
		// value without parentheses in SQL.
		if query[i..].to_lower().starts_with('current_schema()')
			&& (i == 0 || !is_pg_name_byte(query[i - 1])) {
			out << 'CURRENT_SCHEMA'.bytes()
			i += 'current_schema()'.len
			continue
		}

		if pg_is_untyped_null(query, i, out) {
			out << 'CAST(NULL AS BIGINT)'.bytes()
			i += 4
			continue
		}

		if query[i..].starts_with('::') {
			mut type_start := i + 2
			for type_start < query.len && query[type_start] == ` ` {
				type_start++
			}
			mut type_end := type_start
			for type_end < query.len && is_pg_name_byte(query[type_end]) {
				type_end++
			}
			out << '::${pg_type_name(query[type_start..type_end])}'.bytes()
			i = type_end
			continue
		}

		out << ch
		i++
	}

	return out.bytestr()
}

const pg_catalog_prefix = 'pg_catalog.'

// pg_is_untyped_null is true for a NULL at i that's a column of a select list
// (after a comma or SELECT, and before AS), which PostgreSQL allows without a
// type. Clients use it for a size in a UNION, so it's a BIGINT.
fn pg_is_untyped_null(query string, i int, out []u8) bool {
	if i + 4 > query.len || query[i..i + 4].to_upper() != 'NULL'
		|| (i + 4 < query.len && is_pg_name_byte(query[i + 4])) {
		return false
	}
	before := out.bytestr().trim_right(' \t\n').to_upper()
	if !before.ends_with(',') && !(before.ends_with('SELECT')
		&& (before.len == 6 || !is_pg_name_byte(before[before.len - 7]))) {
		return false
	}
	after := query[i + 4..].trim_left(' \t\n').to_upper()

	return after.starts_with('AS') && (after.len == 2 || !is_pg_name_byte(after[2]))
}

fn is_pg_name_byte(ch u8) bool {
	return ch.is_letter() || ch.is_digit() || ch == `_` || ch == `.`
}

// pg_type_name is the SQL type for a PostgreSQL type of a cast. A type that
// names an object (such as regtype) is a VARCHAR.
fn pg_type_name(name string) string {
	lower := name.to_lower().trim_string_left(pg_catalog_prefix)
	return match lower {
		'int2' { 'SMALLINT' }
		'int', 'int4', 'oid' { 'INTEGER' }
		'int8' { 'BIGINT' }
		'float4' { 'REAL' }
		'float8' { 'DOUBLE PRECISION' }
		'bool' { 'BOOLEAN' }
		'text', 'name', 'regtype', 'regclass', 'regproc', 'regnamespace' { 'VARCHAR(255)' }
		else { lower.to_upper() }
	}
}

// PGQueryKind is what the server does with a query from a client, see
// Server.rewrite_query.
enum PGQueryKind {
	// statement is run.
	statement
	// empty is a query without a statement, which is replied to with an
	// EmptyQueryResponse.
	empty
	// ignored_set is a PostgreSQL SET (see ServerOptions.ignore_pg_set), which
	// is replied to with "SET" without being run.
	ignored_set
}

// rewrite_query returns what to do with a query from a client, and the
// statement to run, with the changes that the ServerOptions make. It's the same
// for the simple and the extended query protocol.
fn (s &Server) rewrite_query(query string) (PGQueryKind, string) {
	// Only the reply of the server is different. The standard has no empty
	// statement, so it's still an error for Connection.query.
	if is_empty_query(query) {
		return .empty, query
	}

	if s.options.ignore_pg_set && is_pg_set(query) {
		return .ignored_set, query
	}

	mut rewritten := query
	if s.options.rewrite_pg_syntax {
		rewritten = rewrite_pg_syntax(rewritten)
	}

	// A missing "FROM" clause is valid in PostgreSQL, but it's not valid in the
	// SQL standard so it's not supported by vsql.
	query_upper := rewritten.to_upper()
	if s.options.select_without_from && query_upper.contains('SELECT')
		&& !query_upper.contains('FROM') {
		rewritten = rewritten.trim('; ') + ' FROM singlerow;'
	}

	return .statement, rewritten
}

// pg_begin is the result of a query, except that a BEGIN (which vsql runs as
// START TRANSACTION, see V114-01) is tagged BEGIN, like PostgreSQL. JDBC starts
// a transaction with BEGIN and fails without it.
fn pg_begin(query string, result Result) Result {
	if result.msg == 'START TRANSACTION'
		&& query.trim_left(' \t\r\n').to_upper().starts_with('BEGIN') {
		return Result{
			msg: 'BEGIN'
		}
	}

	return result
}

fn (s &Server) handle_conn(mut db Connection, mut conn PGConn, database string) ! {
	// We need to register some dummy functions commonly used in the connection
	// phase.
	db.register_postgresql(database)!

	if s.options.select_without_from {
		db.query('CREATE TABLE singlerow (x INT)') or {}
		if db.query('SELECT * FROM singlerow')!.rows.len == 0 {
			db.query('INSERT INTO singlerow (x) VALUES (0)')!
		}
	}

	conn.write_ready()!
	s.log('connected')

	mut extended := PGExtendedState{}
	for {
		msg_type := conn.read_byte()!
		match msg_type {
			`Q` { // Query
				kind, query := s.rewrite_query(conn.read_query()!)
				match kind {
					.empty {
						s.log('query: ${query}')
						conn.write_empty_query_response()!
					}
					.ignored_set {
						s.log('ignored: ${query}')
						conn.write_command_complete('SET')!
					}
					.statement {
						s.log('query: ${query}')

						db.clear_warnings()
						if result := db.query(query) {
							for warning in db.warnings {
								conn.write_notice(warning)!
							}

							s.log('response: ${result}')
							conn.write_result(pg_begin(query, result))!
						} else {
							s.log('error: ${err}')
							conn.write_error_result(err)!
						}
					}
				}

				conn.write_ready_for_query()!
			}
			`P`, `B`, `D`, `E`, `C`, `H`, `S` {
				mut msg := conn.read_message()!
				s.handle_extended(mut db, mut conn, mut extended, msg_type, mut msg)!
			}
			`X` { // Terminate
				// Don't bother consuming the message since we're going to
				// disconnect anyway.
				break
			}
			else {
				return error('unknown message: ${msg_type.str()}')
			}
		}
	}
}

// PGExtendedState is the state of a client that uses the extended query
// protocol, where a query is run with a Parse, Bind, Describe and Execute
// message each, followed by a Sync.
struct PGExtendedState {
mut:
	// statements are the prepared statements that were made by Parse, by name.
	// The unnamed statement has an empty name.
	statements map[string]PGStatement
	// portals are the prepared statements that have been given values by Bind,
	// by name. The unnamed portal has an empty name.
	portals map[string]PGPortal
	// failed is true after an error, until the next Sync. Like PostgreSQL, every
	// other message is ignored until then, since they may depend on the one
	// that failed.
	failed bool
}

// PGStatement is a prepared statement of the extended query protocol.
struct PGStatement {
	// query is the statement after it's been rewritten, see
	// Server.rewrite_query.
	query string
	kind  PGQueryKind
	// stmt is only prepared for a kind of statement.
	stmt ?PreparedStmt
	// parameter_oids are the types of the parameters that the client gave in
	// the Parse message, where 0 is unspecified. There may be fewer of them than
	// there are parameters.
	parameter_oids []int
}

// PGPortal is a prepared statement that has been given values for its
// parameters, and will be (or has been) executed.
struct PGPortal {
	statement PGStatement
	params    map[string]Value
	// formats are the format codes of the columns of its result, see pg_format.
	formats []int
mut:
	// executed is true once the statement has run, and result is its result.
	// An Execute with a maximum number of rows sends up to that many, starting
	// from next, so the rest are sent by the next Execute of the portal.
	executed bool
	result   Result
	next     int
}

// handle_extended handles a message of the extended query protocol. An error
// is sent to the client, after which every message is ignored until a Sync.
fn (s &Server) handle_extended(mut db Connection, mut conn PGConn, mut state PGExtendedState, msg_type u8, mut msg PGMessage) ! {
	// A Sync ends a transaction that's only for the statements since the last
	// Sync, so the portals that it had are gone, like PostgreSQL.
	if msg_type == `S` {
		s.log('sync')
		state.failed = false
		if !db.in_transaction() {
			state.portals.clear()
		}
		conn.write_ready_for_query()!
		return
	}

	if state.failed {
		s.log('ignored: ${msg_type.ascii_str()}')
		return
	}

	s.handle_extended_message(mut db, mut conn, mut state, msg_type, mut msg) or {
		s.log('error: ${err}')
		conn.write_error_result(err)!
		state.failed = true
	}
}

fn (s &Server) handle_extended_message(mut db Connection, mut conn PGConn, mut state PGExtendedState, msg_type u8, mut msg PGMessage) ! {
	match msg_type {
		`P` { // Parse
			name := msg.read_string()!
			kind, query := s.rewrite_query(msg.read_string()!)
			mut oids := []int{}
			for _ in 0 .. msg.read_int16()! {
				oids << msg.read_int32()!
			}
			if name != '' && name in state.statements {
				return pg_error('42P05', 'prepared statement "${name}" already exists')
			}

			s.log('parse ${pg_name(name)}: ${query}')
			state.statements[name] = PGStatement{
				query:          query
				kind:           kind
				stmt:           if kind == .statement {
					pg_prepare(mut db, query, oids)!
				} else {
					none
				}
				parameter_oids: oids
			}
			conn.write_empty_message(`1`)! // ParseComplete
		}
		`B` { // Bind
			portal_name := msg.read_string()!
			statement := state.find_statement(msg.read_string()!)!
			mut parameter_formats := []int{}
			for _ in 0 .. msg.read_int16()! {
				parameter_formats << msg.read_int16()!
			}
			mut params := map[string]Value{}
			for i in 0 .. msg.read_int16()! {
				len := msg.read_int32()!
				format := if parameter_formats.len == 1 {
					parameter_formats[0]
				} else {
					parameter_formats[i] or { 0 }
				}
				oid := statement.parameter_oids[i] or { 0 }
				params['?${i + 1}'] = if len < 0 {
					new_null_value(.is_varchar)
				} else {
					pg_parameter(msg.read_bytes(len)!, format, oid)!
				}
			}
			mut formats := []int{}
			for _ in 0 .. msg.read_int16()! {
				formats << msg.read_int16()!
			}

			s.log('bind ${pg_name(portal_name)}: ${params}')
			state.portals[portal_name] = PGPortal{
				statement: statement
				params:    params
				formats:   formats
			}
			conn.write_empty_message(`2`)! // BindComplete
		}
		`D` { // Describe
			if msg.read_byte()! == `S` {
				statement := state.find_statement(msg.read_string()!)!
				oids := statement.parameter_types()
				conn.write_parameter_description(oids)!

				// The values of the parameters aren't known yet, but each one
				// needs a value to find the columns.
				mut params := map[string]Value{}
				for i in 1 .. oids.len + 1 {
					params['?${i}'] = new_null_value(.is_varchar)
				}
				conn.write_columns(statement.columns(params)!, [])!
			} else {
				portal := state.find_portal(msg.read_string()!)!
				conn.write_columns(portal.statement.columns(portal.params)!, portal.formats)!
			}
		}
		`E` { // Execute
			name := msg.read_string()!
			max_rows := msg.read_int32()!
			mut portal := state.find_portal(name)!
			s.execute_portal(mut db, mut conn, mut portal, max_rows)!
			state.portals[name] = portal
		}
		`C` { // Close
			if msg.read_byte()! == `S` {
				state.statements.delete(msg.read_string()!)
			} else {
				state.portals.delete(msg.read_string()!)
			}
			conn.write_empty_message(`3`)! // CloseComplete
		}
		else { // Flush
			conn.flush()!
		}
	}
}

// pg_name is the name of a prepared statement or portal for the log, where an
// empty name is the unnamed one.
fn pg_name(name string) string {
	return if name == '' { '(unnamed)' } else { '"${name}"' }
}

// pg_error is an error that vsql itself doesn't raise, but a client of the
// server can get.
fn pg_error(code string, msg string) IError {
	return SQLState{
		code: sqlstate_to_int(code)
		msg:  msg
	}
}

fn (state PGExtendedState) find_statement(name string) !PGStatement {
	return state.statements[name] or {
		return pg_error('26000', 'prepared statement ${pg_name(name)} does not exist')
	}
}

fn (state PGExtendedState) find_portal(name string) !PGPortal {
	return state.portals[name] or { return pg_error('34000', 'portal ${pg_name(name)} does not exist') }
}

// pg_prepare prepares a statement of a Parse message. A parameter whose type
// can't be determined from where it's used (such as "SELECT $1") is a syntax
// error, unless the client gave it a type, which it's then cast to.
fn pg_prepare(mut db Connection, query string, oids []int) !PreparedStmt {
	if stmt := db.prepare(query) {
		return stmt
	} else {
		if err !is SQLState42601 || oids.all(it == 0) {
			return err
		}
	}

	return db.prepare(pg_cast_parameters(query, oids)!)
}

// pg_cast_parameters puts each parameter ("$1", etc) that has a type in oids
// into a CAST to that type.
fn pg_cast_parameters(query string, oids []int) !string {
	runes := query.runes()
	mut out := ''
	mut at := 0
	for token in tokenize(query)! {
		if token.token != token_operator_question_mark {
			continue
		}
		oid := oids[(token.value as string)[1..].int() - 1] or { 0 }
		name := if oid in [25, 1042] { 'character varying' } else { pg_format_type(oid, -1) }
		if name == '???' {
			continue
		}
		out += runes[at..token.start].string()
		out += 'CAST(${runes[token.start..token.end].string()} AS ${name.to_upper()})'
		at = token.end
	}

	return out + runes[at..].string()
}

// pg_parameter is the value of a parameter of a Bind message, in a format (0
// for text or 1 for binary). Its type is oid, from the Parse message, or 0 if
// it wasn't given. Text is a CHARACTER VARYING, which is then cast to the type
// of the parameter, see PreparedStmt.with_parameters. The binary format is only
// supported for a text type and the pg_binary_types.
fn pg_parameter(data []u8, format int, oid int) !Value {
	if format == 0 || oid in [25, 1042, 1043] {
		return new_varchar_value(data.bytestr())
	}

	pg_type := pg_types.filter(it.oid == oid)
	if pg_type.len == 0 || pg_type[0].len != data.len {
		return sqlstate_0a000('binary format of parameter type ${oid} is not supported')
	}

	return match oid {
		16 { new_boolean_value(data[0] != 0) }
		20 { new_bigint_value(i64(binary.big_endian_u64(data))) }
		21 { new_smallint_value(i16(binary.big_endian_u16(data))) }
		23 { new_integer_value(int(i32(binary.big_endian_u32(data)))) }
		700 { new_real_value(math.f32_from_bits(binary.big_endian_u32(data))) }
		701 { new_double_precision_value(math.f64_from_bits(binary.big_endian_u64(data))) }
		else { sqlstate_0a000('binary format of parameter type ${oid} is not supported') }
	}
}

// parameter_types are the type of each parameter: the type the client gave in
// the Parse message, otherwise the type from where it's used, or text if it
// doesn't have one.
fn (s PGStatement) parameter_types() []int {
	mut oids := s.parameter_oids.clone()
	if stmt := s.stmt {
		for oids.len < stmt.dynamic_parameter_count() {
			oids << 0
		}
		for i, oid in oids {
			if oid == 0 {
				oids[i] = if typ := stmt.dynamic_parameter_type(i + 1) {
					pg_type_of(typ.typ).oid
				} else {
					25
				}
			}
		}
	}

	return oids
}

// columns are the columns of the result of the statement, or none if it doesn't
// return rows.
fn (s PGStatement) columns(params map[string]Value) ![]Column {
	if stmt := s.stmt {
		mut prepared := stmt
		return prepared.columns(params)
	}

	return []Column{}
}

// execute_portal sends the result of a portal, executing it the first time. If
// max_rows isn't 0, only up to that many rows are sent, then a PortalSuspended
// if there are more.
fn (s &Server) execute_portal(mut db Connection, mut conn PGConn, mut portal PGPortal, max_rows int) ! {
	if portal.statement.kind == .empty {
		conn.write_empty_query_response()!
		return
	}

	if !portal.executed {
		portal.result = s.run_portal(mut db, mut conn, portal)!
		portal.executed = true
	}

	result := portal.result
	if result.msg != '' {
		conn.write_command_complete(pg_command_tag(result))!
		return
	}

	start := portal.next
	mut end := result.rows.len
	if max_rows > 0 && start + max_rows < end {
		end = start + max_rows
	}
	for portal.next < end {
		conn.write_data_row(result.columns, result.rows[portal.next], portal.formats)!
		portal.next++
	}

	if portal.next < result.rows.len {
		conn.write_empty_message(`s`)! // PortalSuspended
		return
	}

	conn.write_command_complete('SELECT ${end - start}')!
}

// run_portal executes the statement of a portal with its values.
fn (s &Server) run_portal(mut db Connection, mut conn PGConn, portal PGPortal) !Result {
	if stmt := portal.statement.stmt {
		mut prepared := stmt
		s.log('execute: ${portal.statement.query}')
		db.clear_warnings()
		result := prepared.query(portal.params)!
		for warning in db.warnings {
			conn.write_notice(warning)!
		}
		s.log('response: ${result}')

		return pg_begin(portal.statement.query, result)
	}

	// An ignored SET is the only other statement that's executed.
	s.log('ignored: ${portal.statement.query}')

	return Result{
		msg: 'SET'
	}
}
