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
	// out holds the messages that haven't been sent yet. They're sent together
	// by flush(), rather than with a write for every field.
	out []u8
	// in holds what has been received but not read yet, so that reading each
	// field doesn't need its own read from the connection.
	in []u8
	// lower_case_names sends column names in lower case, see
	// ServerOptions.lower_case_names.
	lower_case_names bool
}

fn new_pg_conn(conn net.TcpConn) &PGConn {
	return &PGConn{
		conn: conn
	}
}

// flush sends the messages that have been written.
fn (mut c PGConn) flush() ! {
	c.conn.write(c.out) or { return error('cannot write to tcp connection: ${err}') }
	c.out = []u8{}
}

// accept reads the startup message and returns the database name the client
// connected with (which may be empty). The client must then be sent
// write_ready().
fn (mut c PGConn) accept() !string {
	// The startup message also has the basic credentials, but we don't check
	// any of that.
	return c.read_startup_message()
}

// write_ready lets the client know the auth is fine and we're ready for
// queries.
fn (mut c PGConn) write_ready() ! {
	c.write_authentication_ok()!
	c.write_ready_for_query()!
}

fn (mut c PGConn) write_result(result Result) ! {
	// A statement (such as CREATE TABLE) only sends its command tag. A query
	// always describes its columns, even when there are no rows.
	if result.msg == '' {
		c.write_row_description(result)!
		// Iterating the Result itself (rather than its rows) generates invalid C
		// with the V3 compiler.
		for row in result.rows {
			c.write_data_row(result.columns, row)!
		}
	}

	c.write_command_complete(pg_command_tag(result))!
}

fn (mut c PGConn) write_error_result(err IError) ! {
	c.write_error_or_notice(`E`, 'ERROR', err)!
}

// write_notice sends a warning, such as when a CAST truncates a string. A
// completion condition that isn't a warning (02000 no data) is a NOTICE.
fn (mut c PGConn) write_notice(warning IError) ! {
	severity := if warning is SQLState02000 { 'NOTICE' } else { 'WARNING' }
	c.write_error_or_notice(`N`, severity, warning)!
}

// write_error_or_notice sends an ErrorResponse (E) or NoticeResponse (N), which
// have the same fields.
fn (mut c PGConn) write_error_or_notice(msg_type u8, severity string, err IError) ! {
	c.write_byte(msg_type)!

	// Errors that aren't a SQLState (code 0) are reported as internal_error.
	sqlstate := if err.code() == 0 { 'XX000' } else { sqlstate_from_int(err.code()) }

	mut msg_len := 4 // self
	msg_len += 1 + severity.len + 1 // NULL // S
	msg_len += 1 + err.msg().len + 1 // NULL // M
	msg_len += 1 + sqlstate.len + 1 // NULL // C
	msg_len += 1 // NULL
	c.write_int32(msg_len)!

	c.write_byte(`S`)!
	c.write_string(severity)!

	c.write_byte(`M`)!
	c.write_string(err.msg())!

	c.write_byte(`C`)!
	c.write_string(sqlstate)!

	c.write_byte(0)!
}

// pg_command_tag is the tag sent in CommandComplete. It's the same as the
// Result msg, except an INSERT tag also has an OID (always 0), like
// "INSERT 0 3". A query is "SELECT" and the number of rows.
fn pg_command_tag(result Result) string {
	if result.msg == '' {
		return 'SELECT ${result.rows.len}'
	}

	if result.msg.starts_with('INSERT ') {
		return 'INSERT 0 ${result.msg.all_after('INSERT ')}'
	}

	return result.msg
}

// write_empty_query_response replies to a query that has no statement, in place
// of a CommandComplete.
fn (mut c PGConn) write_empty_query_response() ! {
	c.write_byte(`I`)!
	c.write_int32(4)! // self
}

fn (mut c PGConn) write_command_complete(tag string) ! {
	c.write_byte(`C`)!

	mut msg_len := 4 // self
	msg_len += tag.len + 1 // NULL
	c.write_int32(msg_len)!
	c.write_string(tag)!
}

fn (mut c PGConn) read_byte() !u8 {
	return c.read_bytes(1)![0]
}

