module vsql

// An INSERT, UPDATE or DELETE with RETURNING returns rows, and its columns are
// known when it's prepared, like a query.
fn test_returning_columns() ! {
	mut db := open(':memory:')!
	db.query('CREATE TABLE t (id INT GENERATED ALWAYS AS IDENTITY, x INT NOT NULL)')!

	mut insert := db.prepare('INSERT INTO t (x) VALUES (?) RETURNING id, x * 2 AS y')!
	assert insert.columns({
		'?1': new_integer_value(5)
	})!.map(it.name.sub_entity_name) == ['ID', 'Y']
	result := insert.query({
		'?1': new_integer_value(5)
	})!
	assert result.msg == ''
	assert result.columns.map(it.name.sub_entity_name) == ['ID', 'Y']
	for row in result {
		assert row.get_int('ID')! == 1
		assert row.get_int('Y')! == 10
	}

	mut update := db.prepare('UPDATE t SET x = 6 RETURNING *')!
	assert update.columns({})!.map(it.name.sub_entity_name) == ['ID', 'X']

	// Without RETURNING, there are no columns.
	mut delete := db.prepare('DELETE FROM t')!
	assert delete.columns({})!.len == 0
	mut create := db.prepare('CREATE TABLE u (x INT)')!
	assert create.columns({})!.len == 0

	// The names in RETURNING are resolved when it's prepared.
	mut failure := ''
	db.prepare('DELETE FROM t RETURNING z') or {
		failure = '${sqlstate_from_int(err.code())} ${err.msg()}'
	}
	assert failure == '42601 syntax error: unknown column: ":memory:".PUBLIC.Z'
}
