import os
import vsql

fn main() {
	os.rm('test.vsql') or {}
	example() or { panic(err) }
}

fn example() ! {
	mut db := vsql.open('test.vsql')!

	db.query('SELECT * FROM bar') or {
		sqlstate := vsql.sqlstate_from_int(err.code())
		println('${sqlstate}: ${err.msg()}')
		// 42P01: no such table: BAR

		if err.code() == vsql.sqlstate_to_int('42P01') {
			println('table does not exist')
		}
	}

	db.query('SELECT * FROM bar') or {
		match err {
			vsql.SQLState42P01 { // 42P01 = table not found
				println("I knew '${err.entity_name}' did not exist!")
			}
			else {
				panic(err)
			}
		}
	}

	db.query('SELECT * FROM bar') or {
		if err.code() >= vsql.sqlstate_to_int('42000')
			&& err.code() <= vsql.sqlstate_to_int('42ZZZ') {
			println('Class 42 — Syntax Error or Access Rule Violation')
		}
	}
}