// read_bytes returns the next n bytes, waiting for them if they haven't been
// received yet.
fn (mut c PGConn) read_bytes(n int) ![]u8 {
	for c.in.len < n {
		mut buf := []u8{len: 4096}
		read := c.conn.read(mut buf)!
		if read == 0 {
			return error('connection closed')
		}
		c.in << buf[..read]
	}

	bytes := c.in[..n].clone()
	c.in = c.in[n..].clone()

	return bytes
}

fn (mut c PGConn) read_startup_message() !string {
	msg_len := c.read_int32()!

	// We read the version, but we don't enforce it. Let's hope the client is
	// using a client that know how to talk to PostgreSQL 7.4+. Use "<< 16" to
	// get the significant part of the version.
	version := c.read_int32()!

	// This is a magic number for SSLRequest message type (instead of a
	// StartupMessage).
	if version == 80877103 {
		// The server then responds with a single byte containing S or N,
		// indicating that it is willing or unwilling to perform SSL,
		// respectively.
		c.write_byte(`N`)!
		c.flush()!

		// It will then expect a StartupMessage.
		return c.read_startup_message()
	}

	// Read all the key/value pairs, such as user, database, etc. A zero byte is
	// required after the last pair (hence the - 1).
	mut database := ''
	mut n := 8
	for n < msg_len - 1 {
		name, n1 := c.read_string()!
		value, n2 := c.read_string()!
		if name == 'database' {
			database = value
		}
		n += n1 + n2
	}

	if c.read_byte()! != 0 {
		return error('missing terminating zero byte')
	}

	return database
}

fn (mut c PGConn) read_query() !string {
	// Read the length, but ignore since we're reading a NULL terminated string.
	c.read_int32()!
	query, _ := c.read_string()!

	return query
}

fn (mut c PGConn) write_byte(b u8) ! {
	c.out << b
}

fn (mut c PGConn) write_bytes(b []u8) ! {
	c.out << b
}

fn (mut c PGConn) write_row_description(result Result) ! {
	c.write_byte(`T`)!

	mut msg_len := 4 // self
	msg_len += 2 // cols
	mut names := []string{}
	for column in result.columns {
		mut name := column.name.sub_entity_name
		if c.lower_case_names && name == name.to_upper() {
			name = name.to_lower()
		}
		names << name
		msg_len += name.len + 1 // NULL
		msg_len += 18 // all the other fields
	}

	c.write_int32(msg_len)!
	c.write_int16(i16(result.columns.len))!

	for name in names {
		c.write_string(name)!
		c.write_int32(0)!
		c.write_int16(0)!
		c.write_int32(0)! // object ID of type
		c.write_int16(0)!
		c.write_int32(0)!
		c.write_int16(0)! // 0 = text
	}
}

fn (mut c PGConn) write_data_row(columns Columns, row Row) ! {
	c.write_byte(`D`)!

	mut msg_len := 4 // self
	msg_len += 2 // cols
	for column in columns {
		v := (row.get_column(column) or { new_varchar_value(err.msg()) }).str()
		msg_len += 4 + v.len
	}

	c.write_int32(msg_len)!
	c.write_int16(i16(columns.len))!

	for column in columns {
		v := (row.get_column(column) or { new_varchar_value(err.msg()) }).str()
		c.write_int32(v.len)!
		c.write_bytes(v.bytes())!
	}
}

fn (mut c PGConn) write_authentication_ok() ! {
	c.write_byte(`R`)!
	c.write_int32(8)!
	c.write_int32(0)!
}

// write_ready_for_query ends the response, so the messages are sent.
fn (mut c PGConn) write_ready_for_query() ! {
	c.write_byte(`Z`)!
	c.write_int32(5)!
	c.write_byte(`I`)!
	c.flush()!
}

fn (mut c PGConn) read_int32() !int {
	return int(binary.big_endian_u32(c.read_bytes(4)!))
}

fn (mut c PGConn) write_int16(x i16) ! {
	mut bytes := []u8{len: 2}
	binary.big_endian_put_u16(mut bytes, u16(x))
	c.out << bytes
}

fn (mut c PGConn) write_int32(x int) ! {
	mut bytes := []u8{len: 4}
	binary.big_endian_put_u32(mut bytes, u32(x))
	c.out << bytes
}

