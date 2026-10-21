module vsql

// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>
//
// Specify a value computed from a collection of rows.

type AggregateFunction = AggregateFunctionCount | RoutineInvocation

fn (e AggregateFunction) pstr(params map[string]Value) string {
	return match e {
		AggregateFunctionCount { 'COUNT(*)' }
		RoutineInvocation { e.pstr(params) }
	}
}

fn (e AggregateFunction) compile(mut c Compiler) !CompileResult {
	match e {
		AggregateFunctionCount {
			c.aggregates << e

			compiled := Identifier{
				custom_id:  'COUNT(*)'
				custom_typ: new_type('INTEGER', 0, 0)
			}.compile(mut c)!

			return CompileResult{
				run:          fn [compiled] (mut conn Connection, data Row, params map[string]Value) !Value {
					return compiled.run(mut conn, data, params)!
				}
				typ:          new_type('INTEGER', 0, 0)
				contains_agg: true
			}
		}
		RoutineInvocation {
			return e.compile(mut c)!
		}
	}
}

struct AggregateFunctionCount {}

// non_null_values removes NULLs before a general set function is applied. If
// all values are NULL (or there are no values) the result will be NULL.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 7a
fn non_null_values(values []Value) []Value {
	return values.filter(!it.is_null)
}

// COUNT(ANY) INTEGER
fn func_count(values []Value) !Value {
	mut non_null := 0
	for value in values {
		if !value.is_null {
			non_null++
		}
	}

	return new_integer_value(non_null)
}

// MIN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_min(all_values []Value) !Value {
	values := non_null_values(all_values)
	if values.len == 0 {
		return new_null_value(.is_double_precision)
	}

	mut min := values[0].f64_value()
	for value in values {
		if value.f64_value() < min {
			min = value.f64_value()
		}
	}

	return new_double_precision_value(min)
}

// MAX(DOUBLE PRECISION) DOUBLE PRECISION
fn func_max(all_values []Value) !Value {
	values := non_null_values(all_values)
	if values.len == 0 {
		return new_null_value(.is_double_precision)
	}

	mut max := values[0].f64_value()
	for value in values {
		if value.f64_value() > max {
			max = value.f64_value()
		}
	}

	return new_double_precision_value(max)
}

// SUM(DOUBLE PRECISION) DOUBLE PRECISION
fn func_sum(all_values []Value) !Value {
	values := non_null_values(all_values)
	if values.len == 0 {
		return new_null_value(.is_double_precision)
	}

	mut sum := 0.0
	for value in values {
		sum += value.f64_value()
	}

	return approximate_value(sum, .is_double_precision)
}

// AVG(DOUBLE PRECISION) DOUBLE PRECISION
fn func_avg(all_values []Value) !Value {
	values := non_null_values(all_values)
	if values.len == 0 {
		return new_null_value(.is_double_precision)
	}

	mut sum := 0.0
	for value in values {
		sum += value.f64_value()
	}

	return approximate_value(sum / values.len, .is_double_precision)
}
