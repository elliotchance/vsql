module vsql

import os

struct SQLTest {
	setup       []string
	file_name   string
	line_number int
	stmts       []string
	expected    string
}

fn get_tests() ?[]SQLTest {
	mut tests := []SQLTest{}
	test_file_paths := os.walk_ext('tests', 'sql')
	for test_file_path in test_file_paths {
		lines := os.read_lines(test_file_path) ?

		mut stmts := []string{}
		mut expected := []string{}
		mut setup := []string{}
		mut line_number := 0
		mut stmt := ''
		mut setup_stmt := ''
		mut in_setup := false
		for line in lines {
			if line == '' {
				tests << SQLTest{setup, test_file_path, line_number, stmts, expected.join('\n')}
				stmts = []
				expected = []
				in_setup = false
			} else if line == '/* setup */' {
				in_setup = true
			} else if line.starts_with('-- ') {
				expected << line[3..]
			} else {
				if in_setup {
					setup_stmt += '\n$line'
					if line.ends_with(';') {
						setup << setup_stmt
						setup_stmt = ''
					}
				} else {
					stmt += '\n$line'
					if line.ends_with(';') {
						stmts << stmt
						stmt = ''
					}
				}
			}

			line_number++
		}

		if stmts.len > 0 {
			tests << SQLTest{setup, test_file_path, line_number, stmts, expected.join('\n')}
		}
	}

	return tests
}

fn test_all() ? {
	for test in get_tests() ? {
		path := '/tmp/test.vsql'
		if os.exists(path) {
			os.rm(path) ?
		}

		mut db := open(path) ?

		for stmt in test.setup {
			db.query(stmt) ?
		}

		mut actual := ''
		for stmt in test.stmts {
			result := db.query(stmt) or {
				actual += 'error ${sqlstate_from_int(err.code)}: $err.msg\n'
				continue
			}

			for row in result {
				mut line := ''
				for col in result.columns {
					line += '$col: ${row.get_string(col) ?} '
				}
				actual += line.trim_space() + '\n'
			}
		}

		at := 'at $test.file_name:$test.line_number:\n'
		expected := at + test.expected.trim_space()
		actual_trim := at + actual.trim_space()
		assert expected == actual_trim
	}
}
