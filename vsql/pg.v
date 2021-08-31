// pg.v contains the PostgreSQL protocol and some compatability functions that
// are used when PostgreSQL clients are connecting.

module vsql

import encoding.binary
import net

// PGConn is a PostgreSQL connection that can send and receive messages over
// TCP.
struct PGConn {
mut:
	conn net.TcpConn
}

fn new_pg_conn(conn net.TcpConn) &PGConn {
	return &PGConn{conn}
}

fn (mut c PGConn) accept() ? {
	// The startup message consumes the basic credentials, but we don't check
	// any of that. Let the client know the auth is fine and we're ready for
	// queries.
	c.read_startup_message() ?
	c.write_authentication_ok() ?
	c.write_ready_for_query() ?
}

fn (mut c PGConn) write_result(result Result) ? {
	if result.rows.len > 0 {
		c.write_row_description(result) ?
		for row in result {
			c.write_data_row(result.columns, row) ?
		}
	}

	c.write_command_complete(result) ?
}

fn (mut c PGConn) write_error_result(err IError) ? {
	c.write_byte(`E`) ?

	mut msg_len := 4 // self
	msg_len += 1 + 'ERROR'.len + 1 // NULL // S
	msg_len += 1 + err.msg.len + 1 // NULL // M
	msg_len += 1 + 5 + 1 // NULL // C
	msg_len += 1 // NULL
	c.write_int32(msg_len) ?

	c.write_byte(`S`) ?
	c.write_string('ERROR') ?

	c.write_byte(`M`) ?
	c.write_string(err.msg) ?

	// TODO(elliotchance): Use the correct SQL state.
	c.write_byte(`C`) ?
	c.write_string('42601') ?

	c.write_byte(0) ?
}

fn (mut c PGConn) write_command_complete(result Result) ? {
	c.write_byte(`C`) ?

	// TODO(elliotchance): This is a hack that will probably cause issues.
	mut tag := 'SELECT $result.rows.len'
	if result.columns == ['msg'] && result.rows.len == 1 {
		tag = result.rows[0].get_string('msg') or { '$err' }
	}

	mut msg_len := 4 // self
	msg_len += tag.len + 1 // NULL
	c.write_int32(msg_len) ?
	c.write_string(tag) ?
}

fn (mut c PGConn) read_byte() ?byte {
	mut bytes := []byte{len: 1}
	c.conn.read(mut bytes) ?

	return bytes[0]
}

fn (mut c PGConn) read_startup_message() ? {
	msg_len := c.read_int32() ?

	// We read the version, but we don't enforce it. Let's hope the client is
	// using a client that know how to talk to PostgreSQL 7.4+. Use "<< 16" to
	// get the significant part of the version.
	version := c.read_int32() ?

	// This is a magic number for SSLRequest message type (instead of a
	// StartupMessage).
	if version == 80877103 {
		// The server then responds with a single byte containing S or N,
		// indicating that it is willing or unwilling to perform SSL,
		// respectively.
		c.write_byte(`N`) ?

		// It will then expect a StartupMessage.
		c.read_startup_message() ?
		return
	}

	// Read all the key/value pairs, such as user, database, etc. A zero byte is
	// required after the last pair (hence the - 1).
	mut n := 8
	for n < msg_len - 1 {
		_, n1 := c.read_string() ? // name
		_, n2 := c.read_string() ? // value
		n += n1 + n2
	}

	if c.read_byte() ? != 0 {
		return error('missing terminating zero byte')
	}
}

fn (mut c PGConn) read_query() ?string {
	// Read the length, but ignore since we're reading a NULL terminated string.
	c.read_int32() ?
	query, _ := c.read_string() ?

	return query
}

fn (mut c PGConn) write_byte(b byte) ? {
	c.conn.write([b]) ?
}

fn (mut c PGConn) write_bytes(b []byte) ? {
	c.conn.write(b) ?
}

fn (mut c PGConn) write_row_description(result Result) ? {
	c.write_byte(`T`) ?

	mut msg_len := 4 // self
	msg_len += 2 // cols
	for column in result.columns {
		msg_len += column.len + 1 // NULL
		msg_len += 18 // all the other fields
	}

	c.write_int32(msg_len) ?
	c.write_int16(i16(result.columns.len)) ?

	for column in result.columns {
		c.write_string(column) ?
		c.write_int32(0) ?
		c.write_int16(0) ?
		c.write_int32(0) ? // object ID of type
		c.write_int16(0) ?
		c.write_int32(0) ?
		c.write_int16(0) ? // 0 = text
	}
}

fn (mut c PGConn) write_data_row(columns []string, row Row) ? {
	c.write_byte(`D`) ?

	mut msg_len := 4 // self
	msg_len += 2 // cols
	for column in columns {
		v := row.get_string(column) or { '$err' }
		msg_len += 4 + v.len
	}

	c.write_int32(msg_len) ?
	c.write_int16(i16(columns.len)) ?

	for column in columns {
		v := row.get_string(column) or { '$err' }
		c.write_int32(v.len) ?
		c.write_bytes(v.bytes()) ?
	}
}

fn (mut c PGConn) write_authentication_ok() ? {
	c.write_byte(`R`) ?
	c.write_int32(8) ?
	c.write_int32(0) ?
}

fn (mut c PGConn) write_ready_for_query() ? {
	c.write_byte(`Z`) ?
	c.write_int32(5) ?
	c.write_byte(`I`) ?
}

fn (mut c PGConn) read_int32() ?int {
	mut bytes := []byte{len: 4}
	c.conn.read(mut bytes) ?

	return int(binary.big_endian_u32(bytes))
}

fn (mut c PGConn) write_int16(x i16) ? {
	mut bytes := []byte{len: 2}
	binary.big_endian_put_u16(mut bytes, u16(x))
	c.conn.write(bytes) ?
}

fn (mut c PGConn) write_int32(x int) ? {
	mut bytes := []byte{len: 4}
	binary.big_endian_put_u32(mut bytes, u32(x))
	c.conn.write(bytes) ?
}

fn (mut c PGConn) read_string() ?(string, int) {
	mut bytes := []byte{len: 1}
	mut read := 0
	mut s := ''
	for {
		c.conn.read(mut bytes) ?
		read++
		if bytes[0] == 0 {
			break
		}
		s += bytes.bytestr()
	}

	return s, read
}

fn (mut c PGConn) write_string(s string) ? {
	c.write_bytes(s.bytes()) ?
	c.write_byte(0) ?
}

fn (mut c PGConn) close() ? {
	c.conn.close() ?
}

fn register_pg_functions(mut db Connection) ? {
	db.register_function('version() varchar', pg_version) ?
	db.register_function('current_setting(varchar) varchar', pg_current_setting) ?
}

fn pg_version(a []Value) ?Value {
	// TODO(elliotchance): Is it worth returning a better value here?
	return new_varchar_value('PostgreSQL 9.3.10 on x86_64-unknown-linux-gnu, compiled by gcc (Ubuntu 4.8.2-19ubuntu1) 4.8.2, 64-bit',
		0)
}

fn pg_current_setting(a []Value) ?Value {
	return new_varchar_value('90310', 0)
}

fn register_pg_virtual_tables(mut db Connection) ? {
	db.register_virtual_table('CREATE TABLE pg_database ( datname VARCHAR(255) )', fn (mut t VirtualTable) ? {
		t.next_values([
			new_varchar_value('vsql', 0), // datname
		])

		t.done()
	}) ?
}
