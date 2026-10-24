module vsql

import encoding.binary
import math
import net
import os
import regex
import strings
import time

struct SQLTest {
	setup       []string
	params      map[string]Value
	file_name   string
	line_number int
	stmts       []string
	expected    string
	show_types  bool
}

fn get_test_filter() (string, int) {
	env_test := $env('TEST')
	parts := env_test.split(':')

	if parts.len == 1 {
		return parts[0], 0
	}

	return parts[0], parts[1].int()
}

fn get_tests() ![]SQLTest {
	filter_test, filter_line := get_test_filter()

	mut tests := []SQLTest{}
	test_file_paths := os.walk_ext('tests', 'sql')
	for test_file_path in test_file_paths {
		// Skip any tests not in the explicit filter.
		if filter_test != '' && !test_file_path.contains(filter_test) {
			continue
		}

		lines := os.read_lines(test_file_path) or { []string{} }

		mut stmts := []string{}
		mut expected := []string{}
		mut setup := []string{}
		mut line_number := 0
		mut stmt := ''
		mut setup_stmt := ''
		mut in_setup := false
		mut params := map[string]Value{}
		mut show_types := false
		for line in lines {
			if line == '' {
				tests << SQLTest{setup, params, test_file_path, line_number, stmts, expected.join('\n'), show_types}
				stmts = []
				expected = []
				in_setup = false
				params = map[string]Value{}
				show_types = false
			} else if line.starts_with('/*') {
				contents := line[2..line.len - 2].trim_space()
				if contents == 'setup' {
					in_setup = true
				} else if contents.starts_with('connection ') {
					stmts << replace_unicode(contents)
				} else if contents.starts_with('fault ') || contents.starts_with('disconnect ') {
					stmts << replace_unicode(contents)
				} else if contents.starts_with('create_catalog ')
					|| contents.starts_with('virtual_table ') {
					stmts << replace_unicode(contents)
				} else if contents == 'out' || contents == 'in' {
					stmts << contents
				} else if contents.starts_with('clock ') {
					stmts << contents
				} else if contents.starts_with('types') {
					show_types = true
				} else if contents.starts_with('set ') {
					parts := contents.split(' ')
					if parts[2].starts_with("'") {
						params[parts[1]] = new_character_value(parts[2][1..parts[2].len - 1])
					} else if parts[2] == 'NULL' {
						typ := new_type(parts[3], 0, 0)
						params[parts[1]] = new_null_value(typ.typ)
					} else {
						params[parts[1]] = new_double_precision_value(parts[2].f64())
					}
				} else {
					panic('bad directive: "${contents}"')
				}
			} else if line.starts_with('-- #') {
				line_number++
				continue
			} else if line.starts_with('-- ') {
				expected << line[3..]
			} else {
				if in_setup {
					setup_stmt += '\n${line}'
					if line.ends_with(';') {
						setup << replace_unicode(setup_stmt)
						setup_stmt = ''
					}
				} else {
					stmt += '\n${line}'
					if line.ends_with(';') {
						stmts << replace_unicode(stmt)
						stmt = ''
					}
				}
			}

			line_number++
		}

		if stmts.len > 0 {
			tests << SQLTest{setup, params, test_file_path, line_number, stmts, expected.join('\n'), show_types}
		}
	}

	return tests
}

fn replace_unicode(s string) string {
	replace_func := fn (re regex.RE, unicode_point string, start int, end int) string {
		hex_chars := {
			`0`: 0
			`1`: 1
			`2`: 2
			`3`: 3
			`4`: 4
			`5`: 5
			`6`: 6
			`7`: 7
			`8`: 8
			`9`: 9
			`a`: 10
			`b`: 11
			`c`: 12
			`d`: 13
			`e`: 14
			`f`: 15
			`A`: 10
			`B`: 11
			`C`: 12
			`D`: 13
			`E`: 14
			`F`: 15
		}
		return rune(hex_chars[unicode_point[start + 3]] * 4096 + hex_chars[unicode_point[start +
			4]] * 256 + hex_chars[unicode_point[start + 5]] * 16 + hex_chars[unicode_point[start +
			6]]).str()
	}

	mut re := regex.regex_opt(r'<U\+[0-9A-Fa-f]{4}>') or { panic(err) }
	return re.replace_by_fn(s, replace_func)
}

enum SQLTestResult {
	passed
	failed
	skipped
}

// SQLTestMode is how a test is run. Every test runs in each mode it can, and
// only passes if it passes in all of them.
enum SQLTestMode {
	in_memory
	on_disk
}

fn (mode SQLTestMode) str() string {
	return match mode {
		.in_memory { 'in memory' }
		.on_disk { 'on disk' }
	}
}

// modes are the modes that a test can run in. A test that needs more than one
// connection doesn't run in memory, because connections can't share a database
// in memory. So does a test with a fault, because faults are in reading and
// writing the file.
fn (test SQLTest) modes() []SQLTestMode {
	mut modes := []SQLTestMode{}
	if $env('MEMORY') != '0'
		&& !test.stmts.any(it.starts_with('connection ') || it.starts_with('fault ')) {
		modes << .in_memory
	}
	if $env('FILE') != '0' {
		modes << .on_disk
	}

	return modes
}

