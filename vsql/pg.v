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
	for name, value in pg_parameters {
		c.write_parameter_status(name, value)!
	}
	c.write_backend_key_data()!
	c.write_ready_for_query()!
}

// pg_parameters are the run-time parameters that a PostgreSQL server reports
// when a client connects. Some clients (such as JDBC, used by DBeaver) need
// them. server_version is the same version as version().
const pg_parameters = {
	'server_version':              '9.3.10'
	'server_encoding':             'UTF8'
	'client_encoding':             'UTF8'
	'DateStyle':                   'ISO, MDY'
	'TimeZone':                    'UTC'
	'integer_datetimes':           'on'
	'standard_conforming_strings': 'on'
	'is_superuser':                'on'
	'session_authorization':       'vsql'
}

fn (mut c PGConn) write_parameter_status(name string, value string) ! {
	c.write_byte(`S`)!
	c.write_int32(4 + name.len + 1 + value.len + 1)!
	c.write_string(name)!
	c.write_string(value)!
}

// write_backend_key_data sends the key that a client would use to cancel a
// query. Cancelling isn't supported, so the key is always zero.
fn (mut c PGConn) write_backend_key_data() ! {
	c.write_byte(`K`)!
	c.write_int32(12)!
	c.write_int32(0)!
	c.write_int32(0)!
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

	for i, name in names {
		typ := result.columns[i].typ
		pg_type := pg_type_of(typ.typ)
		c.write_string(name)!
		c.write_int32(0)! // table
		c.write_int16(0)! // column
		c.write_int32(pg_type.oid)!
		c.write_int16(i16(pg_type.len))!
		c.write_int32(pg_typmod(typ))!
		c.write_int16(0)! // 0 = text
	}
}

fn (mut c PGConn) write_data_row(columns Columns, row Row) ! {
	mut values := []?string{}
	mut msg_len := 4 // self
	msg_len += 2 // cols
	for column in columns {
		v := pg_text(row.get_column(column) or { new_varchar_value(err.msg()) })
		msg_len += 4
		if text := v {
			msg_len += text.len
		}
		values << v
	}

	c.write_byte(`D`)!
	c.write_int32(msg_len)!
	c.write_int16(i16(columns.len))!
	for v in values {
		if text := v {
			c.write_int32(text.len)!
			c.write_bytes(text.bytes())!
		} else {
			c.write_int32(-1)!
		}
	}
}

