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
}

// Server accepts connections from PostgreSQL clients, see new_server.
@[heap]
pub struct Server {
	options ServerOptions
mut:
	connect  ConnectFn        = unsafe { nil }
	listener &net.TcpListener = unsafe { nil }
	stopping bool
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

	for {
		mut conn := s.accept() or {
			if s.stopping {
				return
			}
			s.log('${err}')
			continue
		}

		spawn s.handle_client(mut conn)
	}
}

// accept waits for the next client. A test can make it fail with the "accept"
// fault, which disconnects the client, see fault.v.
fn (mut s Server) accept() !&net.TcpConn {
	mut conn := s.listener.accept()!
	fault_point('accept') or {
		conn.close() or {}
		return err
	}

	return conn
}

// stop stops accepting new clients. Clients that are already connected are not
// disconnected.
pub fn (mut s Server) stop() ! {
	s.stopping = true
	if s.listener != unsafe { nil } {
		s.listener.close()!
	}
}

// handle_client runs in its own thread for each client. An error only
// disconnects that client.
fn (s &Server) handle_client(mut c net.TcpConn) {
	mut conn := new_pg_conn(c)
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

				// A missing "FROM" clause is valid in PostgreSQL, but it's not
				// valid in the SQL standard so it's not supported by vsql.
				//
				// TODO(elliotchance): Once supported, a VALUES() clause will be
				//  better.
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
