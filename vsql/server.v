// server.v can be used to start a server that will listen for connections from
// PostgreSQL compatible clients. See pg.v.

module vsql

import net

struct Server {
	options ServerOptions
mut:
	db &Connection
}

pub struct ServerOptions {
pub:
	db_file string
	port    int
	verbose bool
}

pub fn new_server(options ServerOptions) Server {
	// The server never actually runs in memory mode. I guess it could with a
	// server option, but for now we create a memory storage (that will be
	// replaced with file storage) to satisfy the V check.
	connection_options := default_connection_options()
	mut pager := new_memory_pager()
	btree := new_btree(pager, connection_options.page_size)
	catalog_name := catalog_name_from_path(options.db_file)

	catalog := &CatalogConnection{
		catalog_name: catalog_name
		storage:      new_storage(btree)
		options:      default_connection_options()
	}

	return Server{options, &Connection{
		now:      default_now
		catalogs: {
			catalog_name: catalog
		}
	}}
}

pub fn (mut s Server) start() ! {
	s.db = open(s.options.db_file) or { panic('cannot open database: ${err}') }

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
		s.db.query('INSERT INTO singlerow (x) VALUES (0)')!
	}

	// Also, we need to register some dummy functions commonly used in the
	// connection phase.
	register_pg_functions(mut s.db)!
	register_pg_virtual_tables(mut s.db)!

	mut listener := net.listen_tcp(.ip6, ':${s.options.port}') or {
		return error('cannot listen on :${s.options.port}: ${err}')
	}
	println('ready on 127.0.0.1:${s.options.port}')

	mut client_id := 0
	for {
		client_id++

		mut conn := listener.accept() or {
			s.log('${err}')
			continue
		}

		s.handle_conn(mut conn)!
	}
}

fn (mut s Server) log(message string) {
	if s.options.verbose {
		println(message)
	}
}

fn (mut s Server) handle_conn(mut c net.TcpConn) ! {
	mut conn := new_pg_conn(c)

	conn.accept()!
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
				if query_upper.contains('SELECT') && !query_upper.contains('FROM') {
					query = query.trim('; ') + ' FROM singlerow;'
				}

				s.log('query: ${query}')

				mut did_error := false
				result := s.db.query(query) or {
					did_error = true
					s.log('error: ${err}')

					conn.write_error_result(err)!
					new_result([]Column{}, []Row{}, 0, 0) // not used
				}

				if !did_error {
					s.log('response: ${result}')
					conn.write_result(result)!
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

	conn.close()!
	s.log('disconnected')
}