// pg_text is the text of a value that's sent to a client: none for NULL, and
// "t" or "f" for a BOOLEAN, like PostgreSQL. JDBC only reads "t" as TRUE.
fn pg_text(v Value) ?string {
	if v.is_null {
		return none
	}
	if v.typ.typ == .is_boolean {
		return if v.bool_value() == .is_true { 't' } else { 'f' }
	}

	return v.str()
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
fn register_pg_functions(mut db Connection, database string) ! {
	// current_database() is the database that the client connected with.
	datname := pg_database_name(database)
	mut functions := pg_functions.clone()
	functions['current_database() varchar'] = PGFunction{fn [datname] (_ FunctionContext, _ []Value) !Value {
		return new_varchar_value(datname)
	}, vsql_pg_current_database}
	for prototype, func in functions {
		db.register_flagged_function(prototype, func.func, [func.feature]) or {
			if err !is SQLState42723 {
				return err
			}
		}
	}
}

// pg_database_name is the name of the only database (see pg_database): the one
// that the client connected with, which is ignored (see Server.connect).
fn pg_database_name(database string) string {
	return if database == '' { 'vsql' } else { database }
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
	'version() varchar':                                                             PGFunction{pg_version, vsql_pg_version}
	'current_setting(setting_name varchar) varchar':                                 PGFunction{pg_current_setting, vsql_pg_current_setting}
	'pg_get_userbyid(role_oid integer) varchar':                                     PGFunction{pg_get_userbyid, vsql_pg_get_userbyid}
	'obj_description(object integer, catalog_name varchar) varchar':                 PGFunction{pg_obj_description, vsql_pg_obj_description}
	'pg_total_relation_size(relation integer) bigint':                               PGFunction{pg_size, vsql_pg_total_relation_size}
	'pg_table_size(relation integer) bigint':                                        PGFunction{pg_size, vsql_pg_table_size}
	'pg_indexes_size(relation integer) bigint':                                      PGFunction{pg_size, vsql_pg_indexes_size}
	'pg_get_function_identity_arguments(func_oid integer) varchar':                  PGFunction{pg_get_function_identity_arguments, vsql_pg_get_function_identity_arguments}
	'pg_database_size(database_oid integer) bigint':                                 PGFunction{pg_size, vsql_pg_database_size}
	'format_type(type_oid integer, typemod integer) varchar':                        PGFunction{pg_format_type_func, vsql_pg_format_type}
	'pg_get_expr(expr varchar, relation integer) varchar':                           PGFunction{pg_get_expr, vsql_pg_get_expr}
	'pg_get_expr(expr varchar, relation integer, pretty boolean) varchar':           PGFunction{pg_get_expr, vsql_pg_get_expr}
	'pg_tablespace_location(tablespace_oid integer) varchar':                        PGFunction{pg_empty_string, vsql_pg_tablespace_location}
	'pg_encoding_to_char(encoding integer) varchar':                                 PGFunction{pg_encoding_to_char, vsql_pg_encoding_to_char}
	'pg_relation_size(relation integer) bigint':                                     PGFunction{pg_size, vsql_pg_relation_size}
	'pg_stat_get_numscans(relation integer) bigint':                                 PGFunction{pg_size, vsql_pg_stat_get_numscans}
	'pg_get_indexdef(index_oid integer, column_no integer, pretty boolean) varchar': PGFunction{pg_empty_string, vsql_pg_get_indexdef}
	'pg_get_constraintdef(constraint_oid integer) varchar':                          PGFunction{pg_empty_string, vsql_pg_get_constraintdef}
	'pg_get_constraintdef(constraint_oid integer, pretty boolean) varchar':          PGFunction{pg_empty_string, vsql_pg_get_constraintdef}
	'pg_get_ruledef(rule_oid integer) varchar':                                      PGFunction{pg_empty_string, vsql_pg_get_ruledef}
	'shobj_description(object integer, catalog_name varchar) varchar':               PGFunction{pg_obj_description, vsql_shobj_description}
}

fn pg_format_type_func(_ FunctionContext, args []Value) !Value {
	if args[0].is_null {
		return new_null_value(.is_varchar)
	}
	typmod := if args[1].is_null { -1 } else { int(args[1].as_int()) }

	return new_varchar_value(pg_format_type(int(args[0].as_int()), typmod))
}

// pg_get_expr returns the expression (see pg_attrdef) as it is.
fn pg_get_expr(_ FunctionContext, args []Value) !Value {
	return args[0]
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
fn register_pg_virtual_tables(mut db Connection, database string) ! {
	datname := pg_database_name(database)

	// The rest are the parts of PostgreSQL's system catalog that clients read
	// to list the schemas and tables. Each object has an oid from its position
	// (see pg_oids), so the tables can be joined.
	c := db.catalog()
	pg_tables := {
		'CREATE TABLE pg_database (oid INTEGER, datname VARCHAR(255), datdba INTEGER, encoding INTEGER, datcollate VARCHAR(255), datctype VARCHAR(255), datistemplate BOOLEAN, datallowconn BOOLEAN, datconnlimit INTEGER, datlastsysoid INTEGER, datfrozenxid INTEGER, datminmxid INTEGER, dattablespace INTEGER, datacl VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                 fn [datname] (mut t VirtualTable) ! {
			t.next_values([new_integer_value(pg_database_oid), new_varchar_value(datname),
				new_integer_value(pg_user_oid), new_integer_value(pg_utf8_encoding),
				new_varchar_value('C'), new_varchar_value('C'), new_boolean_value(false),
				new_boolean_value(true), new_integer_value(-1), new_integer_value(pg_last_system_oid),
				new_integer_value(0), new_integer_value(0),
				new_integer_value(pg_default_tablespace_oid), new_null_value(.is_varchar)])
			t.done()
		}
		'CREATE TABLE pg_namespace (oid INTEGER, nspname VARCHAR(255), nspowner INTEGER, nspacl VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           fn [c] (mut t VirtualTable) ! {
			// The built-in types (pg_type) are in pg_catalog.
			t.next_values([new_integer_value(pg_catalog_namespace_oid),
				new_varchar_value('pg_catalog'), new_integer_value(pg_user_oid),
				new_null_value(.is_varchar)])
			namespaces, _ := pg_oids(c)
			for name, oid in namespaces {
				t.next_values([new_integer_value(oid), new_varchar_value(name),
					new_integer_value(pg_user_oid), new_null_value(.is_varchar)])
			}
			t.done()
		}
		// relkind is 'r' for a table, or 'v' for a view (of the
		// INFORMATION_SCHEMA). The number of rows isn't known (-1).
		'CREATE TABLE pg_class (oid INTEGER, relname VARCHAR(255), relnamespace INTEGER, relkind VARCHAR(1), relowner INTEGER, reltuples BIGINT, reltype INTEGER, reloftype INTEGER, relam INTEGER, relfilenode INTEGER, reltablespace INTEGER, relpages INTEGER, relallvisible INTEGER, reltoastrelid INTEGER, relhasindex BOOLEAN, relisshared BOOLEAN, relpersistence VARCHAR(1), relnatts INTEGER, relchecks INTEGER, relhasoids BOOLEAN, relhaspkey BOOLEAN, relhasrules BOOLEAN, relhastriggers BOOLEAN, relhassubclass BOOLEAN, relrowsecurity BOOLEAN, relforcerowsecurity BOOLEAN, relispopulated BOOLEAN, relreplident VARCHAR(1), relispartition BOOLEAN, relfrozenxid INTEGER, relminmxid INTEGER, relacl VARCHAR(255), reloptions VARCHAR(255), relpartbound VARCHAR(255))': fn [c] (mut t VirtualTable) ! {
			namespaces, tables := pg_oids(c)
			for table in c.information_schema_tables() {
				t.next_values([new_integer_value(tables[table.name.storage_id()]),
					new_varchar_value(table.name.entity_name),
					new_integer_value(namespaces[table.name.schema_name]),
					new_varchar_value(if table.is_virtual { 'v' } else { 'r' }),
					new_integer_value(pg_user_oid), new_bigint_value(-1), new_integer_value(0),
					new_integer_value(0), new_integer_value(0), new_integer_value(0),
					new_integer_value(0), new_integer_value(0), new_integer_value(0),
					new_integer_value(0), new_boolean_value(table.primary_key.len > 0),
					new_boolean_value(false), new_varchar_value('p'),
					new_integer_value(table.columns.len),
					new_integer_value(table.check_constraints.len), new_boolean_value(false),
					new_boolean_value(table.primary_key.len > 0), new_boolean_value(false),
					new_boolean_value(false), new_boolean_value(false), new_boolean_value(false),
					new_boolean_value(false), new_boolean_value(true), new_varchar_value('d'),
					new_boolean_value(false), new_integer_value(0), new_integer_value(0),
					new_null_value(.is_varchar), new_null_value(.is_varchar),
					new_null_value(.is_varchar)])
			}
			t.done()
		}
		// The columns of each table, numbered from 1.
		'CREATE TABLE pg_attribute (attrelid INTEGER, attname VARCHAR(255), atttypid INTEGER, attstattarget INTEGER, attlen INTEGER, attnum INTEGER, attndims INTEGER, attcacheoff INTEGER, atttypmod INTEGER, attbyval BOOLEAN, attstorage VARCHAR(1), attalign VARCHAR(1), attnotnull BOOLEAN, atthasdef BOOLEAN, attidentity VARCHAR(1), attgenerated VARCHAR(1), attisdropped BOOLEAN, attislocal BOOLEAN, attinhcount INTEGER, attcollation INTEGER, attacl VARCHAR(255), attoptions VARCHAR(255), attfdwoptions VARCHAR(255))':                                                                                                                                                                                                                                                     fn [c] (mut t VirtualTable) ! {
			_, tables := pg_oids(c)
			for table in c.information_schema_tables() {
				for i, column in table.columns {
					pg_type := pg_type_of(column.typ.typ)
					t.next_values([new_integer_value(tables[table.name.storage_id()]),
						new_varchar_value(column.name.sub_entity_name), new_integer_value(pg_type.oid),
						new_integer_value(-1), new_integer_value(pg_type.len),
						new_integer_value(i + 1), new_integer_value(0), new_integer_value(-1),
						new_integer_value(pg_typmod(column.typ)),
						new_boolean_value(pg_type.len > 0 && pg_type.len <= 8), new_varchar_value('p'),
						new_varchar_value('i'),
						new_boolean_value(is_known_not_nullable(table, column)),
						new_boolean_value(column.default_value != none),
						new_varchar_value(if column.identity != none { 'd' } else { '' }),
						new_varchar_value(''), new_boolean_value(false), new_boolean_value(true),
						new_integer_value(0), new_integer_value(0), new_null_value(.is_varchar),
						new_null_value(.is_varchar), new_null_value(.is_varchar)])
				}
			}
			t.done()
		}
		// The defaults of the columns. pg_get_expr returns adbin as it is.
		'CREATE TABLE pg_attrdef (oid INTEGER, adrelid INTEGER, adnum INTEGER, adbin VARCHAR(4000), adsrc VARCHAR(4000))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                fn [c] (mut t VirtualTable) ! {
			_, tables := pg_oids(c)
			for table in c.information_schema_tables() {
				for i, column in table.columns {
					if column.default_value != none {
						t.next_values([new_integer_value(0),
							new_integer_value(tables[table.name.storage_id()]),
							new_integer_value(i + 1), new_varchar_value(column.default_text),
							new_varchar_value(column.default_text)])
					}
				}
			}
			t.done()
		}
		// The tables (but not the views) of each schema.
		'CREATE TABLE pg_statio_user_tables (relid INTEGER, schemaname VARCHAR(255), relname VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              fn [c] (mut t VirtualTable) ! {
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
		// The built-in types that columns can have (see pg_type_of). There are
		// no user-defined types.
		'CREATE TABLE pg_type (oid INTEGER, typname VARCHAR(255), typnamespace INTEGER, typowner INTEGER, typlen INTEGER, typbyval BOOLEAN, typtype VARCHAR(1), typcategory VARCHAR(1), typispreferred BOOLEAN, typisdefined BOOLEAN, typdelim VARCHAR(1), typrelid INTEGER, typelem INTEGER, typarray INTEGER, typinput VARCHAR(255), typoutput VARCHAR(255), typreceive VARCHAR(255), typsend VARCHAR(255), typmodin VARCHAR(255), typmodout VARCHAR(255), typanalyze VARCHAR(255), typalign VARCHAR(1), typstorage VARCHAR(1), typnotnull BOOLEAN, typbasetype INTEGER, typtypmod INTEGER, typndims INTEGER, typcollation INTEGER, typdefaultbin VARCHAR(255), typdefault VARCHAR(255), typacl VARCHAR(255))':                                                                         fn (mut t VirtualTable) ! {
			for typ in pg_types {
				t.next_values([new_integer_value(typ.oid), new_varchar_value(typ.name),
					new_integer_value(pg_catalog_namespace_oid), new_integer_value(pg_user_oid),
					new_integer_value(typ.len), new_boolean_value(typ.len > 0 && typ.len <= 8),
					new_varchar_value('b'), new_varchar_value(typ.category), new_boolean_value(false),
					new_boolean_value(true), new_varchar_value(','), new_integer_value(0),
					new_integer_value(0), new_integer_value(0), new_varchar_value('${typ.name}in'),
					new_varchar_value('${typ.name}out'), new_varchar_value('${typ.name}recv'),
					new_varchar_value('${typ.name}send'), new_varchar_value('-'),
					new_varchar_value('-'), new_varchar_value('-'), new_varchar_value('i'),
					new_varchar_value('p'), new_boolean_value(false), new_integer_value(0),
					new_integer_value(-1), new_integer_value(0), new_integer_value(0),
					new_null_value(.is_varchar), new_null_value(.is_varchar),
					new_null_value(.is_varchar)])
			}
			t.done()
		}
		// The only user (see pg_get_userbyid).
		'CREATE TABLE pg_roles (oid INTEGER, rolname VARCHAR(255), rolsuper BOOLEAN, rolinherit BOOLEAN, rolcreaterole BOOLEAN, rolcreatedb BOOLEAN, rolcanlogin BOOLEAN, rolreplication BOOLEAN, rolconnlimit INTEGER, rolpassword VARCHAR(255), rolvaliduntil VARCHAR(255), rolbypassrls BOOLEAN, rolconfig VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                             fn (mut t VirtualTable) ! {
			t.next_values([new_integer_value(pg_user_oid), new_varchar_value('vsql'),
				new_boolean_value(true), new_boolean_value(true), new_boolean_value(true),
				new_boolean_value(true), new_boolean_value(true), new_boolean_value(false),
				new_integer_value(-1), new_varchar_value('********'), new_null_value(.is_varchar),
				new_boolean_value(true), new_null_value(.is_varchar)])
			t.done()
		}
		'CREATE TABLE pg_tablespace (oid INTEGER, spcname VARCHAR(255), spcowner INTEGER, spcacl VARCHAR(255), spcoptions VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 fn (mut t VirtualTable) ! {
			t.next_values([new_integer_value(pg_default_tablespace_oid),
				new_varchar_value('pg_default'), new_integer_value(pg_user_oid),
				new_null_value(.is_varchar), new_null_value(.is_varchar)])
			t.done()
		}
		// The run-time parameters, see pg_parameters.
		'CREATE TABLE pg_settings (name VARCHAR(255), setting VARCHAR(255), unit VARCHAR(255), category VARCHAR(255), short_desc VARCHAR(255), vartype VARCHAR(255), source VARCHAR(255), boot_val VARCHAR(255), reset_val VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                fn (mut t VirtualTable) ! {
			mut settings := pg_parameters.clone()
			settings['search_path'] = 'PUBLIC'
			for name, value in settings {
				t.next_values([new_varchar_value(name), new_varchar_value(value),
					new_null_value(.is_varchar), new_varchar_value(''), new_varchar_value(''),
					new_varchar_value('string'), new_varchar_value('default'),
					new_varchar_value(value), new_varchar_value(value)])
			}
			t.done()
		}
		// There are no comments (pg_description and pg_shdescription),
		// dependencies (pg_depend), enums (pg_enum) or functions (pg_proc) to
		// describe. A classoid is the name of the table, like the regclass that
		// it's compared with (see pg_type_name).
		'CREATE TABLE pg_description (objoid INTEGER, classoid VARCHAR(255), objsubid INTEGER, description VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                pg_empty_table
		'CREATE TABLE pg_shdescription (objoid INTEGER, classoid VARCHAR(255), description VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                pg_empty_table
		'CREATE TABLE pg_depend (classid INTEGER, objid INTEGER, objsubid INTEGER, refclassid INTEGER, refobjid INTEGER, refobjsubid INTEGER, deptype VARCHAR(1))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       pg_empty_table
		'CREATE TABLE pg_enum (enumtypid INTEGER, enumlabel VARCHAR(255), enumsortorder DOUBLE PRECISION)':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               pg_empty_table
		// The only encoding (UTF8), collation (the default), index access
		// method (btree) and the built-in languages.
		'CREATE TABLE pg_conversion (oid INTEGER, conname VARCHAR(255), connamespace INTEGER, conowner INTEGER, conforencoding INTEGER, contoencoding INTEGER, conproc VARCHAR(255), condefault BOOLEAN)':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                fn (mut t VirtualTable) ! {
			t.next_values([new_integer_value(12000), new_varchar_value('utf8'),
				new_integer_value(pg_catalog_namespace_oid), new_integer_value(pg_user_oid),
				new_integer_value(pg_utf8_encoding), new_integer_value(pg_utf8_encoding),
				new_varchar_value('-'), new_boolean_value(true)])
			t.done()
		}
		'CREATE TABLE pg_collation (oid INTEGER, collname VARCHAR(255), collnamespace INTEGER, collowner INTEGER, collprovider VARCHAR(1), collencoding INTEGER, collcollate VARCHAR(255), collctype VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      fn (mut t VirtualTable) ! {
			t.next_values([new_integer_value(100), new_varchar_value('default'),
				new_integer_value(pg_catalog_namespace_oid), new_integer_value(pg_user_oid),
				new_varchar_value('d'), new_integer_value(-1), new_varchar_value(''),
				new_varchar_value('')])
			t.done()
		}
		'CREATE TABLE pg_am (oid INTEGER, amname VARCHAR(255), amhandler VARCHAR(255), amtype VARCHAR(1))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               fn (mut t VirtualTable) ! {
			t.next_values([new_integer_value(403), new_varchar_value('btree'),
				new_varchar_value('bthandler'), new_varchar_value('i')])
			t.done()
		}
		'CREATE TABLE pg_language (oid INTEGER, lanname VARCHAR(255), lanowner INTEGER, lanispl BOOLEAN, lanpltrusted BOOLEAN, lanplcallfoid INTEGER, laninline INTEGER, lanvalidator INTEGER, lanacl VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     fn (mut t VirtualTable) ! {
			for i, name in ['internal', 'c', 'sql'] {
				t.next_values([new_integer_value(12 + i), new_varchar_value(name),
					new_integer_value(pg_user_oid), new_boolean_value(false),
					new_boolean_value(name == 'sql'), new_integer_value(0), new_integer_value(0),
					new_integer_value(0), new_null_value(.is_varchar)])
			}
			t.done()
		}
		'CREATE TABLE pg_proc (oid INTEGER, proname VARCHAR(255), pronamespace INTEGER, proowner INTEGER, proisagg BOOLEAN, proiswindow BOOLEAN, prorettype VARCHAR(255), prolang INTEGER, proargdefaults VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 pg_empty_table
		'CREATE TABLE pg_inherits (inhrelid INTEGER, inhparent INTEGER, inhseqno INTEGER)':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               pg_empty_table
		'CREATE TABLE pg_constraint (oid INTEGER, conname VARCHAR(255), connamespace INTEGER, contype VARCHAR(1), condeferrable BOOLEAN, condeferred BOOLEAN, convalidated BOOLEAN, conrelid INTEGER, contypid INTEGER, conindid INTEGER, confrelid INTEGER, confupdtype VARCHAR(1), confdeltype VARCHAR(1), confmatchtype VARCHAR(1), conislocal BOOLEAN, coninhcount INTEGER, connoinherit BOOLEAN, conkey VARCHAR(255), confkey VARCHAR(255), conbin VARCHAR(255), consrc VARCHAR(255))':                                                                                                                                                                                                                                                                                              pg_empty_table
		'CREATE TABLE pg_index (indexrelid INTEGER, indrelid INTEGER, indnatts INTEGER, indisunique BOOLEAN, indisprimary BOOLEAN, indisexclusion BOOLEAN, indimmediate BOOLEAN, indisclustered BOOLEAN, indisvalid BOOLEAN, indcheckxmin BOOLEAN, indisready BOOLEAN, indislive BOOLEAN, indisreplident BOOLEAN, indkey VARCHAR(255), indcollation VARCHAR(255), indclass VARCHAR(255), indoption VARCHAR(255), indexprs VARCHAR(255), indpred VARCHAR(255))':                                                                                                                                                                                                                                                                                                                           pg_empty_table
		'CREATE TABLE pg_trigger (oid INTEGER, tgrelid INTEGER, tgname VARCHAR(255), tgfoid INTEGER, tgtype INTEGER, tgenabled VARCHAR(1), tgisinternal BOOLEAN, tgconstrrelid INTEGER, tgconstrindid INTEGER, tgconstraint INTEGER, tgdeferrable BOOLEAN, tginitdeferred BOOLEAN, tgnargs INTEGER, tgattr VARCHAR(255), tgargs VARCHAR(255), tgqual VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                      pg_empty_table
		'CREATE TABLE pg_rewrite (oid INTEGER, rulename VARCHAR(255), ev_class INTEGER, ev_type VARCHAR(1), ev_enabled VARCHAR(1), is_instead BOOLEAN, ev_qual VARCHAR(255), ev_action VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    pg_empty_table
		'CREATE TABLE pg_aggregate (aggfnoid INTEGER, aggkind VARCHAR(1), aggnumdirectargs INTEGER, aggtransfn VARCHAR(255), aggfinalfn VARCHAR(255), aggsortop INTEGER, aggtranstype INTEGER, agginitval VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 pg_empty_table
		'CREATE TABLE pg_default_acl (oid INTEGER, defaclrole INTEGER, defaclnamespace INTEGER, defaclobjtype VARCHAR(1), defaclacl VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       pg_empty_table
		'CREATE TABLE pg_extension (oid INTEGER, extname VARCHAR(255), extowner INTEGER, extnamespace INTEGER, extrelocatable BOOLEAN, extversion VARCHAR(255), extconfig VARCHAR(255), extcondition VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      pg_empty_table
		'CREATE TABLE pg_available_extensions (name VARCHAR(255), default_version VARCHAR(255), installed_version VARCHAR(255), comment VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   pg_empty_table
		'CREATE TABLE pg_event_trigger (oid INTEGER, evtname VARCHAR(255), evtevent VARCHAR(255), evtowner INTEGER, evtfoid INTEGER, evtenabled VARCHAR(1), evttags VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       pg_empty_table
		'CREATE TABLE pg_foreign_data_wrapper (oid INTEGER, fdwname VARCHAR(255), fdwowner INTEGER, fdwhandler INTEGER, fdwvalidator INTEGER, fdwacl VARCHAR(255), fdwoptions VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             pg_empty_table
		'CREATE TABLE pg_foreign_server (oid INTEGER, srvname VARCHAR(255), srvowner INTEGER, srvfdw INTEGER, srvtype VARCHAR(255), srvversion VARCHAR(255), srvacl VARCHAR(255), srvoptions VARCHAR(255))':                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              pg_empty_table
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

