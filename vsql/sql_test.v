module vsql

import math
import os
import regex
import runtime
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
	// page_size is the page size of the test's databases from its
	// "page_size" directive, or 0 for the one in sql_test_options.
	page_size int
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
		mut page_size := 0
		for line in lines {
			if line == '' {
				// A block with only a setup or comments isn't a test. A block
				// with only an expected output is kept, so that it fails.
				if stmts.len > 0 || expected.len > 0 {
					tests << SQLTest{setup, test_file_path, line_number, stmts, expected.join('\n'), show_types, show_flags, extensions, page_size}
				}
				stmts = []
				expected = []
				in_setup = false
				show_types = false
				show_flags = false
				extensions = []
				page_size = 0
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
				} else if contents.starts_with('page_size ') {
					page_size = contents[10..].int()
					if page_size <= 0 {
						panic('bad page_size directive: "${contents}"')
					}
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
					// The first line isn't after a new line, so that the line
					// numbers of a syntax error are the lines of the statement.
					stmt += if stmt == '' { line } else { '\n${line}' }
					if line.ends_with(';') {
						stmts << replace_unicode(stmt)
						stmt = ''
					}
				}
			}

			line_number++
		}

		if stmts.len > 0 {
			tests << SQLTest{setup, test_file_path, line_number, stmts, expected.join('\n'), show_types, show_flags, extensions, page_size}
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
	mut stack := []YYSymType{}
	_, _, _, features := parse_sql(stmt, mut stack) or { return [] }

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

// statement_count is how many SQL statements the test runs in each mode,
// including its setup. Each SQL statement starts with a new line, unlike the
// directives that are also in stmts.
fn (test SQLTest) statement_count() int {
	return test.setup.len + test.stmts.filter(it.starts_with('\n')).len
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
		&& !test.stmts.any(is_empty_query(it))
}

fn test_all() ! {
	filter_test, filter_line := get_test_filter()
	verbose := $env('VERBOSE')
	if $env('MEMORY') == '0' && $env('FILE') == '0' {
		return error('MEMORY=0 and FILE=0 leave nothing to test')
	}

	// The tests are split between SQL_TEST_JOBS processes (by default, one for
	// each CPU), which are this test program run again with SQL_TEST_SHARD set.
	// Processes are used rather than threads, because threads wait on each other
	// to allocate memory. A filter or VERBOSE runs every test in order in this
	// process, so the output isn't mixed up.
	tests := get_tests()!
	shard := os.getenv('SQL_TEST_SHARD')
	if shard != '' {
		parts := shard.split('/')
		// An error stops this process's tests, but the process that started it
		// still needs to know about it.
		outcome := run_sql_tests(tests, parts[0].int(), parts[1].int(), false, filter_line) or {
			SQLTestOutcome{
				failed: [err.msg()]
			}
		}
		os.write_file(os.getenv('SQL_TEST_OUTCOME'), outcome.encode())!
		// The other tests in this file are run by the process that started this
		// one. The coverage is still written, when the process exits.
		exit(0)
	}
	jobs := if verbose != '' || filter_test != '' {
		1
	} else if $env('SQL_TEST_JOBS') != '' {
		math.max($env('SQL_TEST_JOBS').int(), 1)
	} else {
		runtime.nr_cpus()
	}
	mut outcomes := []SQLTestOutcome{}
	if jobs == 1 {
		outcomes << run_sql_tests(tests, 0, 1, verbose != '', filter_line)!
	} else {
		os.mkdir_all(sql_test_dir())!
		defer {
			os.rmdir_all(sql_test_dir()) or {}
		}
		mut processes := []&os.Process{}
		for i in 0 .. jobs {
			mut env := os.environ()
			env['SQL_TEST_SHARD'] = '${i}/${jobs}'
			env['SQL_TEST_OUTCOME'] = os.join_path(sql_test_dir(), 'outcome-${i}')
			mut process := os.new_process(os.executable())
			process.set_environment(env)
			process.run()
			processes << process
		}
		for i, mut process in processes {
			process.wait()
			process.close()
			outcome_path := os.join_path(sql_test_dir(), 'outcome-${i}')
			outcomes << decode_sql_test_outcome(os.read_file(outcome_path) or {
				'failed process ${i}/${jobs} stopped with exit code ${process.code}\n'
			})
		}
	}

	// The V test summary does not include the failed assertions (only the
	// passing ones) so we keep our own count of the SQL tests.
	mut passed := 0
	mut failed := []string{}
	mut statements := 0
	mut flagged := map[string]bool{}
	for outcome in outcomes {
		passed += outcome.passed
		failed << outcome.failed
		statements += outcome.statements
		for id, _ in outcome.flagged {
			flagged[id] = true
		}
	}
	failed.sort()

	println('SQL tests: ${passed} passed, ${failed.len} failed, ${passed + failed.len} total, ${statements} statements')
	for location in failed {
		println('  FAILED ${location}')
	}
	// The asserts of the other processes aren't counted, so this catches every
	// failure.
	assert failed == []

	// Every feature that can be flagged (including the vsql extensions) must be
	// in the flags of at least one test that has the "flags" directive, so it
	// can't be missed by a test that only happens to use it. A feature that's
	// only found in an SQL-client module (such as a descriptor name) is checked
	// by test_flagging_module instead.
	if filter_test == '' {
		mut module_features := []string{}
		for _, features in flagging_modules {
			module_features << features
		}
		missing := sql_flagger_features()!.filter(it !in flagged && it !in module_features)
		assert missing == [], 'not flagged by any test with /* flags */: ${missing.join(', ')}'
	}
}

// SQLTestOutcome is the result of the tests that one process ran, see
// run_sql_tests.
struct SQLTestOutcome {
mut:
	passed     int
	failed     []string
	statements int
	flagged    map[string]bool
}

// run_sql_tests runs every jobs'th test, starting at the index first, in each
// mode.
fn run_sql_tests(tests []SQLTest, first int, jobs int, verbose bool, filter_line int) !SQLTestOutcome {
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
	defer {
		os.rmdir_all(sql_test_dir()) or {}
	}

	mut outcome := SQLTestOutcome{}
	for i := first; i < tests.len; i += jobs {
		test := tests[i]
		modes := test.modes()
		if modes.len == 0 {
			continue
		}
		through_server := test.through_server()
		mut failed_modes := []string{}
		mut skipped := false
		for mode in modes {
			// An error (rather than a failed assertion) still says which test it
			// was.
			result := run_single_test(test, verbose, filter_line, mode, through_server, port, mut
				outcome.flagged) or {
				return error('${test.file_name}:${test.line_number} (${sql_test_mode_str(mode, through_server)}): ${err}')
			}
			match result {
				.passed {}
				.failed { failed_modes << sql_test_mode_str(mode, through_server) }
				.skipped { skipped = true }
			}
		}

		if skipped {
			continue
		}
		outcome.statements += test.statement_count()
		if failed_modes.len > 0 {
			outcome.failed << '${test.file_name}:${test.line_number} (${failed_modes.join(', ')})'
		} else {
			outcome.passed++
		}
	}

	return outcome
}

// encode is how a process that ran some of the tests gives its outcome to the
// process that started it, one line for each value.
fn (outcome SQLTestOutcome) encode() string {
	mut lines := ['passed ${outcome.passed}', 'statements ${outcome.statements}']
	for location in outcome.failed {
		lines << 'failed ${location}'
	}
	for id, _ in outcome.flagged {
		lines << 'flagged ${id}'
	}

	return lines.join('\n') + '\n'
}

// decode_sql_test_outcome reads what SQLTestOutcome.encode wrote.
fn decode_sql_test_outcome(s string) SQLTestOutcome {
	mut outcome := SQLTestOutcome{}
	for line in s.split_into_lines() {
		kind, value := line.split_once(' ') or { continue }
		match kind {
			'passed' { outcome.passed = value.int() }
			'statements' { outcome.statements = value.int() }
			'failed' { outcome.failed << value }
			else { outcome.flagged[value] = true }
		}
	}

	return outcome
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

// start_sql_test_server starts the server that is shared by all of the tests.
// Each client opens the database it connected with, which is a file, or
// ":memory:" for a new database in memory. This uses the public API to embed
// the server, like an application would.
fn start_sql_test_server() !&Server {
	options := sql_test_options()
	mut server := new_server(ServerOptions{
		connect: fn [options] (database string) !&Connection {
			// A test with a "page_size" directive asks for it after the name of
			// the database, see new_sql_test_conn.
			mut db_options := options
			mut path := database
			if i := database.index(sql_test_page_size_suffix) {
				path = database[..i]
				db_options.page_size = database[i + sql_test_page_size_suffix.len..].int()
			}
			mut db := open_database(path, db_options)!
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

	mut options := sql_test_options()
	if test.page_size > 0 {
		options.page_size = test.page_size
	}

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
		// clock and time zone. "clock tick" starts at sql_test_now, but is a
		// second later each time it's read.
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

	// Every index must still have an entry for each row of its table, with the
	// values of the row. The files are opened again, because the test may have
	// used them through the server. A database that can't be opened anymore
	// (such as after a fault) is left to the test.
	disarm_faults()
	mut checked := []&Connection{}
	if mode == .on_disk {
		for path in [main_path, file_name] {
			if os.exists(path) {
				checked << open_database(path, options) or { continue }
			}
		}
	} else if db.db != unsafe { nil } {
		checked << db.db
	}
	for mut conn in checked {
		conn.check_indexes() or {
			if err is SQLStateXX001 {
				problems << err.msg()
			}
		}
		if mode == .on_disk {
			conn.close()
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

	if clock == 'tick' {
		mut ticking := &SQLTestTickingClock{}
		db.now = ticking.now
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

// SQLTestConn runs the statements of a test, either with a Connection (db) or
// through the server (client).
struct SQLTestConn {
mut:
	db     &Connection   = unsafe { nil }
	client &PGTestClient = unsafe { nil }
}

// sql_test_page_size_suffix is added to the name of the database that the
// test server opens, for the page size of a "page_size" directive.
const sql_test_page_size_suffix = '?page_size='

fn new_sql_test_conn(through_server bool, path string, options ConnectionOptions, port int) !&SQLTestConn {
	if through_server {
		database := if options.page_size == sql_test_options().page_size {
			path
		} else {
			'${path}${sql_test_page_size_suffix}${options.page_size}'
		}
		return &SQLTestConn{
			client: new_pg_test_client(port, database)!
		}
	}

	mut db := open_database(path, options)!
	db.now = sql_test_now
	register_pg_functions(mut db) or {
		db.close()
		return err
	}

	// A file that failed while it was being created doesn't have the PUBLIC
	// schema for pg_database yet, see tests/impl_storage_faults.sql.
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