// through_server is true if the statements of the test are sent to a Server
// from a PostgreSQL client over TCP (in each mode). One server is shared by all
// of the tests. The server can't run a test that uses something only the V
// library has, such as faults, host parameters or the type of each value, so
// those use a Connection directly.
fn (test SQLTest) through_server() bool {
	return $env('SERVER') != '0' && !test.show_types && test.params.len == 0
		&& !test.stmts.any(it.starts_with('fault ') || it.starts_with('disconnect ')
			|| it.starts_with('create_catalog ') || it.starts_with('virtual_table ')
			|| it == 'out' || it == 'in' || it.starts_with('clock '))
}

fn test_all() ! {
	filter_test, filter_line := get_test_filter()
	verbose := $env('VERBOSE')
	if $env('MEMORY') == '0' && $env('FILE') == '0' {
		return error('MEMORY=0 and FILE=0 leave nothing to test')
	}

	// One server is shared by all of the tests, see through_server.
	mut server := &Server(unsafe { nil })
	mut port := 0
	if $env('SERVER') != '0' {
		server = start_sql_test_server()!
		port = server.port()!
	}
	defer {
		if server != unsafe { nil } {
			server.stop() or {}
		}
	}

	// The V test summary does not include the failed assertions (only the
	// passing ones) so we keep our own count of the SQL tests.
	mut passed := 0
	mut failed := []string{}
	defer {
		os.rmdir_all(sql_test_dir()) or {}
	}
	for test in get_tests()! {
		modes := test.modes()
		if modes.len == 0 {
			continue
		}
		through_server := test.through_server()
		mut failed_modes := []string{}
		mut skipped := false
		for mode in modes {
			match run_single_test(test, verbose != '', filter_line, mode, through_server,
				port)! {
				.passed {}
				.failed { failed_modes << sql_test_mode_str(mode, through_server) }
				.skipped { skipped = true }
			}
		}

		if skipped {
			continue
		}
		if failed_modes.len > 0 {
			failed << '${test.file_name}:${test.line_number} (${failed_modes.join(', ')})'
		} else {
			passed++
		}
	}

	println('SQL tests: ${passed} passed, ${failed.len} failed, ${passed + failed.len} total')
	for location in failed {
		println('  FAILED ${location}')
	}
}

// sql_test_mode_str describes how a test was run, such as "on disk through
// server".
fn sql_test_mode_str(mode SQLTestMode, through_server bool) string {
	return if through_server { '${mode} through server' } else { mode.str() }
}

// sql_test_dir holds the database files of the tests that are running.
fn sql_test_dir() string {
	return os.join_path(os.temp_dir(), 'vsql-sql-test-${os.getpid()}')
}

// sql_test_options are the connection options for every test. Small pages make
// even small tests split pages and store large values across several pages.
fn sql_test_options() ConnectionOptions {
	mut options := default_connection_options()
	options.page_size = 256

	return options
}

// sql_test_now is the time for every test. 09:05:03 UTC is 14:05:03 local time
// at +05:00.
fn sql_test_now() (time.Time, i16) {
	return time.new(time.Time{
		year:       2022
		month:      7
		day:        4
		hour:       9
		minute:     5
		second:     3
		nanosecond: 120056000
	}), 300
}

// start_sql_test_server starts the server that is shared by all of the tests.
// Each client opens the database it connected with, which is a file, or
// ":memory:" for a new database in memory. This uses the public API to embed
// the server, like an application would.
fn start_sql_test_server() !&Server {
	options := sql_test_options()
	mut server := new_server(ServerOptions{
		connect: fn [options] (database string) !&Connection {
			mut db := open_database(database, options)!
			db.now = sql_test_now

			return db
		}
	})
	server.listen()!
	spawn fn (mut server Server) {
		server.serve() or { eprintln('server stopped: ${err}') }
	}(mut server)

	return server
}

