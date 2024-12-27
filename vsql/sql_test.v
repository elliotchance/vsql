module vsql

import os
import regex
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
				} else if contents.starts_with('create_catalog ') {
					stmts << replace_unicode(contents)
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

fn test_all() ! {
	filter_test, filter_line := get_test_filter()
	verbose := $env('VERBOSE')
	for test in get_tests()! {
		run_single_test(test, verbose != '', filter_line)!
	}
}

@[assert_continues]
fn run_single_test(test SQLTest, verbose bool, filter_line int) ! {
	if filter_line != 0 && test.line_number != filter_line {
		if verbose {
			println('SKIP ${test.file_name}:${test.line_number}\n')
		}

		return
	}

	if verbose {
		println('BEGIN ${test.file_name}:${test.line_number}')
		defer {
			println('END ${test.file_name}:${test.line_number}\n')
		}
	}

	mut options := default_connection_options()

	mut db := open_database(':memory:', options)!
	db.now = fn () (time.Time, i16) {
		return time.new(time.Time{
			year:       2022
			month:      7
			day:        4
			hour:       14
			minute:     5
			second:     3
			nanosecond: 120056000
		}), 300
	}
	register_pg_functions(mut db)!

	// If a test needs multiple connections we cannot rely on ":memory:".
	// The default connection is called "main". The docs explain that "main"
	// should not be referenced in tests and the "connection" directive must
	// be the first line in the test.
	mut connections := map[string]&Connection{}
	mut current_connection_name := ''

	file_name := 'test.vsql'
	if os.exists(file_name) {
		os.rm(file_name) or { return }
	}

	for stmt in test.setup {
		if verbose {
			println('  ${stmt.trim_space()}')
		}

		mut prepared := db.prepare(stmt)!
		prepared.query(test.params)!
	}

	mut actual := ''
	for stmt in test.stmts {
		if stmt.starts_with('create_catalog ') {
			catalog_name := stmt[15..]
			db.add_catalog(catalog_name, ':memory:', options)!
			continue
		}

		if stmt.starts_with('connection ') {
			connection_name := stmt[11..]
			if connection_name !in connections {
				mut conn := open_database(file_name, options)!
				register_pg_functions(mut conn)!
				connections[connection_name] = conn
			}

			db = connections[connection_name] or { panic('unknown connection: ${connection_name}') }
			current_connection_name = connection_name
			continue
		}

		if verbose {
			println('  ${stmt.trim_space()}')
		}

		mut prepared := db.prepare(stmt) or {
			actual += 'error ${sqlstate_from_int(err.code())}: ${err.msg()}\n'
			continue
		}
		db.clear_warnings()
		result := prepared.query(test.params) or {
			if current_connection_name == '' {
				actual += 'error ${sqlstate_from_int(err.code())}: ${err.msg()}\n'
			} else {
				actual += '${current_connection_name}: error ${sqlstate_from_int(err.code())}: ${err.msg()}\n'
			}

			continue
		}

		for err in db.warnings {
			actual += 'warning ${sqlstate_from_int(err.code())}: ${err.msg()}\n'
		}

		for row in result {
			mut line := ''

			if current_connection_name != '' {
				line = '${current_connection_name}: '
			}

			for col in result.columns {
				line += '${col.name.sub_entity_name}: ${row.get_string(col.name.sub_entity_name)!} '
				if test.show_types {
					line += '(${row.get(col.name.sub_entity_name)!.typ}) '
				}
			}
			actual += line.trim_space() + '\n'
		}
	}

	at := 'at ${test.file_name}:${test.line_number}:\n'
	mut expected := at + test.expected.trim_space()
	actual_trim := at + actual.trim_space()

	assert expected == actual_trim
}

// Make sure any non-keywords (operators, literals, etc) are replaced in error
// messages.
fn test_cleanup_yacc_error() {
	mut msg := ''
	for tok_name in yy_toknames {
		if tok_name.starts_with('OPERATOR_') || tok_name.starts_with('LITERAL_') {
			msg += ' ' + tok_name
		}
	}
	result := cleanup_yacc_error(msg)
	assert !result.contains('OPERATOR_')
	assert !result.contains('LITERAL_')
}
