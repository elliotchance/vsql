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