@[assert_continues]
fn run_single_test(test SQLTest, verbose bool, filter_line int, mode SQLTestMode, through_server bool, port int) !SQLTestResult {
	if filter_line != 0 && test.line_number != filter_line {
		if verbose {
			println('SKIP ${test.file_name}:${test.line_number}\n')
		}

		return SQLTestResult.skipped
	}

	mode_str := sql_test_mode_str(mode, through_server)
	if verbose {
		println('BEGIN ${test.file_name}:${test.line_number} (${mode_str})')
		defer {
			println('END ${test.file_name}:${test.line_number} (${mode_str})\n')
		}
	}

	options := sql_test_options()

	// Connections are never closed (and so keep their locks), so each test
	// needs its own files. The main file is named so that its catalog is still
	// called ":memory:".
	dir := os.join_path(sql_test_dir(), test.file_name.replace('/', '_') + '_${test.line_number}')
	os.mkdir_all(dir)!
	defer {
		os.rmdir_all(dir) or {}
	}
	main_path := if mode == .on_disk { os.join_path(dir, ':memory:.vsql') } else { ':memory:' }
	file_name := os.join_path(dir, 'test.vsql')

	mut db := new_sql_test_conn(through_server, main_path, options, port)!
	mut opened := [db]
	defer {
		for mut conn in opened {
			conn.close()
		}
	}

	// If a test needs multiple connections we cannot rely on ":memory:".
	// The default connection is called "main". The docs explain that "main"
	// should not be referenced in tests and the "connection" directive must
	// be the first line in the test.
	mut connections := map[string]&SQLTestConn{}
	mut current_connection_name := ''

	for stmt in test.setup {
		if verbose {
			println('  ${stmt.trim_space()}')
		}

		output := db.run(stmt, test.params, false)!
		if output.error != '' {
			return error('setup failed: ${stmt}: ${output.error}')
		}
	}

	mut actual := ''
	mut last_dump := ?string(none)
	mut restores := 0
	defer {
		disarm_faults()
	}
	for stmt in test.stmts {
		// "fault <name>" fails the next time it's reached, "fault <name> <n>"
		// fails the nth time.
		if stmt.starts_with('fault ') {
			parts := stmt.split(' ')
			arm_fault(parts[1], if parts.len > 2 { parts[2].int() } else { 1 })!
			continue
		}

		// "disconnect <name>" closes a connection without rolling back its
		// transaction, like a process that stopped.
		if stmt.starts_with('disconnect ') {
			connection_name := stmt[11..]
			mut conn := connections[connection_name] or {
				panic('unknown connection: ${connection_name}')
			}
			conn.close()
			connections.delete(connection_name)
			continue
		}

		// "clock <offset>" sets the time zone of the current connection, such as
		// "-05:00" (the time is still sql_test_now). "clock real" uses the real
		// clock and time zone.
		if stmt.starts_with('clock ') {
			set_sql_test_clock(mut db.db, stmt[6..])
			continue
		}

		if stmt.starts_with('create_catalog ') {
			db.db.add_catalog(stmt[15..], ':memory:', options)!
			continue
		}

		// "virtual_table CREATE TABLE ... AS <query>" registers a virtual table
		// on the current connection, with the rows of the query.
		if stmt.starts_with('virtual_table ') {
			register_test_virtual_table(mut db.db, stmt[14..]) or {
				actual += 'error ${sqlstate_from_int(err.code())}: ${err.msg()}\n'
			}
			continue
		}

		// "out" dumps the database like "vsql out", and "in" replaces it with a
		// new database that the dump is loaded into, like "vsql in". Only the
		// errors from loading it are shown.
		if stmt == 'out' {
			if connections.len > 0 {
				return error('out cannot be used with connection')
			}
			mut sb := strings.new_builder(1024)
			db.db.dump(mut sb)!
			dumped := sb.str()
			last_dump = dumped
			for line in dumped.split_into_lines() {
				if line != '' {
					actual += 'out: ${line}\n'
				}
			}
			continue
		}

		if stmt == 'in' {
			if last_dump == none {
				return error('in needs an out before it')
			}
			restores++
			mut path := ':memory:'
			if mode == .on_disk {
				restored_dir := os.join_path(dir, 'in_${restores}')
				os.mkdir_all(restored_dir)!
				path = os.join_path(restored_dir, ':memory:.vsql')
			}
			db = new_sql_test_conn(false, path, options, port)!
			opened << db
			for dump_stmt in split_statements(last_dump) {
				db.db.query(dump_stmt) or {
					actual += 'error ${sqlstate_from_int(err.code())}: ${err.msg()}\n'
				}
			}
			continue
		}

		if stmt.starts_with('connection ') {
			connection_name := stmt[11..]
			if connection_name !in connections {
				// A connection that can't be opened (such as because of a fault)
				// is an error of the test, and the current connection stays the
				// same.
				conn := new_sql_test_conn(through_server, file_name, options, port) or {
					actual += '${connection_name}: error ${sqlstate_from_int(err.code())}: ${err.msg()}\n'
					continue
				}
				connections[connection_name] = conn
				opened << conn
			}

			db = connections[connection_name] or { panic('unknown connection: ${connection_name}') }
			current_connection_name = connection_name
			continue
		}

		if verbose {
			println('  ${stmt.trim_space()}')
		}

		prefix := if current_connection_name == '' { '' } else { '${current_connection_name}: ' }
		output := db.run(stmt, test.params, test.show_types)!
		if output.error != '' {
			actual += '${prefix}${output.error}\n'
			continue
		}

		for warning in output.warnings {
			actual += '${warning}\n'
		}

		if output.msg != '' {
			actual += '${prefix}msg: ${output.msg}\n'
		}

		for row in output.rows {
			actual += '${prefix}${row}\n'
		}
	}

	at := 'at ${test.file_name}:${test.line_number} (${mode_str}):\n'
	mut expected := at + test.expected.trim_space()
	actual_trim := at + actual.trim_space()

	assert expected == actual_trim

	return if expected == actual_trim { SQLTestResult.passed } else { SQLTestResult.failed }
}

// register_test_virtual_table registers a virtual table from a "virtual_table"
// directive, such as "CREATE TABLE t (x INT) AS VALUES 1, 2". The query is run
// once, and then each call of the provider function adds the next row, so that
// it's called once for each row (and once more to finish).
fn register_test_virtual_table(mut db Connection, directive string) ! {
	i := directive.index(') AS ') or { panic('bad virtual_table directive: ${directive}') }
	create_table := directive[..i + 1]
	result := db.query(directive[i + 5..])!

	mut rows := [][]Value{}
	for row in result {
		mut values := []Value{}
		for column in result.columns {
			values << row.get_column(column)!
		}
		rows << values
	}

	db.register_virtual_table(create_table, fn [rows] (mut t VirtualTable) ! {
		if t.rows.len < rows.len {
			t.next_values(rows[t.rows.len])
		} else {
			t.done()
		}
	})!
}

