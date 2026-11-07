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
		AggregateFunctionCount { 'COUNT(*)${filter_pstr(e.filter, params)}' }
		RoutineInvocation { e.pstr(params) }
	}
}

fn (e AggregateFunction) compile(mut c Compiler) !CompileResult {
	match e {
		AggregateFunctionCount {
			// COUNT(*) has no argument, so its filter doesn't change the query that
			// it's an aggregate of (this one).
			aggregated_columns := c.aggregated_columns
			c.aggregated_columns = []
			compile_filter(mut c, e.filter, e.pstr(c.params))!
			c.aggregated_columns = aggregated_columns

			compiled := Identifier{
				custom_id:  e.pstr(c.params)
				custom_typ: new_type('INTEGER', 0, 0)
			}.compile(mut c)!

			// An aggregate function of an outer query is calculated by that query
			// (see Subquery.plan), and is a value of its row.
			scope := c.aggregation_scope()!
			if scope >= 0 {
				// This isn't seen as an aggregate function by an enclosing one, because
				// it's a value of this query.
				//
				// ISO/IEC 9075-2:2016(E), 6.9, <set function specification>, Syntax Rules, 1
				if c.in_aggregate {
					return sqlstate_42601('nested set function: ${e.pstr(c.params)}')
				}

				c.conn.subquery_scopes[scope].aggregates << AggregateFunction(e)

				return CompileResult{
					run:          fn [compiled, scope] (mut conn Connection, data Row, params map[string]Value) !Value {
						return compiled.run(mut conn, conn.subquery_scopes[scope].row, params)!
					}
					typ:          new_type('INTEGER', 0, 0)
					contains_agg: false
				}
			}

			c.aggregates << e

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

struct AggregateFunctionCount {
	filter ?BooleanValueExpression
}

// with_filter adds the <search condition> of a <filter clause> to a general set
// function.
fn with_filter(e AggregateFunction, filter BooleanValueExpression) AggregateFunction {
	f := e as RoutineInvocation
	return RoutineInvocation{
		function_name: f.function_name
		args:          f.args
		distinct:      f.distinct
		filter:        filter
	}
}

fn filter_pstr(filter ?BooleanValueExpression, params map[string]Value) string {
	if f := filter {
		return ' FILTER (WHERE ${f.pstr(params)})'
	}

	return ''
}

// compile_filter checks the <search condition> of the <filter clause> of the
// aggregate function agg. Like the argument of an aggregate function, it can use
// any column of a grouped query, and it can't contain an aggregate function or
// a subquery (see Subquery.plan). There are no window functions.
//
// ISO/IEC 9075-2:2016(E), 6.9, <set function specification>, Syntax Rules, 5
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 8
fn compile_filter(mut c Compiler, filter ?BooleanValueExpression, agg string) ! {
	f := filter or { return }

	in_aggregate := c.in_aggregate
	c.in_aggregate = true
	defer {
		c.in_aggregate = in_aggregate
	}

	columns := c.aggregated_columns.len
	compiled := f.compile(mut c)!
	if compiled.contains_agg {
		return sqlstate_42601('nested set function: ${agg}')
	}

	for column in c.aggregated_columns[columns..] {
		if column.scope >= 0 {
			return sqlstate_42601('outer reference in FILTER: ${column.name}')
		}
	}

	if compiled.typ.typ != .is_boolean {
		return sqlstate_42804('in FILTER', 'BOOLEAN', compiled.typ.str())
	}
}

// filter_rows is the rows of a group that an aggregate function is applied to.
// If there's a <filter clause>, they're only the rows where its search condition
// is True.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 4
fn filter_rows(mut c Compiler, filter ?BooleanValueExpression, rows []Row) ![]Row {
	f := filter or { return rows }

	compiled := f.compile(mut c)!
	mut result := []Row{}
	for row in rows {
		if compiled.run(mut c.conn, row, c.params)!.bool_value() == .is_true {
			result << row
		}
	}

	return result
}

// non_null_values removes NULLs before a general set function is applied. If
// all values are NULL (or there are no values) the result will be NULL.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 7.a
fn non_null_values(values []Value) []Value {
	return values.filter(!it.is_null)
}

// distinct_values removes NULLs and duplicates for a general set function with
// DISTINCT, such as COUNT(DISTINCT x). Values are duplicates if they're equal
// with =, so 1.5 and 1.50 (or 'a' and 'a ') are the same value. The first of
// each set of duplicates is kept.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 7.b
//
// Values that are equal with = have the same PRIMARY KEY encoding, and values
// that aren't have different ones, so each value is found by its key rather
// than compared with every value already kept. The encoding depends on the type,
// so each value is cast to the declared type of the argument (typ) first.
fn distinct_values(mut conn Connection, values []Value, typ Type) ![]Value {
	mut seen := map[string]bool{}
	mut result := []Value{}
	for value in non_null_values(values) {
		mut key := new_empty_bytes()
		write_key_value(mut key, cast(mut conn, '', value, typ)!, typ.typ)
		k := key.bytes().bytestr()
		if k !in seen {
			seen[k] = true
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
