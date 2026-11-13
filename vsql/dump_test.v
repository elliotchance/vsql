module vsql

// dump_test.v tests dumping a database with DumpOptions (see "vsql out").

import os
import strings

// dump_with is the statements of a dump, without the lines of the rows and
// columns.
fn dump_with(mut db Connection, options DumpOptions) ![]string {
	mut sb := strings.new_builder(1024)
	db.dump(mut sb, options)!

	return sb.str().split_into_lines().filter(it != '' && !it.starts_with('  ') && !it.starts_with(')')
		&& !it.starts_with('INSERT') && !it.starts_with('SELECT')).map(it.all_before(' (').trim_right(';'))
}

// The expected output of each database was loaded into that database.
fn test_dump_compat() {
	mut db := open(':memory:')!
	for stmt in split_statements(os.read_file('cmd/tests/out-compat/fixture.sql')!) {
		db.query(stmt)!
	}

	for compat, file in {
		DumpCompat.sqlite3:    'sqlite3'
		DumpCompat.mysql:      'mysql'
		DumpCompat.postgresql: 'postgresql'
	} {
		mut sb := strings.new_builder(1024)
		db.dump(mut sb, compat: compat, transaction: true)!
		assert sb.str() == os.read_file('cmd/tests/out-compat/${file}.sql')!

		mut schema := strings.new_builder(1024)
		db.dump(mut schema, compat: compat, schema_only: true)!
		output := schema.str()
		assert output.contains('CREATE TABLE')
		assert !output.contains('INSERT')
		assert !output.contains('RESTART')
		assert !output.contains('setval')
		assert !output.contains('sqlite_sequence')
		assert !output.contains('AUTO_INCREMENT =')

		mut data := strings.new_builder(1024)
		db.dump(mut data, compat: compat, data_only: true)!
		rows := data.str()
		assert rows.contains('INSERT')
		assert !rows.contains('CREATE')
		assert !rows.contains('ADD CONSTRAINT')
	}

	// A generated column that isn't kept has its values in the rows, and one that
	// is doesn't.
	mut sb := strings.new_builder(1024)
	db.dump(mut sb, compat: .postgresql, include: ['public.types'])!
	assert sb.str().contains('INSERT INTO "types" ("i", "b", "si", "bi", "r", "d", "c", "c2", "c2_more", "vc", "lv", "de", "n", "dt", "t", "tz", "ts", "tstz", "g2", "cat", "sch") OVERRIDING SYSTEM VALUE VALUES')

	// A foreign key is selected separately from its table, even in SQLite.
	mut only_table := strings.new_builder(1024)
	db.dump(mut only_table, compat: .sqlite3, include: ['foo.child', 'foo.fk2'])!
	output := only_table.str()
	assert output.contains('"fk2"')
	assert !output.contains('"fk1"')

	// An empty schema still needs to be created.
	mut schema := strings.new_builder(1024)
	db.dump(mut schema, compat: .postgresql, include: ['nothing.*'])!
	assert schema.str() == 'CREATE SCHEMA "nothing";\n\n'

	// Anything that isn't known to be the same is left out.
	columns := ['X', 'y z']
	assert DumpCompat.postgresql.expression_sql('X > 1.5e-3 AND "y z" = \'a\\b\'', columns)? == '"x" > 1.5e-3 AND "y z" = \'a\\b\''
	assert DumpCompat.mysql.expression_sql("X = 'a\\b'", columns)? == '"x" = \'a\\\\b\''
	assert DumpCompat.mysql.expression_sql('X / 2', columns) == none
	assert DumpCompat.mysql.expression_sql('NOPE(X)', columns) == none
	assert DumpCompat.mysql.expression_sql('"other" > 1', columns) == none

	// X'...' is a bit string in PostgreSQL, so a binary string is a BYTEA.
	binary := new_binary_value([u8(0x01), 0xab])
	assert binary.bytes_value() == [u8(0x01), 0xab]
	assert DumpCompat.postgresql.literal_sql(binary) == "'\\x01AB'::BYTEA"
	assert DumpCompat.sqlite3.literal_sql(binary) == "X'01AB'"
	assert DumpCompat.postgresql.type_sql(binary.typ) == 'BYTEA'
	assert DumpCompat.sqlite3.type_sql(binary.typ) == 'BLOB'
	assert DumpCompat.mysql.type_sql(new_type('BINARY VARYING', 3, 0)) == 'VARBINARY(3)'

	// A comment can't end early because of the name in it.
	assert compat_comment('a\nb\rc') == '-- a b c'
	// A name that wasn't delimited is lower case, and one that was stays the same.
	assert compat_name('FOO') == '"foo"'
	assert compat_name('Foo') == '"Foo"'
	assert compat_name('FOO BAR') == '"FOO BAR"'
	assert compat_name('a"b') == '"a""b"'
}