// set_sql_test_clock sets the clock of db for a "clock" directive.
fn set_sql_test_clock(mut db Connection, clock string) {
	if clock == 'real' {
		db.now = default_now
		return
	}

	sign := if clock.starts_with('-') { -1 } else { 1 }
	parts := clock[1..].split(':')
	offset := i16(sign * (parts[0].int() * 60 + parts[1].int()))
	db.now = fn [offset] () (time.Time, i16) {
		now, _ := sql_test_now()
		return now, offset
	}
}

// SQLTestOutput is what a statement returned, in the format of the expected
// output of a test.
struct SQLTestOutput {
mut:
	// error is set (and nothing else) if the statement failed.
	error    string
	warnings []string
	msg      string
	rows     []string
}

// SQLTestConn runs the statements of a test, either with a Connection (db) or
// through the server (client).
struct SQLTestConn {
mut:
	db     &Connection   = unsafe { nil }
	client &PGTestClient = unsafe { nil }
}

fn new_sql_test_conn(through_server bool, path string, options ConnectionOptions, port int) !&SQLTestConn {
	if through_server {
		return &SQLTestConn{
			client: new_pg_test_client(port, path)!
		}
	}

	mut db := open_database(path, options)!
	db.now = sql_test_now
	register_pg_functions(mut db) or {
		db.close()
		return err
	}

	// A file that failed while it was being created doesn't have the PUBLIC
	// schema for pg_database yet, see tests/faults.sql.
	register_pg_virtual_tables(mut db) or {
		if err !is SQLState3F000 {
			db.close()
			return err
		}
	}

	return &SQLTestConn{
		db: db
	}
}

fn (mut c SQLTestConn) close() {
	if c.client != unsafe { nil } {
		c.client.close()
	} else {
		c.db.close()
	}
}

fn (mut c SQLTestConn) run(stmt string, params map[string]Value, show_types bool) !SQLTestOutput {
	if c.client != unsafe { nil } {
		return c.client.query(stmt)
	}

	mut output := SQLTestOutput{}
	mut prepared := c.db.prepare(stmt) or {
		output.error = 'error ${sqlstate_from_int(err.code())}: ${err.msg()}'
		return output
	}
	c.db.clear_warnings()
	result := prepared.query(params) or {
		output.error = 'error ${sqlstate_from_int(err.code())}: ${err.msg()}'
		return output
	}

	for err in c.db.warnings {
		output.warnings << 'warning ${sqlstate_from_int(err.code())}: ${err.msg()}'
	}

	output.msg = result.msg

	for row in result {
		mut line := ''
		for col in result.columns {
			value := row.get_column(col)!
			check_sql_test_getters(row, col, value)!
			line += '${col.name.sub_entity_name}: ${value.str()} '
			if show_types {
				line += '(${value.typ}) '
			}
		}
		output.rows << line.trim_space()
	}

	return output
}

// check_sql_test_getters returns an error if the getters of a row (which an
// application would use) don't return the value of the column.
fn check_sql_test_getters(row Row, col Column, value Value) ! {
	name := if col.name.custom_id != '' { col.name.custom_id } else { col.name.sub_entity_name }
	if row.get_null(name)! != value.is_null || row.get_string(name)! != value.str() {
		return error('getters of ${name} are not ${value.str()}')
	}
	if value.typ.uses_int() && row.get_int(name)! != int(value.int_value()) {
		return error('get_int(${name}) is not ${value.str()}')
	}
	if value.typ.uses_f64() && !math.is_nan(value.f64_value())
		&& row.get_f64(name)! != value.f64_value() {
		return error('get_f64(${name}) is not ${value.str()}')
	}
	if value.typ.typ == .is_boolean && row.get_bool(name)! != value.bool_value() {
		return error('get_bool(${name}) is not ${value.str()}')
	}
}

// PGTestClient is a minimal PostgreSQL client for running the tests through the
// server. It only knows the simple query protocol.
struct PGTestClient {
mut:
	conn &net.TcpConn
}

fn new_pg_test_client(port int, database string) !&PGTestClient {
	mut client := &PGTestClient{net.dial_tcp('127.0.0.1:${port}')!}

	// StartupMessage: protocol 3.0, then name/value pairs.
	mut body := []u8{}
	body << pg_test_int32(196608)
	for s in ['user', 'vsql', 'database', database] {
		body << s.bytes()
		body << 0
	}
	body << 0
	mut startup := pg_test_int32(body.len + 4)
	startup << body
	client.conn.write(startup)!

	// AuthenticationOk, then ReadyForQuery. An error means the database couldn't
	// be opened.
	for {
		msg_type, msg := client.read_message()!
		match msg_type {
			`E` { return error(pg_test_fields(msg)['M']) }
			`Z` { break }
			else {}
		}
	}

	return client
}