const pg_database_oid = 13000
const pg_last_system_oid = 13000
const pg_catalog_namespace_oid = 11
const pg_default_tablespace_oid = 1663
const pg_utf8_encoding = 6

// PGType is a built-in type of pg_type.
struct PGType {
	oid      int
	name     string
	len      int
	category string
}

const pg_types = [
	PGType{16, 'bool', 1, 'B'},
	PGType{20, 'int8', 8, 'N'},
	PGType{21, 'int2', 2, 'N'},
	PGType{23, 'int4', 4, 'N'},
	PGType{25, 'text', -1, 'S'},
	PGType{700, 'float4', 4, 'N'},
	PGType{701, 'float8', 8, 'N'},
	PGType{1042, 'bpchar', -1, 'S'},
	PGType{1043, 'varchar', -1, 'S'},
	PGType{1082, 'date', 4, 'D'},
	PGType{1083, 'time', 8, 'D'},
	PGType{1114, 'timestamp', 8, 'D'},
	PGType{1184, 'timestamptz', 8, 'D'},
	PGType{1266, 'timetz', 12, 'D'},
	PGType{1700, 'numeric', -1, 'N'},
]

// pg_type_of is the PostgreSQL type of an SQL type. A type that PostgreSQL
// doesn't have (or that's sent differently) is text.
fn pg_type_of(t SQLType) PGType {
	oid := match t {
		.is_boolean { 16 }
		.is_bigint { 20 }
		.is_smallint { 21 }
		.is_integer { 23 }
		.is_real { 700 }
		.is_double_precision { 701 }
		.is_character { 1042 }
		.is_varchar { 1043 }
		.is_date { 1082 }
		.is_time_without_time_zone { 1083 }
		.is_timestamp_without_time_zone { 1114 }
		.is_timestamp_with_time_zone { 1184 }
		.is_time_with_time_zone { 1266 }
		.is_decimal, .is_numeric { 1700 }
		else { 25 }
	}

	// Every oid above is in pg_types.
	return pg_types.filter(it.oid == oid)[0]
}

