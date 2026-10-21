module vsql

// Builtin functions return NULL when any argument is NULL, but custom functions
// must still be called (CALLED ON NULL INPUT) so they can handle NULL
// themselves.
fn test_custom_function_receives_null() ! {
	mut db := open(':memory:')!
	db.register_function('is_missing(float) float', fn (a []Value) !Value {
		return new_double_precision_value(if a[0].is_null { 1 } else { 0 })
	})!

	db.query('CREATE TABLE t (x FLOAT)')!
	db.query('INSERT INTO t (x) VALUES (NULL)')!
	db.query('INSERT INTO t (x) VALUES (1.5)')!

	mut results := []f64{}
	for row in db.query('SELECT is_missing(x) AS m FROM t')! {
		results << row.get_f64('M')!
	}

	assert results == [1.0, 0.0]
}

fn test_custom_function_with_two_arguments() ! {
	mut db := open(':memory:')!
	db.register_function('add_both(float, float) float', fn (a []Value) !Value {
		return new_double_precision_value(a[0].f64_value() + a[1].f64_value())
	})!

	mut results := []f64{}
	for row in db.query('VALUES add_both(1.5, 2)')! {
		results << row.get_f64('COL1')!
	}

	assert results == [3.5]
}

// A function is identified by its name and argument types, so another function
// with the same ones can't be registered, even if it returns a different type.
fn test_custom_function_already_exists() ! {
	mut db := open(':memory:')!
	db.register_function('foo(integer) integer', fn (a []Value) !Value {
		return new_integer_value(1)
	})!

	assert register_function_error(mut db, 'foo(integer) varchar') == '42723 duplicate function: FOO(INTEGER)'

	// The same for a builtin function, and for CHARACTER, which is the same as
	// CHARACTER VARYING.
	assert register_function_error(mut db, 'abs(double precision) double precision') == '42723 duplicate function: ABS(DOUBLE PRECISION)'
	assert register_function_error(mut db, 'char_length(character) integer') == '42723 duplicate function: CHAR_LENGTH(CHARACTER)'

	// A function with the same name and different argument types is fine.
	db.register_function('foo(varchar) varchar', fn (a []Value) !Value {
		return new_varchar_value('three')
	})!

	assert db.query('VALUES foo(5)')!.rows[0].get_string('COL1')! == '1'
	assert db.query("VALUES foo('x')")!.rows[0].get_string('COL1')! == 'three'
}

fn register_function_error(mut db Connection, prototype string) string {
	db.register_function(prototype, fn (a []Value) !Value {
		return new_integer_value(0)
	}) or { return '${sqlstate_from_int(err.code())} ${err.msg()}' }

	return ''
}

// A prototype that can't be parsed, or has a type that doesn't exist, is an
// error.
fn test_custom_function_bad_prototype() ! {
	mut db := open(':memory:')!
	assert register_function_error(mut db, 'foo(nosuchtype) integer') == '42601 syntax error: unknown type: NOSUCHTYPE'
	assert register_function_error(mut db, 'foo(integer) nosuchtype') == '42601 syntax error: unknown type: NOSUCHTYPE'
	assert register_function_error(mut db, 'foo') == '42601 syntax error: invalid function prototype: foo'
	assert register_function_error(mut db, 'foo(integer)') == '42601 syntax error: invalid function prototype: foo(integer)'
	assert register_function_error(mut db, 'foo integer) integer') == '42601 syntax error: invalid function prototype: foo integer) integer'
	assert register_function_error(mut db, '(integer) integer') == '42601 syntax error: invalid function prototype: (integer) integer'
}