fn (mut c PGTestClient) query(stmt string) !SQLTestOutput {
	mut query := [u8(`Q`)]
	query << pg_test_int32(stmt.len + 5)
	query << stmt.bytes()
	query << 0
	c.conn.write(query)!

	mut output := SQLTestOutput{}
	mut columns := []string{}
	for {
		msg_type, msg := c.read_message()!
		match msg_type {
			// RowDescription: the name of each column, followed by 18 bytes that
			// aren't needed.
			`T` {
				columns = []
				mut at := 2
				for _ in 0 .. pg_test_read_int16(msg, 0) {
					end := pg_test_string_end(msg, at)
					columns << msg[at..end].bytestr()
					at = end + 1 + 18
				}
			}
			// DataRow: the length and text of each value.
			`D` {
				mut line := ''
				mut at := 2
				for column in columns {
					len := pg_test_read_int32(msg, at)
					at += 4
					line += '${column}: ${msg[at..at + len].bytestr()} '
					at += len
				}
				output.rows << line.trim_space()
			}
			// CommandComplete: a query only has a tag for the number of rows. An
			// INSERT tag also has an OID, like "INSERT 0 3".
			`C` {
				tag := msg[..msg.len - 1].bytestr()
				if columns.len == 0 {
					output.msg = if tag.starts_with('INSERT 0 ') {
						'INSERT ${tag[9..]}'
					} else {
						tag
					}
				}
			}
			// The server sends XX000 (internal_error) for an error that isn't a
			// SQLSTATE, which the library reports as 00000.
			`E`, `N` {
				fields := pg_test_fields(msg)
				code := if fields['C'] == 'XX000' { '00000' } else { fields['C'] }
				if msg_type == `E` {
					output.error = 'error ${code}: ${fields['M']}'
				} else {
					output.warnings << 'warning ${code}: ${fields['M']}'
				}
			}
			`Z` {
				break
			}
			else {
				return error('unexpected message: ${msg_type.ascii_str()}')
			}
		}
	}

	return output
}

fn (mut c PGTestClient) close() {
	c.conn.write([u8(`X`), 0, 0, 0, 4]) or {}
	c.conn.close() or {}
}

// read_message returns the type and body of the next message.
fn (mut c PGTestClient) read_message() !(u8, []u8) {
	header := c.read_exactly(5)!
	body := c.read_exactly(pg_test_read_int32(header, 1) - 4)!

	return header[0], body
}

fn (mut c PGTestClient) read_exactly(n int) ![]u8 {
	mut buf := []u8{len: n}
	mut read := 0
	for read < n {
		read += c.conn.read(mut buf[read..])!
	}

	return buf
}

// pg_test_fields returns the fields of an ErrorResponse or NoticeResponse.
fn pg_test_fields(msg []u8) map[string]string {
	mut fields := map[string]string{}
	mut at := 0
	for at < msg.len && msg[at] != 0 {
		end := pg_test_string_end(msg, at + 1)
		fields[msg[at].ascii_str()] = msg[at + 1..end].bytestr()
		at = end + 1
	}

	return fields
}

// pg_test_string_end is the position of the zero byte that ends the string
// starting at at.
fn pg_test_string_end(b []u8, at int) int {
	mut end := at
	for b[end] != 0 {
		end++
	}

	return end
}

fn pg_test_int32(x int) []u8 {
	mut b := []u8{len: 4}
	binary.big_endian_put_u32(mut b, u32(x))

	return b
}

fn pg_test_read_int32(b []u8, at int) int {
	return int(binary.big_endian_u32(b[at..at + 4]))
}

fn pg_test_read_int16(b []u8, at int) int {
	return int(binary.big_endian_u16(b[at..at + 2]))
}

// The tests below are for what a SQL test can't reach, but they're in this file
// so that they count towards the SQL test coverage.

// start_sql_test_server_with starts another server, see start_sql_test_server.
fn start_sql_test_server_with(options ServerOptions) !&Server {
	mut server := new_server(options)
	server.listen()!
	spawn fn (mut server Server) {
		server.serve() or { eprintln('server stopped: ${err}') }
	}(mut server)

	return server
}

// Without a connect function every client opens db_file. A SELECT without a
// FROM is allowed with select_without_from.
fn test_server_db_file() ! {
	// test_all has already removed sql_test_dir(), so this has its own.
	dir := os.join_path(os.temp_dir(), 'vsql-sql-test-server-db-file-${os.getpid()}')
	os.mkdir_all(dir)!
	defer {
		os.rmdir_all(dir) or {}
	}

	mut server := start_sql_test_server_with(ServerOptions{
		db_file:             os.join_path(dir, 'test.vsql')
		select_without_from: true
	})!
	defer {
		server.stop() or {}
	}

	mut client1 := new_pg_test_client(server.port()!, 'ignored')!
	defer {
		client1.close()
	}
	assert client1.query('SELECT 1 AS x')!.rows == ['X: 1']
	client1.query('CREATE TABLE t (x INT)')!
	client1.query('INSERT INTO t (x) VALUES (123)')!

	mut client2 := new_pg_test_client(server.port()!, 'ignored')!
	defer {
		client2.close()
	}
	assert client2.query('SELECT * FROM t')!.rows == ['X: 123']
}

// A client only gets an error (or is disconnected) when its database can't be
// opened, it disconnects before sending its startup message or it disconnects
// without saying goodbye. The server keeps running for other clients.
fn test_server_host() ! {
	connect := fn (database string) !&Connection {
		return open(':memory:')
	}

	// Only clients on the same machine can connect by default.
	mut local := new_server(ServerOptions{
		connect: connect
	})
	if _ := local.address() {
		assert false, 'has an address before listening'
	} else {
		assert err.msg() == 'server is not listening'
	}
	local.listen()!
	defer {
		local.stop() or {}
	}
	assert local.address()! == '127.0.0.1:${local.port()!}'

	mut ip6 := new_server(ServerOptions{
		connect: connect
		host:    '::1'
	})
	ip6.listen()!
	defer {
		ip6.stop() or {}
	}
	assert ip6.address()! == '[::1]:${ip6.port()!}'

	// 192.0.2.1 is reserved for documentation, so it can't be a local address.
	mut remote := new_server(ServerOptions{
		connect: connect
		host:    '192.0.2.1'
	})
	if _ := remote.listen() {
		assert false, 'listened on an address that is not local'
	} else {
		assert err.msg().starts_with('cannot listen on 192.0.2.1:0: ')
	}
}