// read_string reads a string that ends with a zero byte. The number of bytes
// read includes the zero byte.
fn (mut c PGConn) read_string() !(string, int) {
	mut bytes := []u8{}
	for {
		b := c.read_byte()!
		if b == 0 {
			break
		}
		bytes << b
	}

	return bytes.bytestr(), bytes.len + 1
}

fn (mut c PGConn) write_string(s string) ! {
	c.write_bytes(s.bytes())!
	c.write_byte(0)!
}

fn (mut c PGConn) close() ! {
	c.conn.close() or { return error('cannot close connection: ${err}') }
}

// register_pg_functions registers the functions that PostgreSQL clients use,
// unless the connection already has them (such as from ServerOptions.connect).
// They're only registered for the clients of the server (and the SQL tests
// with the "postgresql" directive), and are flagged as PostgreSQL functions
// (see pg_functions).
fn register_pg_functions(mut db Connection) ! {
	for prototype, func in pg_functions {
		db.register_flagged_function(prototype, func.func, [func.feature]) or {
			if err !is SQLState42723 {
				return err
			}
		}
	}
}

struct PGFunction {
	func    fn (FunctionContext, []Value) !Value @[required]
	feature string
}

// pg_functions are the PostgreSQL functions, by prototype. Every object is
// owned by the only user (see pg_get_userbyid), there are no comments, the
// sizes aren't known, and pg_proc is empty, so there are no arguments to
// describe.
const pg_functions = {
	'version() varchar':                                   PGFunction{pg_version, vsql_pg_version}
	'current_setting(varchar) varchar':                    PGFunction{pg_current_setting, vsql_pg_current_setting}
	'pg_get_userbyid(integer) varchar':                    PGFunction{pg_get_userbyid, vsql_pg_get_userbyid}
	'obj_description(integer, varchar) varchar':           PGFunction{pg_obj_description, vsql_pg_obj_description}
	'pg_total_relation_size(integer) bigint':              PGFunction{pg_size, vsql_pg_total_relation_size}
	'pg_table_size(integer) bigint':                       PGFunction{pg_size, vsql_pg_table_size}
	'pg_indexes_size(integer) bigint':                     PGFunction{pg_size, vsql_pg_indexes_size}
	'pg_get_function_identity_arguments(integer) varchar': PGFunction{pg_get_function_identity_arguments, vsql_pg_get_function_identity_arguments}
}

fn pg_obj_description(_ FunctionContext, _ []Value) !Value {
	return new_null_value(.is_varchar)
}

fn pg_size(_ FunctionContext, _ []Value) !Value {
	return new_null_value(.is_bigint)
}

fn pg_get_userbyid(_ FunctionContext, _ []Value) !Value {
	return new_varchar_value('vsql')
}

fn pg_get_function_identity_arguments(_ FunctionContext, _ []Value) !Value {
	return new_varchar_value('')
}

fn pg_version(_ FunctionContext, _ []Value) !Value {
	return new_varchar_value('PostgreSQL 9.3.10 on x86_64-unknown-linux-gnu, compiled by gcc (Ubuntu 4.8.2-19ubuntu1) 4.8.2, 64-bit')
}

fn pg_current_setting(_ FunctionContext, _ []Value) !Value {
	return new_varchar_value('90310')
}

