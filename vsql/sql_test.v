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
	file_name   string
	line_number int
	stmts       []string
	expected    string
	show_types  bool
	show_flags  bool
	// extensions are the vsql extensions (such as "V001-01") that the test
	// uses, see the "extensions" directive.
	extensions []string
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
		mut show_types := false
		mut show_flags := false
		mut extensions := []string{}
		for line in lines {
			if line == '' {
				tests << SQLTest{setup, test_file_path, line_number, stmts, expected.join('\n'), show_types, show_flags, extensions}
				stmts = []
				expected = []
				in_setup = false
				show_types = false
				show_flags = false
				extensions = []
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
				} else if contents == 'flags' {
					show_flags = true
				} else if contents.starts_with('extensions ') {
					extensions = parse_extensions(contents[11..])
				} else if contents == 'params' || contents.starts_with('params ') {
					stmts << '${contents} '
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
			tests << SQLTest{setup, test_file_path, line_number, stmts, expected.join('\n'), show_types, show_flags, extensions}
		}
	}

	return tests
}

// parse_extensions returns the Feature IDs of an "extensions" directive, which
// must each be a vsql extension (VXXX-YY) and only listed once.
fn parse_extensions(s string) []string {
	mut extensions := []string{}
	for id in s.fields() {
		if !is_vsql_extension(id) || id in extensions {
			panic('bad extensions directive: "${s}"')
		}
		extensions << id
	}

	return extensions
}

// is_vsql_extension is true if a Feature ID is a vsql extension (VXXX-YY).
fn is_vsql_extension(id string) bool {
	return id.len == 7 && id[0] == `V` && id[4] == `-`
		&& id[1..4].bytes().all(it.is_digit()) && id[5..].bytes().all(it.is_digit())
}

// sql_test_extensions returns the vsql extensions that a statement uses, if it
// can be parsed.
fn sql_test_extensions(stmt string) []string {
	_, _, _, features := parse_sql(stmt) or { return [] }

	return features.filter(is_vsql_extension(it))
}

// parse_params returns the values of a "params" directive, named "?1", "?2",
// etc. Each value is a character string (such as 'it''s'), NULL followed by its
// type (such as NULL INTEGER) or a number, which is a DOUBLE PRECISION.
fn parse_params(s string) map[string]Value {
	mut params := map[string]Value{}
	mut i := 0
	for i < s.len {
		if s[i] == ` ` {
			i++
			continue
		}

		name := '?${params.len + 1}'
		if s[i] == `'` {
			start := i + 1
			i = start
			for i < s.len && !(s[i] == `'` && (i + 1 == s.len || s[i + 1] != `'`)) {
				i += if s[i] == `'` { 2 } else { 1 }
			}
			params[name] = new_character_value(s[start..i].replace("''", "'"))
			i++
			continue
		}

		word, after_word := next_param_word(s, i)
		i = after_word
		if word == 'NULL' {
			typ, after_type := next_param_word(s, i)
			i = after_type
			params[name] = new_null_value(new_type(typ, 0, 0).typ)
		} else {
			params[name] = new_double_precision_value(word.f64())
		}
	}

	return params
}

// next_param_word returns the next word in s from i, and the position after it.
fn next_param_word(s string, i int) (string, int) {
	mut start := i
	for start < s.len && s[start] == ` ` {
		start++
	}

	mut end := start
	for end < s.len && s[end] != ` ` {
		end++
	}

	return s[start..end], end
}