fn test_server_client_errors() ! {
	mut server := start_sql_test_server_with(ServerOptions{
		connect: fn (database string) !&Connection {
			if database == 'missing' {
				return error('no such database: ${database}')
			}

			return open(':memory:')
		}
	})!
	defer {
		server.stop() or {}
	}
	port := server.port()!

	if _ := new_pg_test_client(port, 'missing') {
		assert false, 'connected to a missing database'
	} else {
		assert err.msg() == 'no such database: missing'
	}

	mut early := net.dial_tcp('127.0.0.1:${port}')!
	early.close()!

	mut abrupt := new_pg_test_client(port, 'db')!
	abrupt.conn.close()!

	// The server keeps accepting clients after it fails to accept one.
	arm_fault('accept', 1)!
	defer {
		disarm_faults()
	}
	if _ := new_pg_test_client(port, 'db') {
		assert false, 'connected while accept is failing'
	}

	mut client := new_pg_test_client(port, 'db')!
	defer {
		client.close()
	}
	assert client.query('VALUES 1')!.rows == ['COL1: 1']
}

// A file can't have more than 256 transactions at the same time, because that's
// how many fit in its header.
fn test_too_many_transactions() {
	mut ids := TransactionIDs{}
	for i in 0 .. 256 {
		ids.add(u64(i + 1)) or { panic(err) }
	}

	ids.add(257) or {
		assert sqlstate_from_int(err.code()) == '0B000'
		assert err.msg() == 'invalid transaction initiation: max concurrent transactions reached'
		return
	}
	assert false, '257th transaction was added'
}

// Every error has a SQLSTATE, including the ones that aren't caused by SQL,
// such as a file that isn't a vsql database (E171).
fn test_sqlstate_for_other_errors() ! {
	assert header_error('nope'.bytes()) == 'XX001 not a vsql database, or it was created by a version of vsql before the file format had a magic number'

	mut data := new_header(4096).bytes()
	binary.big_endian_put_u16_at(mut data, file_format_version + 1, header_magic.len)
	assert header_error(data) == '0A000 database needs file format ${file_format_version + 1} to be read, but this version of vsql only supports up to ${file_format_version}, upgrade vsql to open it'

	binary.big_endian_put_u16_at(mut data, oldest_file_format_version - 1, header_magic.len)
	assert header_error(data) == '0A000 database uses file format ${oldest_file_format_version - 1}, which is older than this version of vsql supports (${oldest_file_format_version}), you will need to recreate it'

	data = new_header(4096).bytes()
	binary.big_endian_put_u32_at(mut data, 0, header_magic.len + 8)
	assert header_error(data) == 'XX001 invalid page size 0'

	mut db := open(':memory:')!
	db.add_catalog('FOO', ':memory:', default_connection_options())!
	mut got := ''
	db.add_catalog('FOO', ':memory:', default_connection_options()) or {
		got = '${sqlstate_from_int(err.code())} ${err.msg()}'
	}
	assert got == '42P04 duplicate catalog: FOO'

	got = ''
	create_plan(CommitStatement{}, map[string]Value{}, mut db) or {
		got = sqlstate_from_int(err.code())
	}
	assert got == 'XX000'

	// An error from the os module has no SQLSTATE, but one that already has a
	// SQLSTATE keeps it.
	assert sqlstate_from_int(io_error(error_with_code('no space left on device', 28)).code()) == '58030'
	assert sqlstate_from_int(io_error(sqlstate_22012()).code()) == '22012'
}

fn header_error(data []u8) string {
	new_header_from_bytes(data) or { return '${sqlstate_from_int(err.code())} ${err.msg()}' }

	return ''
}

// A page can't be larger than 65535 bytes, because the Used field of the page
// header is a u16 (#519).
fn test_page_size_limits() ! {
	data := new_header(65536).bytes()
	assert header_error(data) == 'XX001 invalid page size 65536'

	for page_size in [16, 65536] {
		mut options := default_connection_options()
		options.page_size = page_size
		message := '54000 page size ${page_size} must be more than 16 and at most 65535 bytes'

		if _ := open_database(':memory:', options) {
			assert false, 'opened :memory: with a page size of ${page_size}'
		} else {
			assert '${sqlstate_from_int(err.code())} ${err.msg()}' == message
		}

		// The file isn't created.
		path := os.join_path(os.temp_dir(), 'vsql-sql-test-page-size-${os.getpid()}.vsql')
		if _ := open_database(path, options) {
			assert false, 'created a file with a page size of ${page_size}'
		} else {
			assert '${sqlstate_from_int(err.code())} ${err.msg()}' == message
		}
		assert !os.exists(path)
	}

	// The largest page holds a value that fills most of it.
	path := os.join_path(os.temp_dir(), 'vsql-sql-test-page-size-${os.getpid()}.vsql')
	defer {
		os.rm(path) or {}
		os.rm(session_path(path)) or {}
	}
	mut options := default_connection_options()
	options.page_size = 65535
	mut db := open_database(path, options)!
	db.query('CREATE TABLE t (x VARCHAR(65000))')!
	db.query("INSERT INTO t (x) VALUES ('${'a'.repeat(60000)}')")!
	db.close()

	db = open_database(path, default_connection_options())!
	defer {
		db.close()
	}
	mut result := db.query('SELECT CHAR_LENGTH(x) AS l FROM t')!
	assert result.next()?.get_int('L')! == 60000
}