// register_pg_virtual_tables registers the tables that PostgreSQL clients
// read, unless the connection already has a table with the same name. Like
// register_pg_functions, they're only registered for PostgreSQL clients, and
// each is flagged (see pg_table_features).
fn register_pg_virtual_tables(mut db Connection) ! {
	db.register_flagged_virtual_table('CREATE TABLE pg_database ( datname VARCHAR(255) )', fn (mut t VirtualTable) ! {
		t.next_values([
			new_varchar_value('vsql'), // datname
		])

		t.done()
	}, [vsql_pg_database]) or {
		if err !is SQLState42P07 {
			return err
		}
	}

	// The rest are the parts of PostgreSQL's system catalog that clients read
	// to list the schemas and tables. Each object has an oid from its position
	// (see pg_oids), so the tables can be joined.
	c := db.catalog()
	pg_tables := {
		'CREATE TABLE pg_namespace (oid INTEGER, nspname VARCHAR(255), nspowner INTEGER)':                                                                                  fn [c] (mut t VirtualTable) ! {
			namespaces, _ := pg_oids(c)
			for name, oid in namespaces {
				t.next_values([new_integer_value(oid), new_varchar_value(name),
					new_integer_value(pg_user_oid)])
			}
			t.done()
		}
		// relkind is 'r' for a table, or 'v' for a view (of the
		// INFORMATION_SCHEMA). The number of rows isn't known (-1).
		'CREATE TABLE pg_class (oid INTEGER, relname VARCHAR(255), relnamespace INTEGER, relkind VARCHAR(1), relowner INTEGER, reltuples BIGINT)':                          fn [c] (mut t VirtualTable) ! {
			namespaces, tables := pg_oids(c)
			for table in c.information_schema_tables() {
				t.next_values([new_integer_value(tables[table.name.storage_id()]),
					new_varchar_value(table.name.entity_name),
					new_integer_value(namespaces[table.name.schema_name]),
					new_varchar_value(if table.is_virtual { 'v' } else { 'r' }),
					new_integer_value(pg_user_oid), new_bigint_value(-1)])
			}
			t.done()
		}
		// The tables (but not the views) of each schema.
		'CREATE TABLE pg_statio_user_tables (relid INTEGER, schemaname VARCHAR(255), relname VARCHAR(255))':                                                                fn [c] (mut t VirtualTable) ! {
			_, tables := pg_oids(c)
			for table in c.information_schema_tables() {
				if !table.is_virtual {
					t.next_values([new_integer_value(tables[table.name.storage_id()]),
						new_varchar_value(table.name.schema_name),
						new_varchar_value(table.name.entity_name)])
				}
			}
			t.done()
		}
		// There are no user-defined types (pg_type), enums (pg_enum) or
		// functions (pg_proc) to describe.
		'CREATE TABLE pg_type (oid INTEGER, typname VARCHAR(255), typnamespace INTEGER)':                                                                                   pg_empty_table
		'CREATE TABLE pg_enum (enumtypid INTEGER, enumlabel VARCHAR(255), enumsortorder DOUBLE PRECISION)':                                                                 pg_empty_table
		'CREATE TABLE pg_proc (oid INTEGER, proname VARCHAR(255), pronamespace INTEGER, proowner INTEGER, proisagg BOOLEAN, proiswindow BOOLEAN, prorettype VARCHAR(255))': pg_empty_table
	}
	for create_table, data in pg_tables {
		name := create_table.all_after('CREATE TABLE ').all_before(' ')
		db.register_flagged_virtual_table(create_table, data, [
			pg_table_features[name],
		]) or {
			if err !is SQLState42P07 {
				return err
			}
		}
	}
}

// pg_table_features are the features of the tables of register_pg_virtual_tables
// other than pg_database, by name.
const pg_table_features = {
	'pg_namespace':          vsql_pg_namespace
	'pg_class':              vsql_pg_class
	'pg_statio_user_tables': vsql_pg_statio_user_tables
	'pg_type':               vsql_pg_type
	'pg_enum':               vsql_pg_enum
	'pg_proc':               vsql_pg_proc
}

// pg_user_oid is the oid of the only user, see pg_get_userbyid.
const pg_user_oid = 10

// pg_oids returns the oids of the schemas (by name) and of the tables (by
// storage_id) for the PostgreSQL system catalog. The schemas come first, then
// the tables, in the order of information_schema_tables, starting at 16384 like
// the objects that a PostgreSQL user creates.
fn pg_oids(c &CatalogConnection) (map[string]int, map[string]int) {
	mut names := c.storage.schemas.keys()
	names << information_schema_name
	names.sort()

	mut oid := 16384
	mut namespaces := map[string]int{}
	for name in names {
		namespaces[name] = oid
		oid++
	}
	mut tables := map[string]int{}
	for table in c.information_schema_tables() {
		tables[table.name.storage_id()] = oid
		oid++
	}

	return namespaces, tables
}

fn pg_empty_table(mut t VirtualTable) ! {
	t.done()
}