fn test_dump_data_and_schema_only() {
	mut db := open(':memory:')!
	for stmt in [
		'CREATE SCHEMA foo',
		'CREATE SEQUENCE foo.seq1',
		'SELECT NEXT VALUE FOR foo.seq1 FROM (VALUES 1) AS t',
		'CREATE TABLE foo.parent (id INT NOT NULL PRIMARY KEY)',
		'CREATE TABLE foo.child (pid INT, CONSTRAINT fk1 FOREIGN KEY (pid) REFERENCES foo.parent (id))',
		'INSERT INTO foo.parent (id) VALUES (1)',
		'CREATE TABLE foo.emp (id INT PRIMARY KEY, boss INT REFERENCES foo.emp)',
	] {
		db.query(stmt)!
	}

	mut schema := strings.new_builder(1024)
	db.dump(mut schema, schema_only: true)!
	schema_sql := schema.str()
	assert schema_sql.contains('CREATE SCHEMA "FOO"')
	assert schema_sql.contains('CREATE SEQUENCE "FOO"."SEQ1"')
	assert schema_sql.contains('CREATE TABLE "FOO"."PARENT"')
	assert schema_sql.contains('CONSTRAINT "FK1" FOREIGN KEY')
	// A table that references itself has its FOREIGN KEY in its CREATE TABLE when
	// there are no rows.
	assert schema_sql.contains('  FOREIGN KEY ("BOSS") REFERENCES "FOO"."EMP" ("ID")')
	assert !schema_sql.contains('ALTER TABLE')
	assert !schema_sql.contains('INSERT')
	assert !schema_sql.contains('RESTART')

	mut data := strings.new_builder(1024)
	db.dump(mut data, data_only: true)!
	data_sql := data.str()
	assert data_sql.contains('INSERT INTO "FOO"."PARENT"')
	assert data_sql.contains('ALTER SEQUENCE "FOO"."SEQ1" RESTART WITH 1')
	assert !data_sql.contains('CREATE')
	assert !data_sql.contains('ADD CONSTRAINT')

	// Loading both in that order is the same as loading the whole dump.
	mut copy := open(':memory:')!
	for stmt in split_statements(schema_sql) {
		copy.query(stmt)!
	}
	for stmt in split_statements(data_sql) {
		copy.query(stmt)!
	}
	mut whole := strings.new_builder(1024)
	db.dump(mut whole)!
	whole_sql := whole.str()
	assert whole_sql.contains('ALTER TABLE "FOO"."EMP" ADD CONSTRAINT "EMP_FOREIGN_KEY_1"')
	mut copied := strings.new_builder(1024)
	copy.dump(mut copied)!
	assert copied.str() == whole_sql

	mut sb := strings.new_builder(1024)
	db.dump(mut sb, data_only: true, schema_only: true) or {
		assert err.msg() == 'data_only and schema_only cannot be used together'
		return
	}
	assert false
}

fn test_dump_no_schema() {
	mut db := open(':memory:')!
	for stmt in [
		'CREATE SCHEMA foo',
		'CREATE SEQUENCE foo.seq1',
		"SET SCHEMA 'FOO'",
		"CREATE TABLE parent (id INT NOT NULL PRIMARY KEY, x INT CHECK (foo.parent.x > 0), y INT GENERATED ALWAYS AS (foo.parent.x + 1), z VARCHAR(20) DEFAULT 'FOO.PARENT.X')",
		'CREATE TABLE child (pid INT, CONSTRAINT fk1 FOREIGN KEY (pid) REFERENCES foo.parent (id))',
		'INSERT INTO foo.parent (id, x) VALUES (1, 2)',
		"SET SCHEMA 'PUBLIC'",
	] {
		db.query(stmt)!
	}

	for compat in [DumpCompat.vsql, .sqlite3, .mysql, .postgresql] {
		mut sb := strings.new_builder(1024)
		db.dump(mut sb, compat: compat, no_schema: true)!
		output := sb.str()
		assert !output.contains('CREATE SCHEMA')
		assert !output.contains('SET SCHEMA')
		assert !output.contains('FOO"')
		assert !output.contains('foo')
		assert !output.contains(' FOO.PARENT')
		assert !output.contains('(FOO.PARENT')
	}

	mut sb := strings.new_builder(1024)
	db.dump(mut sb, no_schema: true)!
	output := sb.str()
	assert output.contains('CREATE TABLE "PARENT" (')
	assert output.contains('CHECK (PARENT.X > 0)')
	assert output.contains('GENERATED ALWAYS AS (PARENT.X + 1)')
	assert output.contains("DEFAULT 'FOO.PARENT.X'")

	// It can be loaded into a schema that's named differently.
	mut copy := open(':memory:')!
	for stmt in split_statements(output) {
		copy.query(stmt)!
	}
	assert copy.query('SELECT y FROM parent')!.rows[0].get_int('Y')! == 3

	db.dump(mut sb, no_schema: true, create_public_schema: true) or {
		assert err.msg() == 'no_schema and create_public_schema cannot be used together'
		return
	}
	assert false
}

