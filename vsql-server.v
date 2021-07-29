module main

import encoding.binary
import net
import os
import vsql

// State is to get around the V limitation of:
// error: function in `go` statement cannot contain mutable non-reference arguments
struct State {
mut:
	db   vsql.Connection
	conn net.TcpConn
}

fn main() {
	if os.args.len < 2 {
		println('error: usage: vsql-server myfile.vsql')
		return
	}

	mut db := vsql.open(os.args[1]) or { panic('cannot open database: $err') }

	port := 3210
	mut listener := net.listen_tcp(.ip6, ':$port') or { panic(err) }
	println('ready on 127.0.0.1:$port')

	mut client_id := 1
	for {
		mut conn := listener.accept() or { panic(err) }
		state := State{db, conn}
		go handle_conn(client_id, state)
		client_id++
	}
}

fn log(client_id int, msg string) {
	println('$client_id: $msg')
}

fn handle_conn(client_id int, state State) {
	mut conn := state.conn
	mut db := state.db

	// The startup message consumes the basic credentials, but we don't check
	// any of that. Let the client know the auth is fine and we're ready for
	// queries.
	read_startup_message(mut conn)
	write_authentication_ok(mut conn)
	write_ready_for_query(mut conn)
	log(client_id, 'connected')

	for {
		msg_type := read_byte(mut conn)
		match msg_type {
			`Q` /* Query */ {
				mut query := read_query(client_id, mut conn)

				// For compatability with clients that use PostgreSQL-specific
				// queries like:
				//   SELECT version();
				//   SELECT oid, typname FROM pg_type;
				// We secretly return a dummy response so that we can survive to
				// the real vsql queries.
				if query.contains('version()') || query.contains('pg_') {
					query = 'SELECT 1'
				}

				mut did_error := false
				result := db.query(query) or {
					did_error = true
					write_error_result(client_id, mut conn, err)
					vsql.new_result([]string{}, []vsql.Row{}) // not used
				}

				if !did_error {
					write_result(client_id, mut conn, result)
				}

				write_ready_for_query(mut conn)
			}
			`X` /* Terminate */ {
				// Don't both consuming the message since we're going to
				// disconnect anyway.
				break
			}
			else {
				panic('unknown message: $[msg_type].str()')
			}
		}
	}

	log(client_id, 'disconnected')
	conn.close() or { panic(err) }
}

fn write_result(client_id int, mut conn net.TcpConn, result vsql.Result) {
	if result.rows.len > 0 {
		write_row_description(mut conn, result)
		for row in result {
			write_data_row(mut conn, result.columns, row)
		}
	}
	write_command_complete(client_id, mut conn, result)
}

fn write_error_result(client_id int, mut conn net.TcpConn, err IError) {
	log(client_id, 'error: $err.msg')

	write_byte(mut conn, `E`)

	mut msg_len := 4 // self
	msg_len += 1 + 'ERROR'.len + 1 // NULL // S
	msg_len += 1 + err.msg.len + 1 // NULL // M
	msg_len += 1 + 5 + 1 // NULL // C
	msg_len += 1 // NULL
	write_int32(mut conn, msg_len)

	write_byte(mut conn, `S`)
	write_string(mut conn, 'ERROR')

	write_byte(mut conn, `M`)
	write_string(mut conn, err.msg)

	// TODO(elliotchance): Use the correct SQL state.
	write_byte(mut conn, `C`)
	write_string(mut conn, '42601')

	write_byte(mut conn, 0)
}

fn write_command_complete(client_id int, mut conn net.TcpConn, result vsql.Result) {
	write_byte(mut conn, `C`)

	// TODO(elliotchance): This is a hack that will probably cause issues.
	mut tag := 'SELECT $result.rows.len'
	if result.columns == ['msg'] && result.rows.len == 1 {
		tag = result.rows[0].get_string('msg') or { '$err' }
	}

	mut msg_len := 4 // self
	msg_len += tag.len + 1 // NULL
	write_int32(mut conn, msg_len)
	write_string(mut conn, tag)
	log(client_id, 'response: $tag')
}

