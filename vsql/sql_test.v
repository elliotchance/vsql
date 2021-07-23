module vsql

import os

struct SQLTest {
	stmts    []string
	expected string
}

fn get_tests() ?[]SQLTest {
	mut tests := []SQLTest{}
	test_file_paths := os.walk_ext('tests', 'sql')
	for test_file_path in test_file_paths {
		lines := os.read_lines(test_file_path) ?

		mut stmts := []string{}
		mut expected := ''
		for line in lines {
			if line == '' {
				tests << SQLTest{stmts, expected}
				stmts = []
				expected = ''
			} else if line.starts_with('-- ') {
				expected += line[3..] + ' \n'
			} else {
				stmts << line
			}
		}

		if stmts.len > 0 {
			tests << SQLTest{stmts, expected}
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

		assert test.expected.trim_space() == actual.trim_space()
	}
}