// A custom function that returns a NUMERIC has the type it's registered with,
// even if it has the name of a builtin numeric function, and it may return NULL.
fn test_custom_function_returns_numeric() ! {
	mut db := open(':memory:')!
	db.register_function('half(numeric) numeric', fn (a []Value) !Value {
		return new_numeric_value('${a[0].numeric_value().f64() / 2}')
	})!
	db.register_function('abs(varchar) numeric', fn (a []Value) !Value {
		return new_null_value(.is_numeric)
	})!

	assert db.query('VALUES half(5)')!.rows[0].get_string('COL1')! == '2.5'
	assert db.query("VALUES abs('x')")!.rows[0].get_null('COL1')!
}

// Builtin functions return NULL when any argument is NULL, but custom functions
// must still be called (CALLED ON NULL INPUT) so they can handle NULL
// themselves.
fn test_custom_function_receives_null() ! {
	mut db := open(':memory:')!
	db.register_function('is_missing(float) float', fn (a []Value) !Value {
		return new_double_precision_value(if a[0].is_null { 1 } else { 0 })
	})!

	db.query('CREATE TABLE t (x FLOAT)')!
	db.query('INSERT INTO t (x) VALUES (NULL)')!
	db.query('INSERT INTO t (x) VALUES (1.5)')!

	mut results := []f64{}
	for row in db.query('SELECT is_missing(x) AS m FROM t')! {
		results << row.get_f64('M')!
	}

	assert results == [1.0, 0.0]
}

fn test_custom_function_with_two_arguments() ! {
	mut db := open(':memory:')!
	db.register_function('add_both(float, float) float', fn (a []Value) !Value {
		return new_double_precision_value(a[0].f64_value() + a[1].f64_value())
	})!

	mut results := []f64{}
	for row in db.query('VALUES add_both(1.5, 2)')! {
		results << row.get_f64('COL1')!
	}

	assert results == [3.5]
}

// A function is identified by its name and argument types, so another function
// with the same ones can't be registered, even if it returns a different type.
fn test_custom_function_already_exists() ! {
	mut db := open(':memory:')!
	db.register_function('foo(integer) integer', fn (a []Value) !Value {
		return new_integer_value(1)
	})!

	assert register_function_error(mut db, 'foo(integer) varchar') == '42723 duplicate function: FOO(INTEGER)'

	// The same for a builtin function, and for CHARACTER, which is the same as
	// CHARACTER VARYING.
	assert register_function_error(mut db, 'abs(double precision) double precision') == '42723 duplicate function: ABS(DOUBLE PRECISION)'
	assert register_function_error(mut db, 'char_length(character) integer') == '42723 duplicate function: CHAR_LENGTH(CHARACTER)'

	// A function with the same name and different argument types is fine.
	db.register_function('foo(varchar) varchar', fn (a []Value) !Value {
		return new_varchar_value('three')
	})!

	assert db.query('VALUES foo(5)')!.rows[0].get_string('COL1')! == '1'
	assert db.query("VALUES foo('x')")!.rows[0].get_string('COL1')! == 'three'
}

fn register_function_error(mut db Connection, prototype string) string {
	db.register_function(prototype, fn (a []Value) !Value {
		return new_integer_value(0)
	}) or { return '${sqlstate_from_int(err.code())} ${err.msg()}' }

	return ''
}

// A prototype that can't be parsed, or has a type that doesn't exist, is an
// error.
fn test_custom_function_bad_prototype() ! {
	mut db := open(':memory:')!
	assert register_function_error(mut db, 'foo(nosuchtype) integer') == '42601 syntax error: unknown type: NOSUCHTYPE'
	assert register_function_error(mut db, 'foo(integer) nosuchtype') == '42601 syntax error: unknown type: NOSUCHTYPE'
	assert register_function_error(mut db, 'foo') == '42601 syntax error: invalid function prototype: foo'
	assert register_function_error(mut db, 'foo(integer)') == '42601 syntax error: invalid function prototype: foo(integer)'
	assert register_function_error(mut db, 'foo integer) integer') == '42601 syntax error: invalid function prototype: foo integer) integer'
	assert register_function_error(mut db, '(integer) integer') == '42601 syntax error: invalid function prototype: (integer) integer'
	assert register_function_error(mut db, 'a.b.c.d(integer) integer') == '42602 invalid identifier: a.b.c.d'
	assert register_function_error(mut db, '"foo(integer) integer') == '42602 invalid identifier chain: "foo'
}

// new_numeric_value and new_decimal_value (for an application) also accept an
// exponent.
fn test_new_numeric_and_decimal_value() {
	assert new_numeric_value('1.5e3').str() == '1500.0'
	assert new_decimal_value('1.25').str() == '1.25'
	assert new_decimal_value('1.25').typ.str() == 'DECIMAL(3, 2)'
}

// run_in_child runs f in a child process, and returns its exit code and what it
// wrote to stderr. It's for code that stops the process, such as a panic, which
// can't be recovered from. The child's coverage is still counted, because it's
// written when the child exits.
fn run_in_child(f fn ()) !(int, string) {
	stderr_path := os.join_path(os.temp_dir(), 'vsql-sql-test-child-${os.getpid()}.txt')
	pid := os.fork()
	if pid == 0 {
		stderr_file := os.create(stderr_path) or { exit(100) }
		C.dup2(stderr_file.fd, 2)
		f()
		exit(0)
	}

	mut status := 0
	C.waitpid(pid, &status, 0)
	stderr := os.read_file(stderr_path)!
	os.rm(stderr_path)!

	return (status >> 8) & 0xff, stderr
}

