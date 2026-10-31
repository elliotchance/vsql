module vsql

// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>
//
// Specify a value computed from a collection of rows.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2016(E), 4.16 (Data analysis operations involving tables)

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
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 7.a
fn non_null_values(values []Value) []Value {
	return values.filter(!it.is_null)
}

// distinct_values removes NULLs and duplicates for a general set function with
// DISTINCT, such as COUNT(DISTINCT x). Values are duplicates if they're equal
// with =, so 1.5 and 1.50 (or 'a' and 'a ') are the same value.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 7.b
fn distinct_values(conn &Connection, values []Value) ![]Value {
	mut result := []Value{}
	for value in non_null_values(values) {
		mut is_duplicate := false
		for existing in result {
			if compare(conn, value, existing)! == .is_equal {
				is_duplicate = true
				break
			}
		}
		if !is_duplicate {
			result << value
		}
	}

	return result
}

// set_function_type is the declared type of the result of a general set
// function with an argument of type t.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 4 and 7
fn set_function_type(name string, t Type) Type {
	// The implementation-defined type of COUNT (SR 4).
	if name == 'COUNT' {
		return new_type('INTEGER', 0, 0)
	}

	// The sum of exact numbers keeps the scale (SR 7.g.ii). It has no limit on the
	// precision because the sum may need more digits than any of the values. The
	// sum of integers is a BIGINT so that it's less likely to overflow.
	if name == 'SUM' {
		return match t.typ {
			.is_smallint, .is_integer, .is_bigint { new_type('BIGINT', 0, 0) }
			.is_numeric, .is_decimal { Type{t.typ, 0, t.scale, false} }
			else { Type{t.typ, 0, 0, false} }
		}
	}

	// MAX and MIN have the type of their argument (SR 7.f). So does AVG, which
	// is allowed because an exact numeric only needs at least the same precision
	// and scale (SR 7.g.iii), and an approximate numeric only needs at least the
	// same precision (SR 7.g.iv). The average is truncated to that scale.
	return Type{t.typ, t.size, t.scale, false}
}

// eval_set_function returns the result of the general set function (such as
// SUM) for the values of one group, where t is the declared type of the
// argument.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 3.e
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 7
fn eval_set_function(mut conn Connection, name string, all_values []Value, t Type) !Value {
	values := non_null_values(all_values)
	typ := set_function_type(name, t)

	if name == 'COUNT' {
		return new_integer_value(values.len)
	}

	if values.len == 0 {
		return Value{
			typ:     typ
			is_null: true
		}
	}

	if name in ['MAX', 'MIN'] {
		// The comparison rules are the same as the comparison predicate (GR 7.d.iv).
		want := if name == 'MAX' { CompareResult.is_greater } else { CompareResult.is_less }
		mut result := values[0]
		for value in values[1..] {
			if compare(conn, value, result)! == want {
				result = value
			}
		}

		return result
	}

	// SUM or AVG. An approximate numeric is added as a DOUBLE PRECISION, and an
	// exact numeric is added exactly before it's cast to the result type, which
	// raises 22003 when the sum doesn't fit (GR 3.e and 7.d.v).
	if typ.typ in approximate_types {
		mut sum := 0.0
		for value in values {
			sum += value.f64_value()
		}
		if name == 'AVG' {
			sum /= values.len
		}

		return approximate_value(sum, typ.typ)
	}

	mut sum := values[0].as_numeric()!
	for value in values[1..] {
		sum = sum.add(value.as_numeric()!)
	}
	if name == 'AVG' {
		sum = sum.divide(new_numeric_from_string(values.len.str()))!
	}

	return cast(mut conn, name, new_numeric_value_from_numeric(sum), typ)!
}
