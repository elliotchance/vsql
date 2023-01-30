import os
import vsql

fn main() {
	os.rm('test.vsql') or {}
	example() or { panic(err) }
}

fn example() ! {
	mut db := vsql.open('test.vsql')!

	// The "public" schema is available by default, but we can create more.
	db.query('CREATE TABLE foo (x DOUBLE PRECISION)')!
	db.query('CREATE TABLE public.bar (x INT)')!
	db.query('CREATE SCHEMA my_schema')!
	db.query('CREATE TABLE my_schema.baz (x BOOLEAN)')!

	mut actual := []string{}
	for schema in db.schemas()! {
		mut table_names := []string{}
		for table in db.schema_tables(schema.name)! {
			table_names << table.name
		}

		println('${schema.name} has ${table_names}')
		actual << '${schema.name} has ${table_names}'
	}

	assert actual == [
		"PUBLIC has ['PUBLIC.FOO', 'PUBLIC.BAR']",
		"MY_SCHEMA has ['MY_SCHEMA.BAZ']",
	]
}
