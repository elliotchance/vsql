import os
import vsql

fn main() {
	os.rm('test.vsql') or {}
	example() or { panic(err) }
}

fn example() ? {
	mut db := vsql.open('test.vsql')?

	db.register_virtual_table('CREATE TABLE foo ( "num" INT, word VARCHAR (32) )', fn (mut t vsql.VirtualTable) ? {
		t.next_values([
			vsql.new_double_precision_value(1),
			vsql.new_varchar_value('hi', 0),
		])

		t.next_values([
			vsql.new_double_precision_value(2),
			vsql.new_varchar_value('there', 0),
		])

		t.done()
	})?

	explain := db.query('EXPLAIN SELECT * FROM foo')?
	for row in explain {
		assert row.get_string('EXPLAIN')? == 'VIRTUAL TABLE FOO (num INTEGER, WORD CHARACTER VARYING(32))'
	}

	result := db.query('SELECT * FROM foo')?
	for row in result {
		num := row.get_f64('num')?
		word := row.get_string('WORD')?
		println('$num $word')
	}
}
