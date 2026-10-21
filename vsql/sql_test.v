module vsql

import encoding.binary
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
			|| it.starts_with('create_catalog ') || it.starts_with('virtual_table '))
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
			db.dump(mut sb)!
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
			if on_disk {
				restored_dir := os.join_path(dir, 'in_${restores}')
				os.mkdir_all(restored_dir)!
				path = os.join_path(restored_dir, ':memory:.vsql')
			}
			now := db.now
			db = open_database(path, options)!
			opened << db
			db.now = now
			register_pg_functions(mut db)!
			register_pg_virtual_tables(mut db)!
			for dump_stmt in split_statements(last_dump) {
				db.query(dump_stmt) or {
					actual += 'error ${sqlstate_from_int(err.code())}: ${err.msg()}\n'
				}
			}
			continue
		}

		if stmt.starts_with('connection ') {
			connection_name := stmt[11..]
			if connection_name !in connections {
				conn := new_sql_test_conn(through_server, file_name, options, port)!
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
	register_pg_functions(mut db)!
	register_pg_virtual_tables(mut db)!

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
			line += '${col.name.sub_entity_name}: ${row.get_column(col)!.str()} '
			if show_types {
				line += '(${row.get_column(col)!.typ}) '
			}
		}
		output.rows << line.trim_space()
	}

	return output
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
