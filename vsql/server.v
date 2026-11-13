// server.v can be used to start a server that will listen for connections from
// PostgreSQL compatible clients. See pg.v.

module vsql

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

	for !s.stopping {
		mut conn := s.accept() or {
			s.log('${err}')
			continue
		}
		if s.stopping {
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
	s.stopping = true
	serving := s.serving
	s.mutex.unlock()

	if !serving {
		s.listener.close()!
		return
	}

	// Connecting wakes up serve, which closes the listener. It can't connect if
	// serve has already seen that it's stopping and closed it.
	if mut wake := net.dial_tcp(address.replace('0.0.0.0:', '127.0.0.1:').replace('[::]:', '[::1]:')) {
		wake.close()!
	}
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

	s.handle_conn(mut db, mut conn) or { s.log('error: ${err}') }

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

fn (s &Server) handle_conn(mut db Connection, mut conn PGConn) ! {
	// We need to register some dummy functions commonly used in the connection
	// phase.
	register_pg_functions(mut db)!
	register_pg_virtual_tables(mut db)!

	if s.options.select_without_from {
		db.query('CREATE TABLE singlerow (x INT)') or {}
		if db.query('SELECT * FROM singlerow')!.rows.len == 0 {
			db.query('INSERT INTO singlerow (x) VALUES (0)')!
		}
	}

	conn.write_ready()!
	s.log('connected')

	for {
		msg_type := conn.read_byte()!
		match msg_type {
			`Q` { // Query
				mut query := conn.read_query()!

				// Only the reply of the server is different. The standard has no
				// empty statement, so it's still an error for Connection.query.
				if is_empty_query(query) {
					s.log('query: ${query}')
					conn.write_empty_query_response()!
					conn.write_ready_for_query()!
					continue
				}

				if s.options.ignore_pg_set && is_pg_set(query) {
					s.log('ignored: ${query}')
					conn.write_command_complete('SET')!
					conn.write_ready_for_query()!
					continue
				}

				if s.options.rewrite_pg_syntax {
					query = rewrite_pg_syntax(query)
				}

				// A missing "FROM" clause is valid in PostgreSQL, but it's not
				// valid in the SQL standard so it's not supported by vsql.
				query_upper := query.to_upper()
				if s.options.select_without_from && query_upper.contains('SELECT')
					&& !query_upper.contains('FROM') {
					query = query.trim('; ') + ' FROM singlerow;'
				}

				s.log('query: ${query}')

				db.clear_warnings()
				if result := db.query(query) {
					for warning in db.warnings {
						conn.write_notice(warning)!
					}

					s.log('response: ${result}')
					conn.write_result(result)!
				} else {
					s.log('error: ${err}')
					conn.write_error_result(err)!
				}

				conn.write_ready_for_query()!
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