fn test_dump_options() {
	mut db := open(':memory:')!
	for stmt in [
		'CREATE SCHEMA foo',
		'CREATE SCHEMA nothing',
		'CREATE SEQUENCE foo.seq1',
		'CREATE TABLE foo.parent (id INT NOT NULL PRIMARY KEY)',
		'CREATE TABLE foo.child (pid INT, CONSTRAINT fk1 FOREIGN KEY (pid) REFERENCES foo.parent (id))',
		'CREATE TABLE baz (x INT)',
	] {
		db.query(stmt)!
	}
	schema_foo := 'CREATE SCHEMA "FOO"'
	schema_nothing := 'CREATE SCHEMA "NOTHING"'
	seq1 := 'CREATE SEQUENCE "FOO"."SEQ1" START WITH 1'
	child := 'CREATE TABLE "FOO"."CHILD"'
	parent := 'CREATE TABLE "FOO"."PARENT"'
	baz := 'CREATE TABLE "PUBLIC"."BAZ"'
	fk1 := 'ALTER TABLE "FOO"."CHILD" ADD CONSTRAINT "FK1" FOREIGN KEY'
	// The FOREIGN KEY made an index, which is in the output with its table, when
	// the FOREIGN KEY is too.
	fk1_index := 'CREATE INDEX "FK1" ON "FOO"."CHILD"'

	// The parent comes first, so the FOREIGN KEY is part of the CREATE TABLE of
	// the child, which also makes its index.
	assert dump_with(mut db)! == [schema_foo, seq1, parent, child, schema_nothing, baz]
	// "*.*" is the same as leaving it out.
	assert dump_with(mut db, include: ['*.*'])! == [schema_foo, seq1, parent, child, schema_nothing,
		baz]
	// Case is ignored, and an object can be any type.
	assert dump_with(mut db, include: ['foo.parent'])! == [schema_foo, parent]
	assert dump_with(mut db, include: ['FOO.SEQ?'])! == [schema_foo, seq1]
	assert dump_with(mut db, include: ['foo.fk*'])! == [schema_foo, fk1]
	assert dump_with(mut db, include: ['public.*', 'foo.child'])! == [schema_foo, child, baz]
	// The FOREIGN KEY is added at the end when the table that it references isn't
	// in the output.
	assert dump_with(mut db, include: ['foo.child', 'foo.fk1'])! == [schema_foo, child, fk1_index,
		fk1]
	// exclude is taken from what's included, and it doesn't have to match anything.
	assert dump_with(mut db, include: ['foo.*'], exclude: ['foo.fk1', '*.seq1', 'x.y'])! == [
		schema_foo,
		parent,
		child,
	]
	// A foreign key isn't left out because its table is.
	assert dump_with(mut db, exclude: ['foo.parent', 'foo.child', 'public.*'])! == [
		schema_foo,
		seq1,
		schema_nothing,
		fk1,
	]
	// A schema with nothing in it follows the schema of the patterns.
	assert dump_with(mut db, exclude: ['foo.*'])! == [schema_nothing, baz]
	assert dump_with(mut db, exclude: ['nothing.*'])! == [schema_foo, seq1, parent, child, baz]
	assert dump_with(mut db, include: ['nothing.*'])! == [schema_nothing]
	assert dump_with(mut db, exclude: ['*.*'])! == []
	// PUBLIC is still only created if it's asked for.
	assert dump_with(mut db, include: ['public.baz'], create_public_schema: true)! == [
		'CREATE SCHEMA "PUBLIC"',
		baz,
	]
	// The transaction is around everything, with or without foreign keys.
	assert dump_with(mut db, transaction: true, include: ['foo.parent'])! == [
		'START TRANSACTION',
		schema_foo,
		parent,
		'COMMIT',
	]
	assert dump_with(mut db, transaction: true, include: ['foo.fk1'])! == [
		'START TRANSACTION',
		schema_foo,
		fk1,
		'COMMIT',
	]

	for options in [
		DumpOptions{
			include: ['foo']
		},
		DumpOptions{
			exclude: ['a.b.c']
		},
		DumpOptions{
			include: ['.x']
		},
		DumpOptions{
			exclude: ['x.']
		},
	] {
		dump_with(mut db, options) or {
			assert err.msg().ends_with('must be in the form schema.name')
			continue
		}
		assert false
	}
	dump_with(mut db, include: ['nope.*']) or {
		assert err.msg() == 'nope.*: does not match anything'
		dump_with(mut db, include: ['information_schema.*']) or {
			assert err.msg() == 'information_schema.*: INFORMATION_SCHEMA cannot be included'
			return
		}
	}
	assert false
}
