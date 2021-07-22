module vdb_test

import db
import os

struct VdbTest {
	stmts    []string
	expected string
}

fn get_tests() ?[]VdbTest {
	mut tests := []VdbTest{}
	test_file_paths := os.walk_ext('tests', 'sql')
	for test_file_path in test_file_paths {
		lines := os.read_lines(test_file_path) ?

		mut stmts := []string{}
		mut expected := ''
		for line in lines {
			if line == '' {
				tests << VdbTest{stmts, expected}
				stmts = []
				expected = ''
			} else if line.starts_with('-- ') {
				expected += line[3..] + ' \n'
			} else {
				stmts << line
			}
		}

		if stmts.len > 0 {
			tests << VdbTest{stmts, expected}
		}
	}

	return tests
}

fn test_all() ? {
	for test in get_tests() ? {
		println(test.stmts)

		path := '/tmp/test.vdb'
		if os.exists(path) {
			os.rm(path) ?
		}

		mut db := db.open(path) ?

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