// pg_typmod is the type modifier of a column: the length of a character string
// or the precision and scale of a number (each plus 4), otherwise -1.
fn pg_typmod(t Type) int {
	return match t.typ {
		.is_character, .is_varchar {
			if t.size > 0 { t.size + 4 } else { -1 }
		}
		.is_decimal, .is_numeric {
			if t.size > 0 { ((t.size << 16) | int(t.scale)) + 4 } else { -1 }
		}
		else { -1 }
	}
}

// pg_format_type is format_type(): the SQL name of a type of pg_type, with the
// type modifier.
fn pg_format_type(oid int, typmod int) string {
	name := match oid {
		16 { 'boolean' }
		20 { 'bigint' }
		21 { 'smallint' }
		23 { 'integer' }
		25 { 'text' }
		700 { 'real' }
		701 { 'double precision' }
		1042 { 'character' }
		1043 { 'character varying' }
		1082 { 'date' }
		1083 { 'time without time zone' }
		1114 { 'timestamp without time zone' }
		1184 { 'timestamp with time zone' }
		1266 { 'time with time zone' }
		1700 { 'numeric' }
		else { '???' }
	}
	if typmod < 4 {
		return name
	}
	if oid == 1700 {
		return '${name}(${(typmod - 4) >> 16},${(typmod - 4) & 0xffff})'
	}

	return '${name}(${typmod - 4})'
}

