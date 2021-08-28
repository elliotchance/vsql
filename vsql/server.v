// server.v can be used to start a server that will listen for connections from
// PostgreSQL compatible clients. See pg.v.

module vsql

import net

struct Server {
	db_file string
	port    int
mut:
	db Connection
}

pub fn new_server(db_file string, port int) Server {
	return Server{db_file, port, Connection{}}
}

pub fn (mut s Server) start() ? {
	s.db = open(s.db_file) or { panic('cannot open database: $err') }

	// There are multiple compatibility changes we need to make during the
	// connection. A missing "FROM" clause is valid in PostgreSQL, but it's not
	// valid in the SQL standard so it's not supported by vsql. Make sure a
	// dummy table exists that we can use instead. Also see similar comment
	// below.
	//
	// TODO(elliotchance): Once supported, a VALUES() clause will be better.
	mut table_exists := false
	s.db.query('CREATE TABLE singlerow (x INT)') or { table_exists = true }

	if !table_exists {
		s.db.query('INSERT INTO singlerow (x) VALUES (0)') ?
	}

	// Also, we need to register some dummy functions commonly used in the
	// connection phase.
	register_pg_functions(mut s.db) ?
	register_pg_virtual_tables(mut s.db) ?

	mut listener := net.listen_tcp(.ip6, ':$s.port') or {
		return error('cannot listen on :$s.port: $err')
	}
	println('ready on 127.0.0.1:$s.port')

	mut client_id := 0
	for {
		client_id++

		mut conn := listener.accept() or {
			println(err)
			continue
		}

		s.handle_conn(mut conn) ?
	}
}

fn (mut s Server) handle_conn(mut c net.TcpConn) ? {
	mut conn := new_pg_conn(c)

	conn.accept() ?
	println('connected')

	for {
		msg_type := conn.read_byte() ?
		match msg_type {
			`Q` /* Query */ {
				mut query := conn.read_query() ?

				// A missing "FROM" clause is valid in PostgreSQL, but it's not
				// valid in the SQL standard so it's not supported by vsql.
				//
				// TODO(elliotchance): Once supported, a VALUES() clause will be
				//  better.
				query_upper := query.to_upper()
				if query_upper.contains('SELECT') && !query_upper.contains('FROM') {
					query = query.trim('; ') + ' FROM singlerow;'
				}

				println('query: $query')

				mut did_error := false
				result := s.db.query(query) or {
					did_error = true
					println('error: $err')

					conn.write_error_result(err) ?
					new_result([]string{}, []Row{}) // not used
				}

				if !did_error {
					println('response: $result')
					conn.write_result(result) ?
				}

				conn.write_ready_for_query() ?
			}
			`X` /* Terminate */ {
				// Don't both consuming the message since we're going to
				// disconnect anyway.
				break
			}
			else {
				return error('unknown message: $msg_type.str()')
			}
		}
	}

	conn.close() ?
	println('disconnected')
}