// substitute_params returns the statement on one line, with each "?" replaced
// by the literal of its value, or none if no "?" has a value. A "?" that doesn't
// have a value isn't replaced.
fn substitute_params(stmt string, params map[string]Value) ?string {
	mut sb := strings.new_builder(stmt.len)
	mut n := 0
	mut replaced := 0
	mut quote := u8(0)
	for c in stmt {
		if quote != 0 {
			if c == quote {
				quote = 0
			}
		} else if c == `'` || c == `"` {
			quote = c
		} else if c == `?` {
			n++
			if v := params['?${n}'] {
				sb.write_string(if v.is_null { 'CAST(NULL AS ${v.typ})' } else { v.literal() })
				replaced++
				continue
			}
		}

		sb.write_u8(c)
	}

	if replaced == 0 {
		return none
	}

	return sb.str().trim_space().trim_right(';').replace('\n', ' ')
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
// library has, such as faults, dynamic parameters or the type of each value, so
// those use a Connection directly.
fn (test SQLTest) through_server() bool {
	return $env('SERVER') != '0' && !test.show_types && !test.show_flags
		&& !test.stmts.any(it.starts_with('params '))
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
	mut flagged := map[string]bool{}
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
				port, mut flagged)! {
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

	// Every feature that can be flagged (including the vsql extensions) must be
	// in the flags of at least one test that has the "flags" directive, so it
	// can't be missed by a test that only happens to use it.
	if filter_test == '' {
		missing := sql_flagger_features()!.filter(it !in flagged)
		assert missing == [], 'not flagged by any test with /* flags */: ${missing.join(', ')}'
	}
}

// sql_flagger_features returns every Feature ID that the SQL Flagger can flag,
// which are the quoted Feature IDs (such as 'F591' or 'V001-01') in the
// grammar, the lexer and the flagger.
fn sql_flagger_features() ![]string {
	mut files := os.glob('vsql/*.y')!
	files << ['vsql/lexer.v', 'vsql/std_1_8_5_sql_flagger.v']
	mut re := regex.regex_opt(r"'[A-Z]\d\d\d(-\d\d)?'")!
	mut features := []string{}
	for file in files {
		for id in re.find_all_str(os.read_file(file)!) {
			if id[1..id.len - 1] !in features {
				features << id[1..id.len - 1]
			}
		}
	}
	features.sort()

	return features
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
fn run_single_test(test SQLTest, verbose bool, filter_line int, mode SQLTestMode, through_server bool, port int, mut flagged map[string]bool) !SQLTestResult {
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

	// A test can only use the vsql extensions in its "extensions" directive, and
	// must use each of them. The setup of a file can't use any.
	mut problems := []string{}
	mut used := []string{}
	for stmt in test.setup {
		if verbose {
			println('  ${stmt.trim_space()}')
		}

		for id in sql_test_extensions(stmt) {
			problems << 'setup uses vsql extension ${id}: ${stmt.trim_space()}'
		}

		output := db.run(stmt, map[string]Value{}, false, false)!
		if output.error != '' {
			return error('setup failed: ${stmt}: ${output.error}')
		}
	}

	mut actual := ''
	mut last_dump := ?string(none)
	mut restores := 0
	mut params := map[string]Value{}
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
		// "params <value> ..." sets the value of each "?" for the statements
		// that follow.
		if stmt.starts_with('params ') {
			params = parse_params(stmt[7..])
			continue
		}

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

		for id in sql_test_extensions(stmt) {
			if id !in test.extensions {
				problems << "uses vsql extension ${id}, which isn't in /* extensions */: ${stmt.trim_space()}"
			}
			used << id
		}

		// A statement with a "?" also shows each value it's given, in place of
		// its "?".
		if substituted := substitute_params(stmt, params) {
			actual += '${prefix}sql: ${substituted}\n'
		}

		output := db.run(stmt, params, test.show_types, test.show_flags)!
		if output.flags != '' {
			actual += '${prefix}${output.flags}\n'
			for id in output.flags.all_after('flags:').split(',') {
				if id.trim_space() != '' {
					flagged[id.trim_space()] = true
				}
			}
		}

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

	for id in test.extensions {
		if id !in used {
			problems << '/* extensions */ lists ${id}, but no statement uses it'
		}
	}
	for problem in problems {
		eprintln('${at}${problem}\n')
	}

	return if expected == actual_trim && problems.len == 0 {
		SQLTestResult.passed
	} else {
		SQLTestResult.failed
	}
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
	error string
	// flags are the features of the statement, for the "flags" directive.
	flags    string
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

fn (mut c SQLTestConn) run(stmt string, params map[string]Value, show_types bool, show_flags bool) !SQLTestOutput {
	if c.client != unsafe { nil } {
		return c.client.query(stmt)
	}

	mut output := SQLTestOutput{}
	mut prepared := c.db.prepare(stmt) or {
		output.error = 'error ${sqlstate_from_int(err.code())}: ${err.msg()}'
		return output
	}
	if show_flags {
		output.flags = 'flags: ${prepared.features().join(', ')}'.trim_space()
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

// module_error is the error from compiling an SQL-client module, or an empty
// string if it compiles.
fn module_error(source string) string {
	compile_module(source, 'm') or { return err.msg() }
	return ''
}

const module_header = 'MODULE LANGUAGE C SCHEMA s '

fn test_module_compile() ! {
	m := compile_module('-- A module.
MODULE "My Module" LANGUAGE C SCHEMA "it\'s" AUTHORIZATION a
PROCEDURE add (SQLSTATE, :c CHAR, :v VARCHAR(10), :s SMALLINT, :i INT,
    :i2 INTEGER, :b BIGINT, :r REAL, :d DOUBLE PRECISION, :f BOOLEAN,
    :ind SMALLINT, :unused BIGINT);
  /* ; */ INSERT INTO "t;" (a) VALUES (\'a;\\"\n\t\r\', :c, :v :ind, :s INDICATOR :ind,
    :i, :i2, :b, :r, :d, :f) -- ;
;
PROCEDURE procedure (SQLSTATE); START TRANSACTION;
procedure c2 (SQLSTATE); COMMIT;
PROCEDURE r (SQLSTATE); ROLLBACK;
PROCEDURE conn (SQLSTATE, :n CHAR(3), :u VARCHAR(4));
  CONNECT TO \'file\' AS :n USER :u;
PROCEDURE conn_default (SQLSTATE); CONNECT TO DEFAULT;
PROCEDURE conn_server (SQLSTATE); CONNECT TO \'x\';
PROCEDURE set_conn (SQLSTATE); SET CONNECTION \'x\';
PROCEDURE set_default (SQLSTATE); SET CONNECTION DEFAULT;
PROCEDURE d1 (SQLSTATE); DISCONNECT DEFAULT;
PROCEDURE d2 (SQLSTATE); DISCONNECT ALL;
PROCEDURE d3 (SQLSTATE); DISCONNECT CURRENT;
PROCEDURE d4 (SQLSTATE, :n CHAR(1)); DISCONNECT :n;
PROCEDURE set_schema (SQLSTATE); SET SCHEMA \'x\';
', 'my-module')!
	assert m.header.contains('#ifndef MY_MODULE_H')
	assert m.header.contains('void add(char SQLSTATE[6], char c[8], char v[44], short *s, long *i, long *i2, long long *b, float *r, double *d, long *f, short *ind, long long *unused);')
	assert m.source.contains('#include "my-module.h"')
	assert m.source.contains('static const char vsql_m_set_schema[] = "SET SCHEMA \'it\'\'s\'";')
	assert m.source.contains('  (void)unused;\n')
	assert m.source.contains('{SQL_CHAR, SQL_BOOLEAN, 0, (SQLPOINTER)(*f ? "TRUE" : "FALSE"), SQL_NTS}')
	assert m.source.contains('INSERT INTO \\"t;\\" (a) VALUES (\'a;\\\\\\"\\n\\t\\r\', CAST(? AS CHARACTER(1)), CAST(? AS CHARACTER VARYING(10)), CAST(? AS SMALLINT)')
	assert m.source.contains('  if (*ind < 0) {\n    vsql_m_p[1].indicator = SQL_NULL_DATA;\n  } else if (!vsql_m_string(SQLSTATE, v, 44)) {')
	assert m.source.contains('  if (*ind < 0) {\n    vsql_m_p[2].indicator = SQL_NULL_DATA;\n  }\n')
	assert m.source.contains('void procedure(char SQLSTATE[6]) {\n  vsql_m_begin("START TRANSACTION", 111);\n  vsql_m_start(SQLSTATE);')
	assert m.source.contains('void c2(char SQLSTATE[6]) {\n  vsql_m_begin("COMMIT WORK", 11);\n  vsql_m_end(SQLSTATE, SQL_COMMIT);')
	assert m.source.contains('vsql_m_end(SQLSTATE, SQL_ROLLBACK);')
	assert m.source.contains('vsql_m_connect(SQLSTATE, "file", n, u);')
	assert m.source.contains('vsql_m_connect(SQLSTATE, NULL, NULL, NULL);')
	assert m.source.contains('vsql_m_connect(SQLSTATE, "x", NULL, NULL);')
	assert m.source.contains('vsql_m_set_connection(SQLSTATE, "x");')
	assert m.source.contains('vsql_m_set_connection(SQLSTATE, NULL);')
	assert m.source.contains("vsql_m_disconnect(SQLSTATE, 'D', NULL);")
	assert m.source.contains("vsql_m_disconnect(SQLSTATE, 'A', NULL);")
	assert m.source.contains("vsql_m_disconnect(SQLSTATE, 'C', NULL);")
	assert m.source.contains("vsql_m_disconnect(SQLSTATE, 'n', n);")
	assert m.source.contains('vsql_m_execute(SQLSTATE, "SET SCHEMA \'x\'", 0, NULL);')

	// 23.1 <get diagnostics statement> doesn't empty the diagnostics area.
	m4 := compile_module(module_header + 'PROCEDURE p (SQLSTATE, :n INT, :s CHAR(5), :c SMALLINT); GET DIAGNOSTICS :n = NUMBER, :s = DYNAMIC_FUNCTION; ' +
		'PROCEDURE q (SQLSTATE, :n BIGINT, :s VARCHAR(5), :c SMALLINT); GET DIAGNOSTICS CONDITION :c :n = CONDITION_NUMBER, :s = MESSAGE_TEXT, :n = PARAMETER_ORDINAL_POSITION; ' +
		'PROCEDURE r (SQLSTATE, :n INT); GET DIAGNOSTICS CONDITION 01 :n = CONDITION_NUMBER;',
		'm')!
	assert m4.source.contains('void p(char SQLSTATE[6], long *n, char s[24], short *c) {\n  (void)c;\n  int vsql_m_w = 0;\n')
	assert m4.source.contains('  *n = (long)vsql_m_item_number(SQL_DIAG_NUMBER, 0);\n  vsql_m_w |= vsql_m_put(s, 5, 1, vsql_m_item_text(VSQL_M_DYNAMIC_FUNCTION, 0));\n  vsql_m_sqlstate(SQLSTATE, vsql_m_w ? "01004" : "00000");\n')
	assert m4.source.contains('  long long vsql_m_n = (long long)*c;\n  if (vsql_m_n < 1 || vsql_m_n > vsql_m_da.number) {\n    vsql_m_sqlstate(SQLSTATE, "35000");\n    return;\n  }\n  *n = (long long)vsql_m_n;\n  vsql_m_w |= vsql_m_put(s, 5, 0, vsql_m_item_text(SQL_DIAG_MESSAGE_TEXT, vsql_m_n));\n  *n = (long long)0;\n')
	assert m4.source.contains('  long long vsql_m_n = 1LL;\n')
	assert m4.source.contains('  *n = (long)vsql_m_n;\n  vsql_m_sqlstate(SQLSTATE, "00000");\n')
	assert !m4.source.contains('  vsql_m_begin(')

	// Only the sections of the runtime that are used are included.
	m2 := compile_module(module_header + 'PROCEDURE p (SQLSTATE); DISCONNECT ALL;', 'm')!
	assert m2.source.contains('vsql_m_disconnect(')
	assert !m2.source.contains('vsql_m_execute(')
	assert !m2.source.contains('vsql_m_switch(')

	// The schema is the authorization identifier when there's no SCHEMA.
	m3 := compile_module('MODULE m LANGUAGE C AUTHORIZATION bob PROCEDURE p (SQLSTATE); COMMIT;',
		'm')!
	assert m3.source.contains('"SET SCHEMA \'BOB\'"')
}

fn test_module_errors() ! {
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE);') == 'syntax error: a module must end with a procedure that has a statement'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); COMMIT; PROCEDURE P (SQLSTATE); COMMIT;') == 'syntax error: procedure P is defined more than once'
	assert module_error('MODULE LANGUAGE ADA SCHEMA s PROCEDURE p (SQLSTATE); COMMIT;') == 'syntax error: only LANGUAGE C is supported, not ADA'
	assert module_error('MODULE LANGUAGE C PROCEDURE p (SQLSTATE); COMMIT;') == 'syntax error: expected SCHEMA or AUTHORIZATION after LANGUAGE C'
	assert module_error(module_header + 'PATH s PROCEDURE p (SQLSTATE); COMMIT;') == 'syntax error: expected PROCEDURE or DECLARE after the module authorization clause'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); COMMIT') == 'syntax error: a statement in a module must end with a semicolon'
	assert module_error('MODULE') == 'syntax error: a statement in a module must end with a semicolon'
	assert module_error('MODULE;;') == 'syntax error: expected LANGUAGE at the end'
	assert module_error('LANGUAGE C;;') == 'syntax error: expected MODULE near LANGUAGE'
	assert module_error('MODULE LANGUAGE C SCHEMA 1;;') == 'syntax error: expected schema name near 1'
	assert module_error('MODULE LANGUAGE C SCHEMA "";;') == 'syntax error: invalid delimited identifier: ""'
	assert module_error('MODULE LANGUAGE C SCHEMA "s;;') == 'syntax error: unterminated delimited identifier: "s'
	assert compile_module('MODULE LANGUAGE C SCHEMA "a""b" PROCEDURE p (SQLSTATE); COMMIT;',
		'm')!.source.contains('SET SCHEMA \'a\\"b\'')
	assert module_error("MODULE LANGUAGE C SCHEMA 's;;") == "syntax error: unterminated string: 's;;"
	assert module_error(module_header + 'PROCEDURE "p" (SQLSTATE); COMMIT;') == 'syntax error: expected procedure name near p'
	assert module_error(module_header + 'PROCEDURE p SQLSTATE; COMMIT;') == 'syntax error: expected ( near SQLSTATE'

	// 13.3 <externally-invoked procedure>
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, SQLSTATE); COMMIT;') == 'syntax error: procedure p: SQLSTATE can only be used once'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :a INT, :A INT); COMMIT;') == 'syntax error: procedure p: host parameter :A is declared more than once'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE) x; COMMIT;') == 'syntax error: procedure p: expected ; near x'
	assert module_error(module_header + 'PROCEDURE p (:a INT); COMMIT;') == 'syntax error: procedure p: SQLSTATE must be one of the parameters'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, a INT); COMMIT;') == 'syntax error: expected : near a'

	// 13.5 Data type correspondences
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :a VARCHAR); COMMIT;') == 'syntax error: host parameter :a: CHARACTER VARYING must have a length'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :a CHAR(0)); COMMIT;') == 'syntax error: expected a length near 0'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :a DOUBLE); COMMIT;') == 'syntax error: expected PRECISION near )'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :a DATE); COMMIT;') == 'syntax error: host parameter :a: the data type must be CHARACTER, CHARACTER VARYING, SMALLINT, INTEGER, BIGINT, REAL, DOUBLE PRECISION or BOOLEAN'

	// 13.4 <SQL procedure statement>
	assert module_error(module_header + "PROCEDURE p (SQLSTATE); VALUES 'a;") == "syntax error: unterminated string: 'a;"
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); VALUES "a;') == 'syntax error: unterminated delimited identifier: "a'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); DELETE FROM t WHERE x = ?;') == 'syntax error: procedure p: a module cannot contain a dynamic parameter (?), use a host parameter (:name)'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); DELETE FROM t WHERE x = "";') == 'syntax error: procedure p: a delimited identifier cannot be empty'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); VALUES 1;') == 'syntax error: procedure p: a query is not an SQL procedure statement, use SELECT ... INTO'
	parse_error := module_error(module_header + 'PROCEDURE p (SQLSTATE); DELETE t;')
	assert parse_error.starts_with('syntax error: procedure p: ')
	assert parse_error.count('syntax error') == 1
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); DELETE FROM t WHERE x = :x;') == 'syntax error: procedure p: host parameter :x is not declared'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); DELETE FROM t WHERE x = : x;') == 'syntax error: expected a host parameter name after :'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :x INT); DELETE FROM t WHERE x = :x INDICATOR 1;') == 'syntax error: expected an indicator parameter after INDICATOR'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :x INT, :i REAL); DELETE FROM t WHERE x = :x :i;') == 'syntax error: procedure p: indicator parameter :i must be SMALLINT, INTEGER or BIGINT'

	// 14.7 <select statement: single row>
	select_header := module_header + 'PROCEDURE p (SQLSTATE, :a INT, :b REAL); '
	assert module_error(select_header + 'SELECT x INTO :a, :b FROM t;') == 'syntax error: procedure p: the select list has 1 column, but there are 2 targets'
	assert module_error(select_header + 'SELECT x, y INTO :a FROM t;') == 'syntax error: procedure p: the select list has 2 columns, but there is 1 target'
	assert module_error(select_header + 'SELECT x INTO a FROM t;') == 'syntax error: procedure p: expected a host parameter after INTO near a'
	assert module_error(select_header + 'SELECT x INTO FROM t;') == 'syntax error: procedure p: expected a host parameter after INTO at the end'
	assert module_error(select_header + 'SELECT x INTO :c FROM t;') == 'syntax error: procedure p: host parameter :c is not declared'
	assert module_error(select_header + 'SELECT x INTO :a :b FROM t;') == 'syntax error: procedure p: indicator parameter :b must be SMALLINT, INTEGER or BIGINT'
	assert module_error(select_header + 'SELECT x INTO :a INDICATOR b FROM t;') == 'syntax error: expected : near b'
	assert module_error(select_header + 'SELECT x INTO :a x FROM t;') == 'syntax error: procedure p: expected FROM near x'
	assert module_error(select_header + 'SELECT x INTO :a FROM t ORDER BY x;') == 'syntax error: procedure p: SELECT ... INTO cannot have UNION, EXCEPT, INTERSECT, ORDER BY, OFFSET or FETCH'
	assert module_error(select_header + 'SELECT x INTO :a FROM t UNION SELECT x FROM t;') == 'syntax error: procedure p: SELECT ... INTO cannot have UNION, EXCEPT, INTERSECT, ORDER BY, OFFSET or FETCH'
	assert module_error(select_header + 'SELECT x INTO :a FROM t FETCH FIRST 1 ROW ONLY;') == 'syntax error: procedure p: SELECT ... INTO cannot have UNION, EXCEPT, INTERSECT, ORDER BY, OFFSET or FETCH'
	assert module_error(select_header + 'SELECT x INTO :a;').starts_with('syntax error: procedure p: ')
	assert module_error(select_header + 'SELECT t.* INTO :a FROM t;') == ''
	assert module_error(select_header + 'SELECT * INTO :a FROM t;') == ''
	assert module_error(select_header + 'SELECT :b INTO :a FROM t;') == ''
	assert module_error(select_header + 'SELECT x FROM t;') == 'syntax error: procedure p: a query is not an SQL procedure statement, use SELECT ... INTO'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :a INT, :i SMALLINT); SELECT ("x") INTO :a INDICATOR :i FROM t;') == ''

	// 23.1 <get diagnostics statement>
	diag_header := module_header + 'PROCEDURE p (SQLSTATE, :n INT, :s CHAR(5), :r REAL); GET DIAGNOSTICS '
	assert module_error(diag_header + 'n = NUMBER;') == 'syntax error: procedure p: expected a host parameter near n'
	assert module_error(diag_header + ':x = NUMBER;') == 'syntax error: procedure p: host parameter :x is not declared'
	assert module_error(diag_header + ':n NUMBER;') == 'syntax error: expected = near NUMBER'
	assert module_error(diag_header + ':s = ALL;') == 'syntax error: procedure p: GET DIAGNOSTICS ... = ALL is not supported'
	assert module_error(diag_header + ':n = MESSAGE_TEXT;') == 'syntax error: procedure p: expected a statement information item name near MESSAGE_TEXT'
	assert module_error(diag_header + ':n =;') == 'syntax error: procedure p: expected a statement information item name at the end'
	assert module_error(diag_header + 'CONDITION 1 :n = NUMBER;') == 'syntax error: procedure p: expected a condition information item name near NUMBER'
	assert module_error(diag_header + ':s = NUMBER;') == 'syntax error: procedure p: host parameter :s must be SMALLINT, INTEGER or BIGINT for NUMBER'
	assert module_error(diag_header + ':r = MORE;') == 'syntax error: procedure p: host parameter :r must be CHARACTER or CHARACTER VARYING for MORE'
	assert module_error(diag_header + ':n = NUMBER x;') == 'syntax error: procedure p: unexpected near x'
	assert module_error(diag_header + 'CONDITION :r :n = CONDITION_NUMBER;') == 'syntax error: procedure p: the condition number :r must be SMALLINT, INTEGER or BIGINT'
	assert module_error(diag_header + 'CONDITION :x :n = CONDITION_NUMBER;') == 'syntax error: procedure p: host parameter :x is not declared'
	assert module_error(diag_header + 'CONDITION :n = CONDITION_NUMBER;') == 'syntax error: procedure p: expected a host parameter near ='
	assert module_error(diag_header + 'CONDITION x :n = CONDITION_NUMBER;') == 'syntax error: procedure p: expected a condition number near x'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); GET x;').starts_with('syntax error: procedure p: ')

	// 18 SQL-connection statements
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); CONNECT DEFAULT;') == 'syntax error: expected TO near DEFAULT'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :n INT); CONNECT TO :n;') == 'syntax error: procedure p: host parameter :n must be CHARACTER or CHARACTER VARYING'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); CONNECT TO 1;') == 'syntax error: procedure p: expected a string or a host parameter near 1'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); DISCONNECT ALL x;') == 'syntax error: unexpected near x'
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