fn read_byte(mut conn net.TcpConn) byte {
	mut bytes := []byte{len: 1}
	conn.read(mut bytes) or { panic(err) }
	return bytes[0]
}

fn read_startup_message(mut conn net.TcpConn) {
	msg_len := read_int32(mut conn)

	// We read the version, but we don't enforce it. Let's hope the client is
	// using a client that know how to talk to PostgreSQL 7.4+. Use "<< 16" to
	// get the significant part of the version.
	read_int32(mut conn)

	// Read all the key/value pairs, such as user, database, etc. A zero byte is
	// required after the last pair (hence the - 1).
	mut n := 8
	for n < msg_len - 1 {
		_, n1 := read_string(mut conn) // name
		_, n2 := read_string(mut conn) // value
		n += n1 + n2
	}

	if read_byte(mut conn) != 0 {
		panic('missing terminating zero byte')
	}
}

fn read_query(client_id int, mut conn net.TcpConn) string {
	// Read the length, but ignore since we're reading a NULL terminated string.
	read_int32(mut conn)
	query, _ := read_string(mut conn)
	log(client_id, 'query: $query')

	return query
}

fn write_byte(mut conn net.TcpConn, b byte) {
	conn.write([b]) or { panic(err) }
}

fn write_bytes(mut conn net.TcpConn, b []byte) {
	conn.write(b) or { panic(err) }
}

fn write_row_description(mut conn net.TcpConn, result vsql.Result) {
	write_byte(mut conn, `T`)

	mut msg_len := 4 // self
	msg_len += 2 // cols
	for column in result.columns {
		msg_len += column.len + 1 // NULL
		msg_len += 18 // all the other fields
	}

	write_int32(mut conn, msg_len)
	write_int16(mut conn, i16(result.columns.len))

	for column in result.columns {
		write_string(mut conn, column)
		write_int32(mut conn, 0)
		write_int16(mut conn, 0)
		write_int32(mut conn, 0) // object ID of type
		write_int16(mut conn, 0)
		write_int32(mut conn, 0)
		write_int16(mut conn, 0) // 0 = text
	}
}

fn write_data_row(mut conn net.TcpConn, columns []string, row vsql.Row) {
	write_byte(mut conn, `D`)

	mut msg_len := 4 // self
	msg_len += 2 // cols
	for column in columns {
		v := row.get_string(column) or { '$err' }
		msg_len += 4 + v.len
	}

	write_int32(mut conn, msg_len)
	write_int16(mut conn, i16(columns.len))

	for column in columns {
		v := row.get_string(column) or { '$err' }
		write_int32(mut conn, v.len)
		write_bytes(mut conn, v.bytes())
	}
}

fn write_authentication_ok(mut conn net.TcpConn) {
	write_byte(mut conn, `R`)
	write_int32(mut conn, 8)
	write_int32(mut conn, 0)
}

fn write_ready_for_query(mut conn net.TcpConn) {
	write_byte(mut conn, `Z`)
	write_int32(mut conn, 5)
	write_byte(mut conn, `I`)
}

fn read_int32(mut conn net.TcpConn) int {
	mut bytes := []byte{len: 4}
	conn.read(mut bytes) or { panic(err) }
	return int(binary.big_endian_u32(bytes))
}

fn write_int16(mut conn net.TcpConn, x i16) {
	mut bytes := []byte{len: 2}
	binary.big_endian_put_u16(mut bytes, u16(x))
	conn.write(bytes) or { panic(err) }
}

fn write_int32(mut conn net.TcpConn, x int) {
	mut bytes := []byte{len: 4}
	binary.big_endian_put_u32(mut bytes, u32(x))
	conn.write(bytes) or { panic(err) }
}

fn read_string(mut conn net.TcpConn) (string, int) {
	mut bytes := []byte{len: 1}
	mut read := 0
	mut s := ''
	for {
		conn.read(mut bytes) or { panic(err) }
		read++
		if bytes[0] == 0 {
			break
		}
		s += bytes.bytestr()
	}
	return s, read
}

fn write_string(mut conn net.TcpConn, s string) {
	write_bytes(mut conn, s.bytes())
	write_byte(mut conn, 0)
}