// A panic is for something that can't happen, so these break an invariant
// directly to check that it's caught, rather than carrying on with bad data.
fn test_panics() ! {
	$if windows {
		return
	}

	mut code, mut stderr := run_in_child(fn () {
		mut db := open(':memory:') or { panic(err) }
		db.current_catalog = 'NOPE'
		_ := db.catalog()
	})!
	assert code == 1
	assert stderr.contains('unknown catalog: NOPE')

	code, stderr = run_in_child(fn () {
		mut db := open(':memory:') or { panic(err) }
		_ := db.catalog_for(Identifier{ catalog_name: 'NOPE' })
	})!
	assert code == 1
	assert stderr.contains('unknown catalog: NOPE')

	code, stderr = run_in_child(fn () {
		_ := yy_as[Identifier](YYSym(true))
	})!
	assert code == 1
	assert stderr.contains('V panic: expected vsql.Identifier')

	code, stderr = run_in_child(fn () {
		mut page := new_page(kind_leaf, 64)
		page.add(new_page_object('k'.bytes(), 1, 0, []u8{len: 100})) or {}
	})!
	assert code == 1
	assert stderr.contains('page cannot fit object of 124 b in page using 16 b')
}

// crash_point stops the process the VSQL_CRASH_AT'th time it's reached, without
// flushing anything, see cmd/tests/crash-recovery.sh.
fn test_crash_point() ! {
	$if windows {
		return
	}

	code, stderr := run_in_child(fn () {
		mut state := unsafe { &CrashPoint(crash_point_state) }
		unsafe {
			*state = CrashPoint{
				at: 2
			}
		}
		crash_point()
		eprintln('first crash point passed')
		crash_point()
		eprintln('second crash point passed')
	})!
	assert code == 1
	assert stderr == 'first crash point passed\n'
}

// expire returns -1 when there's no object with the key and tid.
fn test_btree_expire_missing_object() ! {
	mut btree := new_btree(new_memory_pager(), 256)
	btree.add(new_page_object('a'.bytes(), 1, 0, 'x'.bytes()))!

	assert btree.expire('b'.bytes(), 1, 2)! == -1
	assert btree.expire('a'.bytes(), 2, 3)! == -1
	assert btree.expire('a'.bytes(), 1, 2)! >= 0
}

// A row only has the columns that the table had when it was written, so the
// columns after them are NULL.
fn test_row_with_fewer_columns() {
	x := Column{
		name: Identifier{
			entity_name:     'T'
			sub_entity_name: 'X'
		}
		typ:  new_type('INTEGER', 0, 0)
	}
	y := Column{
		name: Identifier{
			entity_name:     'T'
			sub_entity_name: 'Y'
		}
		typ:  new_type('INTEGER', 0, 0)
	}

	row := new_row({
		'X': new_integer_value(123)
	})
	data := row.bytes(Table{ columns: [x] })
	read := new_row_from_bytes(Table{ columns: [x, y] }, data, 1)

	assert read.data[x.name.id()].int_value() == 123
	assert read.data[y.name.id()].is_null
	assert read.data[y.name.id()].typ.typ == .is_integer
}

// verbose prints every message in and out of the server.
fn test_server_verbose() ! {
	$if windows {
		return
	}

	stdout_path := os.join_path(os.temp_dir(), 'vsql-sql-test-stdout-${os.getpid()}.txt')
	stdout_file := os.create(stdout_path)!
	saved_stdout := C.dup(1)
	C.dup2(stdout_file.fd, 1)
	defer {
		C.dup2(saved_stdout, 1)
		os.rm(stdout_path) or {}
	}

	mut server := start_sql_test_server_with(ServerOptions{
		connect: fn (database string) !&Connection {
			return open(':memory:')
		}
		verbose: true
	})!
	defer {
		server.stop() or {}
	}

	mut client := new_pg_test_client(server.port()!, 'db')!
	assert client.query('VALUES 1')!.rows == ['COL1: 1']
	client.close()

	// The server logs the disconnect after the client has gone. The message and
	// its newline may be written separately, so it waits for the whole line.
	mut stdout := ''
	for _ in 0 .. 500 {
		stdout = os.read_file(stdout_path)!
		if stdout.contains('disconnected\n') {
			break
		}
		time.sleep(10 * time.millisecond)
	}

	lines := stdout.split('\n')
	assert 'connected' in lines
	assert 'query: VALUES 1' in lines
	assert 'disconnected' in lines
}

// A comment doesn't end a statement, even with a semicolon or quote in it, and
// a statement that is only a comment is left out.
fn test_split_statements_with_comments() {
	assert split_statements("VALUES 1; -- it's; done") == ['VALUES 1']
	assert split_statements('VALUES 1 -- a;b\n, 2;\n-- end') == ['VALUES 1 -- a;b\n, 2']
	assert split_statements("VALUES '--';VALUES 2") == ["VALUES '--'", 'VALUES 2']

	// A comment may also end the SQL without a new line.
	mut db := open(':memory:')!
	assert db.query('VALUES 1 -- one')!.rows[0].get_string('COL1')! == '1'
}