// A custom function is NOT DETERMINISTIC, so it can't be used in a CHECK
// constraint.
fn test_custom_function_in_check_constraint() ! {
	mut db := open(':memory:')!
	db.register_function('double_it(integer) integer', fn (a []Value) !Value {
		return new_integer_value(int(a[0].int_value() * 2))
	})!

	db.query('CREATE TABLE t (x INTEGER CHECK (double_it(x) > 0))') or {
		assert err.msg() == 'syntax error: non-deterministic function DOUBLE_IT cannot be used in a CHECK constraint'
		return
	}
	assert false
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
//
// The exit code is 1, except that V's backtrace (after the message) can crash on
// Linux ARM64, which exits with 255 (https://github.com/vlang/v/issues/31422).
const panic_exit_codes = $if linux && arm64 { [1, 255] } $else { [1] }

fn test_panics() ! {
	$if windows {
		return
	}

	mut code, mut stderr := run_in_child(fn () {
		mut db := open(':memory:') or { panic(err) }
		db.current_catalog = 'NOPE'
		_ := db.catalog()
	})!
	assert code in panic_exit_codes
	assert stderr.contains('unknown catalog: NOPE')

	code, stderr = run_in_child(fn () {
		mut db := open(':memory:') or { panic(err) }
		_ := db.catalog_for(Identifier{ catalog_name: 'NOPE' })
	})!
	assert code in panic_exit_codes
	assert stderr.contains('unknown catalog: NOPE')

	code, stderr = run_in_child(fn () {
		_ := yy_as[Identifier](YYSym(true))
	})!
	assert code in panic_exit_codes
	assert stderr.contains('V panic: expected vsql.Identifier')

	code, stderr = run_in_child(fn () {
		mut page := new_page(kind_leaf, 64)
		page.add(new_page_object('k'.bytes(), 1, 0, []u8{len: 100})) or {}
	})!
	assert code in panic_exit_codes
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

// A semicolon in a bracketed comment (which can be nested) doesn't end a
// statement either. The text after the last semicolon is returned as it is,
// unless it's only white space and comments.
fn test_split_terminated_statements() {
	cases := {
		'VALUES 1 /* a; /* b; */ c; */;': ['VALUES 1 /* a; /* b; */ c; */', '']
		'VALUES 1; /* end */\n':          ['VALUES 1', '']
		'VALUES 1; VALUES\n':             ['VALUES 1', ' VALUES\n']
		"VALUES ';":                      ["VALUES ';"]
		'/* a; */ /* b;':                 ['/* a; */ /* b;']
	}
	for script, expected in cases {
		statements, rest := split_terminated_statements(script)
		assert [...statements, rest] == expected, script
	}
	assert split_statements('VALUES 1; VALUES 2 ') == ['VALUES 1', 'VALUES 2']
}

// ISO/IEC 9075-2:2016(E), 22.1, <direct SQL statement>
fn test_direct() {
	mut db := open(':memory:')!

	// A statement that isn't one statement ending with a semicolon, or that has
	// a parameter, is a syntax error.
	for stmt in ['VALUES 1', 'VALUES 1; VALUES 2;', 'VALUES ?;', 'VALUES :x;'] {
		db.direct(stmt) or {
			assert sqlstate_from_int(err.code()) == '42601'
			continue
		}
		assert false, stmt
	}
	assert !db.in_transaction()

	// SET CATALOG and SET SCHEMA don't start an SQL-transaction.
	db.direct("SET SCHEMA 'PUBLIC';")!
	assert !db.in_transaction()

	// Any other statement starts one, which stays active until it's committed.
	db.direct('CREATE TABLE t (x INT);')!
	assert db.in_transaction()
	db.direct('INSERT INTO t (x) VALUES (1);')!
	db.direct('COMMIT;')!
	assert !db.in_transaction()

	// An empty result of a query is no data. A query starts an SQL-transaction
	// too, but it isn't started in storage until something is changed.
	db.clear_warnings()
	assert db.direct('SELECT * FROM t WHERE x = 2;')!.rows.len == 0
	assert !db.in_transaction() && db.direct_query_transaction
	assert db.warnings.map(sqlstate_from_int(it.code())) == ['02000']
	db.clear_warnings()
	assert db.direct('SELECT * FROM t;')!.rows.len == 1
	assert db.warnings.len == 0
	assert db.direct('COMMIT;')!.msg == 'COMMIT'
	assert !db.direct_query_transaction
	db.direct('VALUES 1;')!
	db.direct('INSERT INTO t (x) VALUES (2);')!
	assert db.in_transaction() && !db.direct_query_transaction
	db.direct('COMMIT;')!
	db.direct('VALUES 1;')!

	// START TRANSACTION can't be used while the SQL-transaction is active.
	db.direct('START TRANSACTION;') or {
		assert sqlstate_from_int(err.code()) == '25001'
		assert db.direct('ROLLBACK;')!.msg == 'ROLLBACK'
		db.direct('START TRANSACTION;')!
		assert db.in_transaction()
		db.direct('ROLLBACK;')!

		// With autocommit, each statement commits on its own.
		db.direct('INSERT INTO t (x) VALUES (3);', autocommit: true)!
		assert !db.in_transaction() && !db.direct_query_transaction
		assert db.direct('SELECT * FROM t WHERE x = 3;', autocommit: true)!.rows.len == 1
		assert !db.in_transaction() && !db.direct_query_transaction

		// SET TRANSACTION doesn't start an SQL-transaction, and its DIAGNOSTICS
		// SIZE is for the next one, even if a query starts it.
		db.direct('SET TRANSACTION DIAGNOSTICS SIZE 1;')!
		assert !db.is_active()
		db.direct('VALUES 1;')!
		db.direct('INSERT INTO t (x) VALUES (4);')!
		assert db.condition_area_limit == 1
		db.direct('SET TRANSACTION;') or { assert sqlstate_from_int(err.code()) == '25001' }
		db.direct('ROLLBACK;')!
		db.direct('SET TRANSACTION DIAGNOSTICS SIZE 2;')!
		db.direct('INSERT INTO t (x) VALUES (4);')!
		assert db.condition_area_limit == 2
		db.direct('ROLLBACK;')!
		return
	}
	assert false
}

// agent_sqlstate is the SQLSTATE of the error of a statement, or '' if it
// succeeds.
fn agent_sqlstate(mut a Agent, stmt string) string {
	a.direct(stmt) or { return sqlstate_from_int(err.code()) }
	return ''
}

fn test_agent() {
	// The default SQL-connection is established by the first statement that
	// isn't a connection statement. The other files are attached as catalogs.
	mut a := new_agent(':memory:', catalogs: [':memory:'])
	assert agent_sqlstate(mut a, 'VALUES 1;') == '08001'
	a = new_agent(':memory:')
	assert !a.in_transaction()
	for stmt in [';', '"";', 'VALUES;'] {
		assert agent_sqlstate(mut a, stmt) == '42601', stmt
	}
	a.direct('CREATE TABLE t (x INT);')!
	assert a.in_transaction()

	// Only the current SQL-connection can have an active SQL-transaction.
	for stmt in ["CONNECT TO ':memory:' AS 'c';", 'SET CONNECTION DEFAULT;', 'DISCONNECT CURRENT;'] {
		assert agent_sqlstate(mut a, stmt) in ['0A001', '25001'], stmt
	}
	a.direct('COMMIT;')!

	// A connection name is an identifier, and the SQL-server name is the
	// connection name when there isn't one.
	for name, code in {
		'':        '2E000'
		'x y':     '2E000'
		'x;':      '2E000'
		'1':       '2E000'
		'(':       '2E000'
		'"x':      '2E000'
		'DEFAULT': ''
		' c ':     ''
		'"c"':     ''
		'C':       '08002'
	} {
		assert agent_sqlstate(mut a, "CONNECT TO ':memory:' AS '${name}';") == code, name
	}
	assert agent_sqlstate(mut a, "CONNECT TO ':memory:';") == '2E000'
	assert agent_sqlstate(mut a, "CONNECT TO ':memory:' USER 'bob';") == '2E000'
	assert agent_sqlstate(mut a, "CONNECT TO '/does/not/exist.vsql' AS 'd';") == '08001'
	assert agent_sqlstate(mut a, "CONNECT TO ':memory:' AS 'u' USER 'a b';") == '28000'
	assert agent_sqlstate(mut a, "CONNECT TO ':memory:' AS 'u' USER 'bob';") == ''
	assert agent_sqlstate(mut a, 'CONNECT TO :x;') == '42601'
	assert agent_sqlstate(mut a, 'CONNECT TO DEFAULT;') == '08002'

	// The connection is a different SQL-server. The SQL-transaction that the
	// query started is still active.
	assert agent_sqlstate(mut a, 'SELECT * FROM t;') == '42P01'
	assert agent_sqlstate(mut a, 'SET CONNECTION DEFAULT;') == '0A001'
	a.direct('ROLLBACK;')!
	a.direct('SET CONNECTION DEFAULT;')!
	assert a.direct('SELECT * FROM t;')!.rows.len == 0
	assert a.warnings.map(sqlstate_from_int(it.code())) == ['02000']
	a.direct('ROLLBACK;')!
	assert agent_sqlstate(mut a, "SET CONNECTION 'nope';") == '08003'

	// A connection statement can't be prepared.
	mut conn := a.current
	conn.query('CONNECT TO DEFAULT') or { assert sqlstate_from_int(err.code()) == '42601' }

	// After a connection statement, there's no implicit connection.
	a.direct('DISCONNECT DEFAULT;')!
	assert agent_sqlstate(mut a, 'SET CONNECTION DEFAULT;') == '08003'
	assert agent_sqlstate(mut a, 'DISCONNECT CURRENT;') == '08003'
	assert agent_sqlstate(mut a, 'VALUES 1;') == '08003'
	a.direct("SET CONNECTION 'default';")!
	a.direct('DISCONNECT CURRENT;')!
	assert agent_sqlstate(mut a, "DISCONNECT 'default';") == '08003'
	a.direct('CONNECT TO DEFAULT;')!
	a.direct('DISCONNECT ALL;')!
	assert a.all_connections().len == 0

	// The end of the SQL-session commits, or rolls back.
	a.direct('CONNECT TO DEFAULT;')!
	a.direct('CREATE TABLE t (x INT);')!
	assert a.in_transaction()
	a.close(true)!
	assert !a.in_transaction() && a.all_connections().len == 0
	a.connect_default()!
	a.connect_default()!
	a.close(false)!
}

// The reserved words are sorted and leave out the non-reserved words (which
// can be identifiers), operators, literals and E.
fn test_reserved_words() {
	words := reserved_words()
	assert 'SELECT' in words
	assert 'FROM' in words
	assert 'NAME' !in words
	assert 'E' !in words
	assert !words.any(it.starts_with('OPERATOR_') || it.starts_with('LITERAL_'))
	mut sorted := words.clone()
	sorted.sort()
	assert words == sorted
}

// A DEFAULT can be up to the maximum length of a VARCHAR, but its text (with
// the quotes) is then too long for the COLUMN_DEFAULT of the COLUMNS view.
fn test_information_schema_truncated_column_default() {
	column := Column{
		name:          Identifier{
			sub_entity_name: 'X'
		}
		typ:           new_type('CHARACTER VARYING', max_character_length, 0)
		default_value: DefaultOption(new_varchar_value('a'.repeat(max_character_length)))
	}

	assert column_default(column).string_value() == 'TRUNCATED'
}

// A CHECK_CLAUSE that's too long for the INFORMATION_SCHEMA is NULL.
fn test_information_schema_truncated_check_clause() {
	row := check_constraints_view_row('C', Table{}, 'T_CHECK_1', 'a'.repeat(max_character_length + 1))

	assert row[3].is_null
}

// column_names is only used by vorm, so it's tested directly.
fn test_table_column_names() ! {
	mut db := open(':memory:')!
	db.query('CREATE TABLE t (x INTEGER, y INTEGER GENERATED ALWAYS AS (x + 1))')!
	tables := db.catalog().schema_tables('PUBLIC')!

	assert tables.len == 1
	assert tables[0].column_names() == ['X', 'Y']
}

// The INFORMATION_SCHEMA and other virtual tables are in the catalog, so they
// can be listed like any other schema and table.
fn test_catalog_virtual_tables() ! {
	mut db := open(':memory:')!
	db.register_virtual_table('CREATE TABLE v (x INTEGER)', fn (mut t VirtualTable) ! {
		t.done()
	})!
	mut catalog := db.catalog()

	schemas := catalog.schemas()!
	assert schemas.filter(it.name == 'PUBLIC').map(it.is_virtual) == [false]
	assert schemas.filter(it.name == 'INFORMATION_SCHEMA').map(it.is_virtual) == [true]

	mut public_tables := catalog.schema_tables('PUBLIC')!.map('${it.name.entity_name} ${it.is_virtual}')
	public_tables.sort()
	assert public_tables == ['V true']
	assert catalog.schema_tables('INFORMATION_SCHEMA')!.any(it.name.entity_name == 'TABLES'
		&& it.is_virtual)
}

fn test_current_catalog_name() {
	mut db := open(':memory:')!
	assert db.current_catalog_name() == ':memory:'
}

fn test_prepared_stmt_dynamic_parameters() {
	mut db := open(':memory:')!
	mut stmt := db.prepare("VALUES ROW(?, '?', ?)")!
	assert stmt.dynamic_parameter_count() == 2

	columns := stmt.columns({
		'?1': new_integer_value(1)
		'?2': new_varchar_value('a')
	})!
	assert columns.map(it.typ.str()) == ['INTEGER', 'CHARACTER(1)', 'CHARACTER VARYING(1)']

	// A statement that doesn't return rows has no columns.
	mut create := db.prepare('CREATE TABLE t (x INT)')!
	assert create.columns({})!.len == 0

	mut explain := db.prepare('EXPLAIN VALUES 1')!
	assert explain.columns({})!.map(it.name.sub_entity_name) == ['EXPLAIN']
}

fn test_command_function() {
	mut db := open(':memory:')!
	for sql, want in {
		'ALTER SEQUENCE s RESTART':              'ALTER SEQUENCE 134'
		'ALTER TABLE t ADD COLUMN y INT':        'ALTER TABLE 4'
		'COMMIT':                                'COMMIT WORK 11'
		'DELETE FROM t':                         'DELETE WHERE 19'
		'DROP SCHEMA s RESTRICT':                'DROP SCHEMA 31'
		'DROP SEQUENCE s':                       'DROP SEQUENCE 135'
		'DROP TABLE t':                          'DROP TABLE 32'
		'INSERT INTO t (x) VALUES (1)':          'INSERT 50'
		'VALUES 1':                              'SELECT CURSOR 85'
		'ROLLBACK':                              'ROLLBACK WORK 62'
		'CREATE SCHEMA s':                       'CREATE SCHEMA 64'
		'CREATE SEQUENCE s':                     'CREATE SEQUENCE 133'
		"SET CATALOG 'c'":                       'SET CATALOG 66'
		'SET CONSTRAINTS ALL DEFERRED':          'SET CONSTRAINT 68'
		"SET SCHEMA 's'":                        'SET SCHEMA 74'
		'START TRANSACTION':                     'START TRANSACTION 111'
		'CREATE TABLE t (x INT)':                'CREATE TABLE 77'
		'UPDATE t SET x = 1':                    'UPDATE WHERE 82'
		'EXPLAIN VALUES 1':                      'EXPLAIN -1'
		'CLOSE c':                               'CLOSE CURSOR 9'
		'DECLARE c CURSOR FOR VALUES 1':         'DECLARE CURSOR -2'
		'DELETE FROM t WHERE CURRENT OF c':      'DELETE CURSOR 18'
		'FETCH c':                               'FETCH 45'
		'OPEN c':                                'OPEN 53'
		'UPDATE t SET x = 1 WHERE CURRENT OF c': 'UPDATE CURSOR 81'
	} {
		stmt := db.prepare(sql)!
		name, code := stmt.command_function()
		assert '${name} ${code}' == want, sql
	}
}

// An SQL argument of a routine invocation that's a dynamic parameter needs
// B033, as well as B031 for the dynamic parameter itself (see F812, "Basic
// flagging", in tests/flagging.sql).
fn test_features_of_routine_invocation() ! {
	mut db := open(':memory:')!
	db.register_function('twice(float) float', fn (a []Value) !Value {
		return new_double_precision_value(a[0].f64_value() * 2)
	})!

	assert db.prepare('VALUES twice(1)')!.features() == ['F641', 'F661']
	assert db.prepare('VALUES twice(?)')!.features() == ['B031', 'B033', 'F641', 'F661']
}

fn test_cast() {
	mut db := open(':memory:')!
	assert db.cast(new_varchar_value('12'), new_type('INTEGER', 0, 0))!.int_value() == 12
	assert db.cast(new_null_value(.is_integer), new_type('DATE', 0, 0))!.is_null
	assert db.cast(new_varchar_value('2026-10-26'), new_type('DATE', 0, 0))!.str() == '2026-10-26'
	assert db.cast(new_varchar_value('abc'), new_type('CHARACTER VARYING', 2, 0))!.str() == 'ab'
	assert db.cast(new_varchar_value('true'), new_type('BOOLEAN', 0, 0))!.bool_value() == .is_true
	assert db.cast(new_boolean_value(true), new_type('CHARACTER VARYING', 10, 0))!.str() == 'TRUE'
	db.cast(new_varchar_value('a'), new_type('CHARACTER VARYING', max_character_length + 1,
		0)) or {
		assert err.code() != 0
		return
	}
	assert false
}

fn test_version() {
	// Tests don't run on a release build.
	assert version() == ''
	assert version_date() == ''
	assert release_value('v0.34.0') == 'v0.34.0'
}

// A result column is unnamed when the query didn't name it (it has a name like
// COL1).
fn test_column_unnamed() {
	mut db := open(':memory:')!
	result := db.query('SELECT x, x + 1, x + 2 AS y FROM (VALUES 1) AS t (x)')!
	assert result.columns.map(it.unnamed) == [false, true, false]

	values := db.query('VALUES ROW(1, 2)')!
	assert values.columns.map(it.unnamed) == [true, true]
}

// A cursor opened by PreparedStmt.open_cursor (for the SQL/CLI) is positioned
// with position_cursor, so a positioned DELETE can change its current row.
fn test_open_cursor() ! {
	mut db := open(':memory:')!
	db.query('CREATE TABLE t (x INTEGER)')!
	db.query('INSERT INTO t (x) VALUES (1), (2), (0)')!
	db.query('START TRANSACTION')!

	mut stmt := db.prepare('SELECT x FROM t WHERE x > ?')!
	result := stmt.open_cursor('C', false, {
		'?1': new_integer_value(1)
	})!
	assert result.rows.map(it.get('X')!.int_value()) == [2]

	db.position_cursor('C', 1)!
	db.query('DELETE FROM t WHERE CURRENT OF c') or {
		assert err.code() == sqlstate_to_int('24000')
	}
	db.position_cursor('C', 0)!
	assert db.query('DELETE FROM t WHERE CURRENT OF c')!.msg == 'DELETE 1'

	// The name can't be used again until the cursor is removed.
	stmt.open_cursor('C', false, {
		'?1': new_integer_value(1)
	}) or { assert err.code() == sqlstate_to_int('42P03') }
	db.remove_cursor('C')
	db.position_cursor('C', 0) or { assert err.code() == sqlstate_to_int('34000') }

	// A cursor that can't be opened isn't declared.
	mut divide := db.prepare('SELECT 1 / x FROM t')!
	divide.open_cursor('C', false, {}) or { assert err.code() == sqlstate_to_int('22012') }
	mut all := db.prepare('SELECT x FROM t')!
	assert all.open_cursor('C', false, {})!.rows.len == 2

	// Outside of a transaction, the cursor is closed when the statement ends.
	db.query('COMMIT')!
	stmt.open_cursor('D', false, {
		'?1': new_integer_value(0)
	}) or { assert err.code() == sqlstate_to_int('24000') }
	assert all.open_cursor('D', true, {})!.rows.len == 2
}

// 14.1 <declare cursor> in a module, with OPEN, FETCH, CLOSE and positioned
// statements in its procedures.
fn test_module_cursors() ! {
	m := compile_module(module_header + 'DECLARE "c" /* FOR */ CURSOR WITH HOLD FOR SELECT x, y FROM t WHERE x > :min;
PROCEDURE o (SQLSTATE, :min INTEGER); OPEN "c";
PROCEDURE f (SQLSTATE, :x INTEGER, :y VARCHAR(5), :i SMALLINT); FETCH NEXT FROM "c" INTO :x, :y INDICATOR :i;
PROCEDURE f2 (SQLSTATE, :x INTEGER); FETCH FROM d INTO :x;
PROCEDURE f3 (SQLSTATE, :x INTEGER, :y INTEGER); FETCH "c" INTO :x, :y;
PROCEDURE cl (SQLSTATE); CLOSE "c";
PROCEDURE del (SQLSTATE); DELETE FROM t WHERE CURRENT OF "c";
PROCEDURE upd (SQLSTATE, :y VARCHAR(5)); UPDATE t SET y = :y WHERE CURRENT OF "c";
DECLARE d CURSOR FOR SELECT * FROM t;',
		'm')!
	assert m.source.contains('static const int vsql_m_cursor_count = 2;')
	assert m.source.contains('  vsql_m_begin("OPEN", 53);\n  struct vsql_m_param vsql_m_p[1] = {\n')
	assert m.source.contains('  vsql_m_open_cursor(SQLSTATE, 0, "\\"c\\"", 1, "SELECT x, y FROM t WHERE x > CAST(? AS INTEGER)", 1, vsql_m_p);\n')
	assert m.source.contains('  vsql_m_begin("FETCH", 45);\n  struct vsql_m_target vsql_m_t[2] = {\n')
	assert m.source.contains('  if (vsql_m_fetch(SQLSTATE, 0, 2, vsql_m_t)) {\n    *i = (short)vsql_m_t[1].indicator;\n  }\n')
	assert m.source.contains('  vsql_m_fetch(SQLSTATE, 1, 1, vsql_m_t);\n')
	assert m.source.contains('  vsql_m_begin("CLOSE CURSOR", 9);\n  vsql_m_close_cursor(SQLSTATE, 0);\n')
	assert m.source.contains('  vsql_m_begin("DELETE CURSOR", 18);\n  vsql_m_execute(SQLSTATE, "DELETE FROM t WHERE CURRENT OF \\"c\\"", 0, NULL);\n')
	assert m.source.contains('  vsql_m_begin("UPDATE CURSOR", 81);\n')

	// A cursor can be declared at the start of the module, and the cursors
	// aren't in a module that doesn't use them. The SQL-connections still have
	// a list of the cursors of each module, since they're shared with other
	// modules that may have cursors.
	m2 := compile_module(module_header + 'DECLARE c CURSOR FOR VALUES 1; PROCEDURE p (SQLSTATE); COMMIT;',
		'm')!
	assert !m2.source.contains('vsql_m_cursor_count')

	cursor_header := module_header + 'DECLARE c CURSOR FOR SELECT x FROM t; PROCEDURE p (SQLSTATE, :x INTEGER); '
	assert module_error(cursor_header + 'FETCH c INTO :x, :x;') == 'syntax error: procedure p: cursor C has 1 column, but there are 2 targets'
	assert module_error(module_header + 'DECLARE c CURSOR FOR SELECT x, y FROM t; PROCEDURE p (SQLSTATE, :x INTEGER); FETCH c INTO :x;') == 'syntax error: procedure p: cursor C has 2 columns, but there is 1 target'
	assert module_error(cursor_header + 'FETCH NEXT c INTO :x;') == 'syntax error: expected FROM near c'
	assert module_error(cursor_header + 'FETCH c :x;') == 'syntax error: expected INTO near :'
	assert module_error(cursor_header + 'FETCH c INTO :x x;') == 'syntax error: procedure p: unexpected near x'
	assert module_error(cursor_header + 'OPEN d;') == 'syntax error: procedure p: cursor D is not declared'
	assert module_error(cursor_header + 'CLOSE c c;') == 'syntax error: procedure p: unexpected near c'
	assert module_error(cursor_header + 'OPEN c c;') == 'syntax error: procedure p: unexpected near c'
	assert module_error(cursor_header + 'DELETE FROM t WHERE CURRENT OF d;') == 'syntax error: procedure p: cursor D is not declared'
	assert module_error(cursor_header + 'UPDATE t SET x = 1 WHERE CURRENT OF d;') == 'syntax error: procedure p: cursor D is not declared'
	assert module_error(cursor_header + 'DECLARE d CURSOR FOR VALUES 1;') == 'syntax error: procedure p: a cursor must be declared in the module, not in a procedure'
	assert module_error(module_header + 'DECLARE c CURSOR FOR SELECT x FROM t WHERE x = :y; PROCEDURE p (SQLSTATE); OPEN c;') == 'syntax error: procedure p: host parameter :y is not declared'
	assert module_error(cursor_header + 'COMMIT; DECLARE C CURSOR FOR VALUES 2;') == 'syntax error: cursor C is declared more than once'
	assert module_error(module_header + 'DECLARE c CURSOR FOR VALUES ?; PROCEDURE p (SQLSTATE); COMMIT;') == 'syntax error: a module cannot contain a dynamic parameter (?), use a host parameter (:name)'
	assert module_error(module_header + 'DECLARE c CURSOR FOR VALUES 1 FOR READ ONLY; PROCEDURE p (SQLSTATE); COMMIT;') == 'syntax error: cursor C: FOR READ ONLY and FOR UPDATE are not supported in a module'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); COMMIT; DECLARE c CURSOR FOR VALUES 1; PROCEDURE q (SQLSTATE);') == 'syntax error: a module must end with a procedure that has a statement'
	assert module_error(module_header + 'DECLARE c CURSOR VALUES 1; PROCEDURE p (SQLSTATE); COMMIT;').starts_with('syntax error')
}

// Feature B031, "Basic dynamic SQL".
fn test_module_dynamic_sql() ! {
	m := compile_module(module_header +
		'PROCEDURE h (SQLSTATE, :n INTEGER, :s VARCHAR(5)); GET DESCRIPTOR d :n = COUNT, :n = TOP_LEVEL_COUNT, :n = KEY_TYPE, :s = DYNAMIC_FUNCTION, :n = DYNAMIC_FUNCTION_CODE;
PROCEDURE g (SQLSTATE, :n INTEGER, :s VARCHAR(5), :c CHAR(3)); GET SQL DESCRIPTOR GLOBAL \' g \' VALUE :n :s = DATA, :n = INDICATOR, :c = NAME, :n = TYPE;
PROCEDURE g2 (SQLSTATE, :n INTEGER); GET DESCRIPTOR LOCAL \'g\' VALUE 2 :n = DATA;
PROCEDURE a (SQLSTATE, :n SMALLINT); ALLOCATE SQL DESCRIPTOR d WITH MAX :n;
PROCEDURE a2 (SQLSTATE); ALLOCATE DESCRIPTOR "d";
PROCEDURE de (SQLSTATE); DEALLOCATE SQL DESCRIPTOR d;
PROCEDURE sc (SQLSTATE); SET DESCRIPTOR d COUNT = -1;
PROCEDURE sv (SQLSTATE, :s VARCHAR(5)); SET DESCRIPTOR d VALUE 2 DATA = :s, CHARACTER_SET_NAME = :s, SCOPE_NAME = \'x\', LENGTH = 5, TYPE = 12, LEVEL = 0;
PROCEDURE sb (SQLSTATE, :b BOOLEAN); SET DESCRIPTOR d VALUE 1 DATA = :b;
PROCEDURE pr (SQLSTATE, :s VARCHAR(5)); PREPARE s FROM :s;
PROCEDURE pr2 (SQLSTATE); PREPARE s FROM \'SELECT 1\';
PROCEDURE dp (SQLSTATE); DEALLOCATE PREPARE s;
PROCEDURE ds (SQLSTATE); DESCRIBE s USING DESCRIPTOR d WITH NESTING;
PROCEDURE ds2 (SQLSTATE); DESCRIBE OUTPUT s USING SQL DESCRIPTOR d WITHOUT NESTING;
PROCEDURE ex (SQLSTATE); EXECUTE s;
PROCEDURE ex2 (SQLSTATE, :n INTEGER, :s VARCHAR(5), :i INTEGER); EXECUTE s INTO :n, :s INDICATOR :i USING :s :i, :n;
PROCEDURE ex3 (SQLSTATE); EXECUTE s INTO DESCRIPTOR d USING DESCRIPTOR GLOBAL \'g\';
PROCEDURE ei (SQLSTATE); EXECUTE IMMEDIATE \'DELETE FROM t\';
DECLARE c0 CURSOR FOR SELECT 1 FROM t;
DECLARE dc CURSOR WITH HOLD FOR s;
PROCEDURE o (SQLSTATE); OPEN dc;
PROCEDURE o2 (SQLSTATE, :n INTEGER); OPEN dc USING :n;
PROCEDURE f (SQLSTATE, :n INTEGER); FETCH NEXT FROM dc INTO :n;
PROCEDURE f2 (SQLSTATE); FETCH dc INTO SQL DESCRIPTOR d;
PROCEDURE cl (SQLSTATE); CLOSE dc;
PROCEDURE dl (SQLSTATE); DELETE FROM t WHERE CURRENT OF dc;
PROCEDURE up (SQLSTATE); UPDATE t SET x = 1 WHERE CURRENT OF dc;',
		'm')!
	assert m.source.contains('static const char *const vsql_m_cursor_statements[] = {NULL, "S", NULL};\n')
	assert m.source.contains('  int vsql_m_w = 0;\n  vsql_m_begin("GET DESCRIPTOR", 47);\n  struct vsql_m_descriptor *vsql_m_d = vsql_m_descriptor(SQLSTATE, "D", &vsql_m_own);\n')
	assert m.source.contains('  *n = (long)vsql_m_d->count;\n  *n = (long)vsql_m_d->top_level_count;\n  *n = (long)0;\n  vsql_m_w |= vsql_m_put(s, 5, 0, vsql_m_d->dynamic_function);\n  *n = (long)vsql_m_d->dynamic_function_code;\n')
	assert m.source.contains('  struct vsql_m_item *vsql_m_i = vsql_m_get_item(SQLSTATE, "G", NULL, (long long)*n, SQL_VARCHAR, 5, 1);\n')
	assert m.source.contains('  vsql_m_w |= vsql_m_get_data(vsql_m_i, s, SQL_VARCHAR, 5);\n  *n = (long)vsql_m_i->number[VSQL_M_INDICATOR];\n  vsql_m_w |= vsql_m_put(c, 3, 1, vsql_m_i->string[VSQL_M_NAME] == NULL ? "" : vsql_m_i->string[VSQL_M_NAME]);\n')
	assert m.source.contains('vsql_m_get_item(SQLSTATE, "G", &vsql_m_own, 2LL, SQL_INTEGER, 0, 0);\n')
	assert m.source.contains('  vsql_m_allocate_descriptor(SQLSTATE, "D", &vsql_m_own, (long long)*n);\n')
	assert m.source.contains('  vsql_m_allocate_descriptor(SQLSTATE, "d", &vsql_m_own, 100LL);\n')
	assert m.source.contains('  vsql_m_begin("DEALLOCATE DESCRIPTOR", 15);\n  vsql_m_deallocate_descriptor(SQLSTATE, "D", &vsql_m_own);\n')
	assert m.source.contains('  vsql_m_set_count(SQLSTATE, "D", &vsql_m_own, -1LL);\n')

	// - 20.5 GR 4. The components are set in a fixed order.
	assert m.source.contains('  if (vsql_m_i != NULL &&\n      vsql_m_set_number(SQLSTATE, vsql_m_i, VSQL_M_LEVEL, 0LL) &&\n      vsql_m_set_number(SQLSTATE, vsql_m_i, VSQL_M_TYPE, 12LL) &&\n      vsql_m_set_string(vsql_m_i, VSQL_M_CHARACTER_SET_NAME, s) &&\n      vsql_m_set_string(vsql_m_i, VSQL_M_SCOPE_NAME, "x") &&\n      vsql_m_set_number(SQLSTATE, vsql_m_i, VSQL_M_LENGTH, 5LL) &&\n      vsql_m_set_data(SQLSTATE, vsql_m_i, SQL_VARCHAR, 5, s)) {\n')
	assert m.source.contains('      vsql_m_set_data(SQLSTATE, vsql_m_i, SQL_BOOLEAN, 0, b)) {\n')
	assert m.source.contains('  vsql_m_begin("PREPARE", 56);\n  if (!vsql_m_string(SQLSTATE, s, 24)) {\n    return;\n  }\n  vsql_m_prepare(SQLSTATE, "S", s);\n')
	assert m.source.contains('  vsql_m_prepare(SQLSTATE, "S", "SELECT 1");\n')
	assert m.source.contains('  vsql_m_begin("DEALLOCATE PREPARE", 16);\n  vsql_m_deallocate_prepare(SQLSTATE, "S");\n')
	assert m.source.contains('  vsql_m_begin("DESCRIBE", 20);\n  vsql_m_describe(SQLSTATE, "S", "D", &vsql_m_own);\n')
	assert m.source.contains('  struct vsql_m_input vsql_m_in = {-1, NULL, NULL, NULL};\n  struct vsql_m_output vsql_m_out = {-1, NULL, NULL, NULL};\n  vsql_m_execute_prepared(SQLSTATE, "S", &vsql_m_in, &vsql_m_out);\n')
	assert m.source.contains('  struct vsql_m_input vsql_m_in = {2, vsql_m_p, NULL, NULL};\n  struct vsql_m_target vsql_m_t[2] = {\n')
	assert m.source.contains('  struct vsql_m_output vsql_m_out = {2, vsql_m_t, NULL, NULL};\n  if (vsql_m_execute_prepared(SQLSTATE, "S", &vsql_m_in, &vsql_m_out)) {\n    *i = (long)vsql_m_t[1].indicator;\n  }\n')
	assert m.source.contains('  struct vsql_m_input vsql_m_in = {0, NULL, "G", NULL};\n  struct vsql_m_output vsql_m_out = {0, NULL, "D", &vsql_m_own};\n')
	assert m.source.contains('  vsql_m_begin("EXECUTE IMMEDIATE", 43);\n  vsql_m_execute_immediate(SQLSTATE, "DELETE FROM t");\n')
	assert m.source.contains('  vsql_m_begin("DYNAMIC OPEN", 40);\n  struct vsql_m_input vsql_m_in = {-1, NULL, NULL, NULL};\n  vsql_m_open_dynamic(SQLSTATE, 1, "\\"DC\\"", 1, "S", &vsql_m_in);\n')
	assert m.source.contains('  struct vsql_m_input vsql_m_in = {1, vsql_m_p, NULL, NULL};\n  vsql_m_open_dynamic(')
	assert m.source.contains('  vsql_m_begin("DYNAMIC FETCH", 39);\n  struct vsql_m_target vsql_m_t[1] = {\n')
	assert m.source.contains('  vsql_m_fetch_dynamic(SQLSTATE, 1, &vsql_m_out);\n')
	assert m.source.contains('  struct vsql_m_output vsql_m_out = {0, NULL, "D", &vsql_m_own};\n  vsql_m_fetch_dynamic(')
	assert m.source.contains('  vsql_m_begin("DYNAMIC CLOSE", 37);\n')
	assert m.source.contains('  vsql_m_begin("DYNAMIC DELETE CURSOR", 38);\n')
	assert m.source.contains('  vsql_m_begin("DYNAMIC UPDATE CURSOR", 42);\n')

	h := module_header +
		'PROCEDURE p (SQLSTATE, :n INTEGER, :s VARCHAR(5), :r REAL); '
	prepared := " PROCEDURE q (SQLSTATE); PREPARE s FROM 'x';"
	for stmt, expected in {
		"ALLOCATE DESCRIPTOR '1 x';":                   "procedure p: '1 x' is not a valid descriptor name"
		'ALLOCATE DESCRIPTOR GLOBAL d;':                'procedure p: a descriptor name must be an identifier or a literal near d'
		'ALLOCATE DESCRIPTOR :s;':                      'procedure p: a descriptor name must be an identifier or a literal near s'
		'ALLOCATE x;':                                  'procedure p: expected DESCRIPTOR near x'
		'ALLOCATE DESCRIPTOR d WITH x;':                'expected MAX near x'
		'ALLOCATE DESCRIPTOR d WITH MAX :r;':           'procedure p: the number of occurrences :r must be SMALLINT, INTEGER or BIGINT'
		'ALLOCATE DESCRIPTOR d WITH MAX x;':            'procedure p: expected a number of occurrences near x'
		'ALLOCATE DESCRIPTOR d x;':                     'procedure p: unexpected near x'
		'GET DESCRIPTOR d :n = X;':                     'procedure p: expected a header item name near X'
		'GET DESCRIPTOR d VALUE 1 :n = X;':             'procedure p: expected a descriptor item name near X'
		'GET DESCRIPTOR d VALUE 1 n = TYPE;':           'procedure p: expected a host parameter near n'
		'GET DESCRIPTOR d VALUE 1 :s = TYPE;':          'procedure p: host parameter :s must be SMALLINT, INTEGER or BIGINT for TYPE'
		'GET DESCRIPTOR d VALUE 1 :n = NAME;':          'procedure p: host parameter :n must be CHARACTER or CHARACTER VARYING for NAME'
		'GET DESCRIPTOR d :s = COUNT;':                 'procedure p: host parameter :s must be SMALLINT, INTEGER or BIGINT for COUNT'
		'SET DESCRIPTOR d x = 1;':                      'expected COUNT near x'
		'SET DESCRIPTOR d VALUE 1 NAME = :s;':          'procedure p: NAME cannot be set'
		'SET DESCRIPTOR d VALUE 1 TYPE = 1, TYPE = 2;': 'procedure p: TYPE is set more than once'
		"SET DESCRIPTOR d VALUE 1 DATA = 'x';":         'procedure p: DATA must be set to a host parameter near x'
		'SET DESCRIPTOR d VALUE 1 TYPE = -:n;':         'procedure p: expected a value near :'
		'SET DESCRIPTOR d VALUE 1 TYPE = 1 x;':         'procedure p: unexpected near x'
		'PREPARE s :s;':                                'expected FROM near :'
		'PREPARE s FROM :s x;':                         'procedure p: unexpected near x'
		'DEALLOCATE PREPARE x;':                        'procedure p: statement X is not prepared in the module'
		'DEALLOCATE x;':                                'procedure p: expected DESCRIPTOR near x'
		'DESCRIBE INPUT s USING DESCRIPTOR d;':         'procedure p: DESCRIBE INPUT is not supported'
		'DESCRIBE s d;':                                'expected USING near d'
		'DESCRIBE s USING DESCRIPTOR d WITH x;':        'expected NESTING near x'
		'EXECUTE x;':                                   'procedure p: statement X is not prepared in the module'
		'EXECUTE s USING SQL x;':                       'expected DESCRIPTOR near x'
		'EXECUTE s INTO :x;':                           'procedure p: host parameter :x is not declared'
		'EXECUTE s USING :n x;':                        'procedure p: unexpected near x'
		'EXECUTE IMMEDIATE :s x;':                      'procedure p: unexpected near x'
		'SET SQL x;':                                   'expected DESCRIPTOR near x'
		'DELETE FROM "";':                              'procedure p: a delimited identifier cannot be empty'
		'COMMIT; DECLARE dc CURSOR FOR x;':             'cursor DC: statement X is not prepared in the module'
		'COMMIT; DECLARE dc CURSOR FOR 1;':             'expected statement name near 1'
		'FETCH dc :n; DECLARE dc CURSOR FOR s;':        'expected INTO near :'
	} {
		assert module_error(h + stmt + prepared) == 'syntax error: ${expected}', stmt
	}
	assert module_error(h + "PREPARE 1 FROM 'x';") == 'syntax error: expected statement name near 1'
}

fn embed_error(source string) string {
	precompile_c(source, 'x.sqc') or { return err.msg() }
	return ''
}

const embed_header = 'EXEC SQL BEGIN DECLARE SECTION;
char SQLSTATE[6]; long a, b = 2; char c[11];
EXEC SQL END DECLARE SECTION;
'

fn test_embed_precompile() ! {
	p := precompile_c('// EXEC SQL is not in a comment
/* EXEC SQL */ #include <stdio.h>
int main(void) {
  char *s = "EXEC SQL \\" x"; char q = \'"\';
  EXEC  SQL BEGIN DECLARE SECTION;
  char SQLSTATE[6]; // the SQLSTATE
  static const long long a = 1, b; /* two */ short d; float e;
  double f = 1.5; varchar g[ 5 ] = "a,[\\"b", h[3] = {\'x\', 0};
  EXEC SQL END DECLARE SECTION;
  EXEC SQL WHENEVER SQLEXCEPTION GO TO failed;
  EXEC SQL WHENEVER SQLWARNING GOTO warned;
  EXEC SQL WHENEVER NOT FOUND GOTO done;
  exec sql insert into "t;" (x) values (\'a;\', :a, :g INDICATOR :d, :e, :f -- ;
    , :h, :a);
  EXEC SQL DECLARE c CURSOR FOR SELECT x FROM t WHERE x = :b;
  EXEC SQL WHENEVER SQLEXCEPTION CONTINUE;
  EXEC SQL OPEN c;
failed: warned: done: return 0;
}
EXECUTE SQL x; MYEXEC SQL; EXEC SQLX; EXEC', 'x.sqc')!
	assert p.implied_module == 'MODULE LANGUAGE C SCHEMA "PUBLIC"
PROCEDURE vsql_e1 (SQLSTATE, :a BIGINT, :g CHARACTER VARYING(4), :d SMALLINT, :e REAL, :f DOUBLE PRECISION, :h CHARACTER VARYING(2));
  insert into "t;" (x) values (\'a;\', :a, :g INDICATOR :d, :e, :f -- ;
    , :h, :a);
DECLARE c CURSOR FOR SELECT x FROM t WHERE x = :b;
PROCEDURE vsql_e2 (SQLSTATE, :b BIGINT);
  OPEN c;
'
	assert p.source.contains('static void vsql_e1(char SQLSTATE[6], long long *a, char g[20], short *d, float *e, double *f, char h[12]) {')
	assert p.source.contains('#line 1 "x.sqc"\n// EXEC SQL is not in a comment\n')
	assert p.source.contains('  \n  char SQLSTATE[6]; // the SQLSTATE\n')
	assert p.source.contains('double f = 1.5; char g[20] = "a,[\\"b", h[12] = {\'x\', 0};\n')
	assert p.source.contains("  { vsql_e1(SQLSTATE, &a, g, &d, &e, &f, h); if (SQLSTATE[0] != '0' || SQLSTATE[1] > '2') goto failed; if (SQLSTATE[0] == '0' && SQLSTATE[1] == '1') goto warned; if (SQLSTATE[0] == '0' && SQLSTATE[1] == '2') goto done; }\n\n")
	assert p.source.contains("  { vsql_e2(SQLSTATE, &b); if (SQLSTATE[0] == '0' && SQLSTATE[1] == '1') goto warned; if (SQLSTATE[0] == '0' && SQLSTATE[1] == '2') goto done; }\nfailed:")
	assert !p.source.contains('#include "x.h"')
	assert !p.source.contains('vsql_m_violated')
}

// 21.2 <embedded exception declaration>: SQLSTATE and CONSTRAINT (Feature B041),
// and which declarations apply (SR 2).
fn test_embed_exceptions() ! {
	p := precompile_c(embed_header + 'EXEC SQL WHENEVER SQLSTATE (22) GOTO data;
EXEC SQL WHENEVER SQLSTATE (22, 012) GOTO zero;
EXEC SQL WHENEVER SQLSTATE(2B) GOTO dependent;
EXEC SQL WHENEVER SQLSTATE (42, P01) GO TO missing;
EXEC SQL WHENEVER CONSTRAINT c1 GOTO c1;
EXEC SQL WHENEVER CONSTRAINT s."c2" GOTO c2;
EXEC SQL WHENEVER CONSTRAINT x.s.c3 GOTO c3;
EXEC SQL WHENEVER SQLSTATE (01, 004) GOTO truncated;
EXEC SQL WHENEVER SQLSTATE (02) GOTO none;
EXEC SQL COMMIT;
EXEC SQL WHENEVER SQLSTATE (22) CONTINUE;
EXEC SQL WHENEVER CONSTRAINT c1 CONTINUE;
EXEC SQL WHENEVER SQLWARNING CONTINUE;
EXEC SQL WHENEVER NOT FOUND CONTINUE;
EXEC SQL COMMIT;
EXEC SQL WHENEVER SQLSTATE (23) GOTO integrity;
EXEC SQL COMMIT;
EXEC SQL WHENEVER CONSTRAINT c1 GOTO c1;
EXEC SQL WHENEVER SQLEXCEPTION CONTINUE;
EXEC SQL COMMIT;
',
		'x.sqc')!
	assert p.source.contains('static int vsql_m_violated(')
	assert p.source.contains('{ vsql_e1(SQLSTATE); if (vsql_m_violated(NULL, "PUBLIC", "C1")) goto c1; if (vsql_m_violated(NULL, "S", "c2")) goto c2; if (vsql_m_violated("X", "S", "C3")) goto c3; if (memcmp(SQLSTATE, "01004", 5) == 0) goto truncated; if (memcmp(SQLSTATE, "22012", 5) == 0) goto zero; if (memcmp(SQLSTATE, "42P01", 5) == 0) goto missing; if (memcmp(SQLSTATE, "02", 2) == 0) goto none; if (memcmp(SQLSTATE, "22", 2) == 0) goto data; if (memcmp(SQLSTATE, "2B", 2) == 0) goto dependent; }')
	assert p.source.contains('{ vsql_e2(SQLSTATE); if (vsql_m_violated(NULL, "S", "c2")) goto c2; if (vsql_m_violated("X", "S", "C3")) goto c3; if (memcmp(SQLSTATE, "42P01", 5) == 0) goto missing; if (memcmp(SQLSTATE, "2B", 2) == 0) goto dependent; }')
	assert p.source.contains('{ vsql_e3(SQLSTATE); if (memcmp(SQLSTATE, "42P01", 5) == 0) goto missing; if (memcmp(SQLSTATE, "23", 2) == 0) goto integrity; if (memcmp(SQLSTATE, "2B", 2) == 0) goto dependent; }')
	assert p.source.contains('{ vsql_e4(SQLSTATE); }')
}

fn test_embed_errors() ! {
	// 21.1 <embedded SQL host program>
	assert embed_error('int x;') == 'syntax error: an embedded SQL program must have an SQL statement'
	assert embed_error(embed_header + 'EXEC SQL COMMIT') == 'syntax error: line 4: EXEC SQL must end with a semicolon'
	assert embed_error(embed_header + "EXEC SQL VALUES 'a;") == "syntax error: line 4: unterminated string: 'a;"
	assert embed_error(embed_header + 'EXEC SQL /* a;') == 'syntax error: line 4: unterminated comment: /* a;'
	assert embed_error(embed_header + 'EXEC SQL BEGIN DECLARE SECTION;') == 'syntax error: line 4: END DECLARE SECTION is missing'
	assert embed_error(embed_header + 'EXEC SQL BEGIN DECLARE SECTION; EXEC SQL BEGIN DECLARE SECTION;') == 'syntax error: line 4: unexpected BEGIN DECLARE SECTION'
	assert embed_error('EXEC SQL END DECLARE SECTION;') == 'syntax error: line 1: unexpected END DECLARE SECTION'
	assert embed_error('EXEC SQL BEGIN DECLARE SECTION; EXEC SQL COMMIT;') == 'syntax error: line 1: a declare section can only contain host variable definitions'
	assert embed_error('EXEC SQL COMMIT;') == 'syntax error: line 1: SQLSTATE must be defined in a declare section before the first EXEC SQL'
	assert embed_error(embed_header + 'EXEC SQL BEGIN WORK;') == 'syntax error: line 4: unexpected BEGIN'
	assert embed_error(embed_header + 'EXEC SQL DELETE FROM t WHERE x = :z;') == 'syntax error: line 4: host variable :z is not defined'
	assert embed_error(embed_header + 'EXEC SQL COMMIT;\nEXEC SQL VALUES :a;') == 'syntax error: line 5: a query is not an SQL procedure statement, use SELECT ... INTO'
	assert embed_error(embed_header + 'EXEC SQL DECLARE SCHEMA s;') == 'syntax error: line 4: DECLARE SCHEMA and DECLARE AUTHORIZATION are not supported'
	assert embed_error(embed_header + 'EXEC SQL DECLARE c CURSOR FOR SELECT :z FROM t;') == 'syntax error: line 4: host variable :z is not defined'
	assert embed_error(embed_header + 'EXEC SQL OPEN c;') == 'syntax error: line 4: cursor C must be declared before it is opened'
	assert embed_error(embed_header + 'EXEC SQL OPEN 1;') == 'syntax error: line 4: expected a cursor name near 1'
	assert embed_error(embed_header + 'EXEC SQL "a') == 'syntax error: line 4: EXEC SQL must end with a semicolon'

	// 21.2 <embedded exception declaration>
	assert embed_error(embed_header + 'EXEC SQL WHENEVER SQLERROR CONTINUE;') == 'syntax error: line 4: expected SQLEXCEPTION, SQLWARNING, NOT FOUND, SQLSTATE or CONSTRAINT near SQLERROR'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER NOT x CONTINUE;') == 'syntax error: line 4: expected SQLEXCEPTION, SQLWARNING, NOT FOUND, SQLSTATE or CONSTRAINT near NOT'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER NOT FOUND STOP;') == 'syntax error: line 4: expected CONTINUE, GOTO or GO TO near STOP'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER NOT FOUND GOTO 1;') == 'syntax error: line 4: expected a label near 1'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER NOT FOUND CONTINUE x;') == 'syntax error: line 4: unexpected near x'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER SQLSTATE 22 CONTINUE;') == 'syntax error: line 4: expected ( near 22'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER SQLSTATE () CONTINUE;') == 'syntax error: line 4: expected SQLSTATE class code near )'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER SQLSTATE (2 2) CONTINUE;') == 'syntax error: line 4: SQLSTATE class code must be 2 digits or upper case letters: 2'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER SQLSTATE (hy) CONTINUE;') == 'syntax error: line 4: SQLSTATE class code must be 2 digits or upper case letters: hy'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER SQLSTATE (00) CONTINUE;') == 'syntax error: line 4: SQLSTATE class 00 is successful completion, which is not a condition'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER SQLSTATE (22, 01) CONTINUE;') == 'syntax error: line 4: SQLSTATE subclass code must be 3 digits or upper case letters: 01'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER SQLSTATE (22 CONTINUE;') == 'syntax error: line 4: expected ) near CONTINUE'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER CONSTRAINT 1 CONTINUE;') == 'syntax error: line 4: expected a constraint name near 1'

	// 21.4 <embedded SQL C program>
	h := 'EXEC SQL BEGIN DECLARE SECTION; char SQLSTATE[6]; '
	for definition, expected in {
		'int x;':            'unsupported host variable definition: int x'
		'const;':            'unsupported host variable definition: const'
		'long 1x;':          'unsupported host variable definition: long 1x'
		'long [2];':         'unsupported host variable definition: long [2]'
		'long a, a;':        'host variable a is defined more than once'
		'long x[3];':        'host variable x must be a number, not an array'
		'char x;':           'host variable x must be an array of at least 2 characters'
		'VARCHAR x[1];':     'host variable x must be an array of at least 2 characters'
		'char SQLSTATE[5];': 'host variable SQLSTATE is defined more than once'
	} {
		assert embed_error(h + definition + ' EXEC SQL END DECLARE SECTION;') == 'syntax error: line 1: ${expected}', definition
	}
	assert embed_error('EXEC SQL BEGIN DECLARE SECTION; char SQLSTATE[5]; EXEC SQL END DECLARE SECTION;') == 'syntax error: line 1: SQLSTATE must be char SQLSTATE[6]'
	assert embed_error('EXEC SQL BEGIN DECLARE SECTION; long SQLSTATE; EXEC SQL END DECLARE SECTION;') == 'syntax error: line 1: SQLSTATE must be char SQLSTATE[6]'
}

