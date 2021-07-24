module vsql

import os

struct SQLTest {
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
		mut expected := ''
		mut line_number := 0
		for line in lines {
			if line == '' {
				tests << SQLTest{test_file_path, line_number, stmts, expected}
				stmts = []
				expected = ''
			} else if line.starts_with('-- ') {
				expected += line[3..] + ' \n'
			} else {
				stmts << line
			}

			line_number++
		}

		if stmts.len > 0 {
			tests << SQLTest{test_file_path, line_number, stmts, expected}
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

		mut actual := ''
		for stmt in test.stmts {
			result := db.query(stmt) or {
				actual += 'error: $err\n'
				continue
			}

			for row in result {
				for col in result.columns {
					actual += '$col: ${row.get_string(col)} '
				}
				actual += '\n'
			}
		}

		at := 'at $test.file_name:$test.line_number:\n'
		expected := at + test.expected.trim_space()
		actual_trim := at + actual.trim_space()
		assert expected == actual_trim
	}
}
