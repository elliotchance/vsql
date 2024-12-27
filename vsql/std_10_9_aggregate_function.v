module vsql

// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>
//
// # Function
//
// Specify a value computed from a collection of rows.
//
// # Format
//~
//~ <aggregate function> /* AggregateFunction */ ::=
//~     COUNT <left paren> <asterisk> <right paren>   -> count_all
//~   | <general set function>
//~
//~ <general set function> /* AggregateFunction */ ::=
//~     <set function type> <left paren>
//~     <value expression> <right paren>   -> general_set_function
//~
//~ <set function type> /* string */ ::=
//~     <computational operation>
//~
//~ <computational operation> /* string */ ::=
//~     AVG
//~   | MAX
//~   | MIN
//~   | SUM
//~   | COUNT

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

fn parse_count_all(asterisk string) !AggregateFunction {
	return AggregateFunctionCount{}
}

fn parse_general_set_function(name string, expr ValueExpression) !AggregateFunction {
	return RoutineInvocation{name, [expr]}
}

// COUNT(ANY) INTEGER
fn func_count(values []Value) !Value {
	mut count := 0
	for value in values {
		if !value.is_null {
			count++
		}
	}

	return new_integer_value(count)
}

// MIN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_min(values []Value) !Value {
	if values.len == 0 {
		return new_null_value(.is_double_precision)
	}

	mut min := values[0].f64_value()
	for value in values {
		// If any values are NULL, the result is also NULL.
		if value.is_null {
			return new_null_value(.is_double_precision)
		}

		if value.f64_value() < min {
			min = value.f64_value()
		}
	}

	return new_double_precision_value(min)
}

// MAX(DOUBLE PRECISION) DOUBLE PRECISION
fn func_max(values []Value) !Value {
	if values.len == 0 {
		return new_null_value(.is_double_precision)
	}

	mut max := values[0].f64_value()
	for value in values {
		// If any values are NULL, the result is also NULL.
		if value.is_null {
			return new_null_value(.is_double_precision)
		}

		if value.f64_value() > max {
			max = value.f64_value()
		}
	}

	return new_double_precision_value(max)
}

// SUM(DOUBLE PRECISION) DOUBLE PRECISION
fn func_sum(values []Value) !Value {
	if values.len == 0 {
		return new_null_value(.is_double_precision)
	}

	mut sum := 0.0
	for value in values {
		// If any values are NULL, the result is also NULL.
		if value.is_null {
			return new_null_value(.is_double_precision)
		}

		sum += value.f64_value()
	}

	return new_double_precision_value(sum)
}

// AVG(DOUBLE PRECISION) DOUBLE PRECISION
fn func_avg(values []Value) !Value {
	if values.len == 0 {
		return new_null_value(.is_double_precision)
	}

	mut sum := 0.0
	for value in values {
		// If any values are NULL, the result is also NULL.
		if value.is_null {
			return new_null_value(.is_double_precision)
		}

		sum += value.f64_value()
	}

	return new_double_precision_value(sum / values.len)
}