// constraint_violated is the constraint that a statement violated.
fn constraint_violated(mut db Connection, stmt string) string {
	db.query(stmt) or {
		c := violated_constraint(err) or { return 'none' }
		return '${c.catalog_name}.${c.schema_name}.${c.entity_name}'
	}
	return 'ok'
}

fn test_violated_constraint() ! {
	mut db := open(':memory:')!
	db.query('CREATE TABLE p (id INT PRIMARY KEY, x INT NOT NULL CONSTRAINT x_positive CHECK (x > 0))')!
	db.query('CREATE TABLE c (id INT CONSTRAINT fk REFERENCES p (id), y INT CONSTRAINT y_positive CHECK (y > 0) DEFERRABLE INITIALLY DEFERRED)')!
	db.query('INSERT INTO p (id, x) VALUES (1, 1)')!
	assert constraint_violated(mut db, 'INSERT INTO p (id, x) VALUES (2, NULL)') == ':memory:.PUBLIC.P_NOT_NULL_2'
	assert constraint_violated(mut db, 'INSERT INTO c (id, y) VALUES (2, 1)') == ':memory:.PUBLIC.FK'
	assert constraint_violated(mut db, 'INSERT INTO p (id, x) VALUES (1, 1)') == ':memory:.PUBLIC.P_PRIMARY_KEY'
	assert constraint_violated(mut db, 'INSERT INTO p (id, x) VALUES (2, 0)') == ':memory:.PUBLIC.X_POSITIVE'
	db.query('START TRANSACTION')!
	db.query('INSERT INTO c (id, y) VALUES (1, 0)')!
	assert constraint_violated(mut db, 'COMMIT') == ':memory:.PUBLIC.Y_POSITIVE'
	assert constraint_violated(mut db, 'SELECT * FROM q') == 'none'
}
