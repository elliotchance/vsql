module vsql

// function_test.v tests custom functions (register_function) and the clock.

import time

// A custom function that returns a NUMERIC has the type it's registered with,
// even if it has the name of a builtin numeric function, and it may return NULL.
fn test_custom_function_returns_numeric() ! {
	mut db := open(':memory:')!
	db.register_function('half(numeric) numeric', fn (_ FunctionContext, a []Value) !Value {
		return new_numeric_value('${a[0].numeric_value().f64() / 2}')
	})!
	db.register_function('abs(varchar) numeric', fn (_ FunctionContext, a []Value) !Value {
		return new_null_value(.is_numeric)
	})!

	assert db.query('VALUES half(5)')!.rows[0].get_string('COL1')! == '2.5'
	assert db.query("VALUES abs('x')")!.rows[0].get_null('COL1')!
}

// Builtin functions return NULL when any argument is NULL, but custom functions
// must still be called (CALLED ON NULL INPUT) so they can handle NULL
// themselves.
fn test_custom_function_receives_null() ! {
	mut db := open(':memory:')!
	db.register_function('is_missing(float) float', fn (_ FunctionContext, a []Value) !Value {
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
	db.register_function('add_both(float, float) float', fn (_ FunctionContext, a []Value) !Value {
		return new_double_precision_value(a[0].f64_value() + a[1].f64_value())
	})!

	mut results := []f64{}
	for row in db.query('VALUES add_both(1.5, 2)')! {
		results << row.get_f64('COL1')!
	}

	assert results == [3.5]
}

// A custom function is NOT DETERMINISTIC, so it can't be used in a CHECK
// constraint.
fn test_custom_function_in_check_constraint() ! {
	mut db := open(':memory:')!
	db.register_function('double_it(integer) integer', fn (_ FunctionContext, a []Value) !Value {
		return new_integer_value(int(a[0].int_value() * 2))
	})!

	db.query('CREATE TABLE t (x INTEGER CHECK (double_it(x) > 0))') or {
		assert err.msg() == 'syntax error: non-deterministic function DOUBLE_IT cannot be used in a CHECK constraint'
		return
	}
	assert false
}

struct SQLTestCallCounter {
mut:
	calls int
}

// A custom function is NOT DETERMINISTIC, so a subquery that uses it is
// evaluated for each row, even though it doesn't refer to the outer query. A
// subquery without one is only evaluated once for the statement.
fn test_custom_function_in_subquery() ! {
	mut db := open(':memory:')!
	mut counter := &SQLTestCallCounter{}
	db.register_function('next_call(integer) integer', fn [mut counter] (_ FunctionContext, a []Value) !Value {
		counter.calls++
		return new_integer_value(counter.calls)
	})!

	db.query('CREATE TABLE t (x INTEGER)')!
	db.query('INSERT INTO t (x) VALUES (1), (2), (3)')!

	mut results := []int{}
	for row in db.query('SELECT x + (VALUES next_call(0)) AS c FROM t')! {
		results << row.get_int('C')!
	}
	assert results == [2, 4, 6]

	results = []
	for row in db.query('SELECT x + (SELECT MAX(x) FROM t) AS c FROM t')! {
		results << row.get_int('C')!
	}
	assert results == [4, 5, 6]
}

// A function is identified by its name and argument types, so another function
// with the same ones can't be registered, even if it returns a different type.
fn test_custom_function_already_exists() ! {
	mut db := open(':memory:')!
	db.register_function('foo(integer) integer', fn (_ FunctionContext, a []Value) !Value {
		return new_integer_value(1)
	})!

	assert register_function_error(mut db, 'foo(integer) varchar') == '42723 duplicate function: FOO(INTEGER)'

	// The same for a builtin function, and for CHARACTER, which is the same as
	// CHARACTER VARYING.
	assert register_function_error(mut db, 'abs(double precision) double precision') == '42723 duplicate function: ABS(DOUBLE PRECISION)'
	assert register_function_error(mut db, 'char_length(character) integer') == '42723 duplicate function: CHAR_LENGTH(CHARACTER)'

	// A function with the same name and different argument types is fine.
	db.register_function('foo(varchar) varchar', fn (_ FunctionContext, a []Value) !Value {
		return new_varchar_value('three')
	})!

	assert db.query('VALUES foo(5)')!.rows[0].get_string('COL1')! == '1'
	assert db.query("VALUES foo('x')")!.rows[0].get_string('COL1')! == 'three'
}

fn register_function_error(mut db Connection, prototype string) string {
	db.register_function(prototype, fn (_ FunctionContext, a []Value) !Value {
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
	assert register_function_error(mut db, 'a.b.c.d(integer) integer') == '42602 invalid identifier: a.b.c.d'
	assert register_function_error(mut db, '"foo(integer) integer') == '42602 invalid identifier chain: "foo'
}

// An SQL argument of a routine invocation that's a dynamic parameter needs
// B033, as well as B031 for the dynamic parameter itself (see F812, "Basic
// flagging", in tests/std_1_8_5_flagging.sql).
// NOW() is always CURRENT_TIMESTAMP. A function with that name is called by
// quoting it.
// NOW() is a builtin function, so another one with the same arguments is a
// duplicate.
fn test_registered_now_function() ! {
	mut db := open(':memory:')!
	assert register_function_error(mut db, 'now() float') == '42723 duplicate function: NOW()'
	assert db.query('VALUES NOW()')!.columns[0].typ.str() == 'TIMESTAMP(6) WITH TIME ZONE'
}

// NOW() reads the wall clock each time it's called, while CURRENT_TIMESTAMP is
// the time that the statement started.
fn test_now_reads_the_clock() ! {
	mut db := open(':memory:')!
	mut counter := &SQLTestCallCounter{}
	db.now = fn [mut counter] () (time.Time, i16) {
		counter.calls++
		now, offset := sql_test_now()
		return now.add_seconds(counter.calls), offset
	}

	row := db.query('VALUES (NOW(), NOW(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)')!.rows[0]
	assert row.get_string('COL1')! != row.get_string('COL2')!
	assert row.get_string('COL1')! > row.get_string('COL3')!
	assert row.get_string('COL2')! > row.get_string('COL3')!
	assert row.get_string('COL3')! == row.get_string('COL4')!
}

// A function gets the statement, session and database values from its
// FunctionContext.
fn test_function_context() ! {
	mut db := open(':memory:')!
	db.now = sql_test_now
	db.register_function('context_values() varchar', fn (ctx FunctionContext, _ []Value) !Value {
		now, offset := ctx.statement_timestamp()
		return new_varchar_value('${ctx.current_timestamp()!.str()} ${now.unix()} ${offset} ${ctx.current_catalog()} ${ctx.current_schema()} ${ctx.in_transaction()} ${ctx.version() == version()}')
	})!

	now, offset := sql_test_now()
	expected := '${db.query('VALUES CURRENT_TIMESTAMP')!.rows[0].get_string('COL1')!} ${now.unix()} ${offset} :memory: PUBLIC'
	assert db.query('VALUES context_values()')!.rows[0].get_string('COL1')! == '${expected} false true'
	db.query('START TRANSACTION')!
	assert db.query('VALUES context_values()')!.rows[0].get_string('COL1')! == '${expected} true true'
}