// pg_table_features are the features of the tables of register_pg_virtual_tables
// other than pg_database, by name.
const pg_table_features = {
	'pg_database':             vsql_pg_database
	'pg_namespace':            vsql_pg_namespace
	'pg_attribute':            vsql_pg_attribute
	'pg_attrdef':              vsql_pg_attrdef
	'pg_roles':                vsql_pg_roles
	'pg_tablespace':           vsql_pg_tablespace
	'pg_settings':             vsql_pg_settings
	'pg_description':          vsql_pg_description
	'pg_shdescription':        vsql_pg_shdescription
	'pg_depend':               vsql_pg_depend
	'pg_conversion':           vsql_pg_conversion
	'pg_collation':            vsql_pg_collation
	'pg_am':                   vsql_pg_am
	'pg_language':             vsql_pg_language
	'pg_inherits':             vsql_pg_inherits
	'pg_constraint':           vsql_pg_constraint
	'pg_index':                vsql_pg_index
	'pg_trigger':              vsql_pg_trigger
	'pg_rewrite':              vsql_pg_rewrite
	'pg_aggregate':            vsql_pg_aggregate
	'pg_default_acl':          vsql_pg_default_acl
	'pg_extension':            vsql_pg_extension
	'pg_available_extensions': vsql_pg_available_extensions
	'pg_event_trigger':        vsql_pg_event_trigger
	'pg_foreign_data_wrapper': vsql_pg_foreign_data_wrapper
	'pg_foreign_server':       vsql_pg_foreign_server
	'pg_class':                vsql_pg_class
	'pg_statio_user_tables':   vsql_pg_statio_user_tables
	'pg_type':                 vsql_pg_type
	'pg_enum':                 vsql_pg_enum
	'pg_proc':                 vsql_pg_proc
}

// pg_user_oid is the oid of the only user, see pg_get_userbyid.
const pg_user_oid = 10

// pg_oids returns the oids of the schemas (by name) and of the tables (by
// storage_id) for the PostgreSQL system catalog. The schemas come first, then
// the tables, in the order of information_schema_tables, starting at 16384 like
// the objects that a PostgreSQL user creates.
fn pg_oids(c &CatalogConnection) (map[string]int, map[string]int) {
	mut names := c.storage.schemas.keys()
	// A file from before the VSQL schema could already have a schema with
	// that name.
	for name in system_schema_names {
		if name !in names {
			names << name
		}
	}
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

fn pg_empty_string(_ FunctionContext, _ []Value) !Value {
	return new_varchar_value('')
}

fn pg_encoding_to_char(_ FunctionContext, _ []Value) !Value {
	return new_varchar_value('UTF8')
}
