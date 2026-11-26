module vsql

// V412: GENERATE_SERIES.
//
// GENERATE_SERIES(start, stop [, step]) is a table in FROM with one row for
// each value from start to stop (inclusive), going up by step (1 by default).
// It's a table function of PostgreSQL and DuckDB. The standard's table functions
// (T326) are separate, and use "TABLE (...)".
//
// It isn't LATERAL: the arguments can't reference the other tables of the same
// FROM, but can reference the columns of an outer query.

// TableFunction is a function call in FROM, such as "GENERATE_SERIES(1, 3)".
// GENERATE_SERIES is the only one.
struct TableFunction {
	name Identifier
	args []ValueExpression
}

fn (e TableFunction) pstr(params map[string]Value) string {
	return '${e.name}(${e.args.map(it.pstr(params)).join(', ')})'
}

// table_function_plan plans a function in FROM, such as GENERATE_SERIES(1, 3)
// AS t (n). Without a correlation name, the range variable has the name of the
// function.
fn table_function_plan(mut plan Plan, f TableFunction, correlation Correlation, params map[string]Value, mut conn Connection) !Table {
	if f.name.entity_name != 'GENERATE_SERIES' {
		return sqlstate_42883('table function does not exist: ${f.name}')
	}
	if conn.flagging {
		conn.flagged_features << vsql_generate_series
	}

	table_name := if correlation.name.sub_entity_name != '' {
		correlation.name
	} else {
		new_column_identifier('GENERATE_SERIES')!
	}

	operation := new_generate_series_operation(f.args, params, mut conn)!
	return add_correlation_plan(mut plan, table_name, Plan{
		operations: [PlanOperation(operation)]
	}, correlation, params, mut conn)!
}

struct GenerateSeriesOperation {
	args   []ValueExpression
	params map[string]Value
	typ    Type
	// step_typ is the type the step is cast to: the type of the column for a
	// number, or the type of the interval for a datetime.
	step_typ Type
mut:
	conn &Connection
}

fn generate_series_compiler(conn &Connection, params map[string]Value) Compiler {
	return Compiler{
		conn:                   conn
		params:                 params
		next_value_not_allowed: 'GENERATE_SERIES'
		aggregation_query:      values_aggregation_query(conn)
	}
}

// new_generate_series_operation finds the type of the column from the
// arguments. For numbers, it's the combined type of all of them (9.5), which
// must be exact, so GENERATE_SERIES(1, 2, 0.5) is a NUMERIC. For a DATE or a
// TIMESTAMP, the step is required and must be an interval, and the column has
// the type of the datetime plus the interval.
fn new_generate_series_operation(args []ValueExpression, params map[string]Value, mut conn Connection) !&GenerateSeriesOperation {
	mut c := generate_series_compiler(conn, params)
	mut types := []Type{}
	for arg in args {
		compiled := arg.compile(mut c)!
		if compiled.contains_agg {
			return sqlstate_42601('an aggregate function cannot be used in GENERATE_SERIES')
		}
		types << compiled.typ
	}

	not_exist := sqlstate_42883('function does not exist: GENERATE_SERIES(${types.map(it.str()).join(', ')})')
	if types.len < 2 || types.len > 3 {
		return not_exist
	}

	mut typ := combine_types(types[0], types[1]) or { return not_exist }
	mut step_typ := typ
	if typ.typ.is_number() {
		if types.len == 3 {
			typ = combine_types(typ, types[2]) or { return not_exist }
			step_typ = typ
		}
		if typ.typ !in [.is_smallint, .is_integer, .is_bigint, .is_numeric, .is_decimal] {
			return not_exist
		}
	} else if typ.typ in [.is_date, .is_timestamp_without_time_zone, .is_timestamp_with_time_zone] {
		if types.len != 3 || !types[2].typ.is_interval() {
			return not_exist
		}
		typ = datetime_plus_interval_type(typ, types[2]) or { return not_exist }
		step_typ = types[2]
	} else {
		return not_exist
	}

	return &GenerateSeriesOperation{args, params, Type{typ.typ, typ.size, typ.scale, false, false}, step_typ, conn}
}

fn (o &GenerateSeriesOperation) str() string {
	return 'GENERATE SERIES (${o.columns()}) = ${o.args.map(it.pstr(o.params)).join(', ')}'
}

fn (o &GenerateSeriesOperation) columns() Columns {
	return [
		Column{
			name: Identifier{
				sub_entity_name: 'GENERATE_SERIES'
			}
			typ:  o.typ
		},
	]
}

// execute returns a row for each value. It has no rows when any argument is
// NULL, or when the step goes away from stop. A step of zero is an error, since
// it would never end.
fn (mut o GenerateSeriesOperation) execute(_ []Row) ![]Row {
	o.conn.begin_row()
	mut c := generate_series_compiler(o.conn, o.params)
	mut values := []Value{}
	for arg in o.args {
		v := arg.compile(mut c)!.run(mut o.conn, Row{}, o.params)!
		if v.is_null {
			return []Row{}
		}
		values << v
	}

	start := convert_to_combined_type(mut o.conn, 'in GENERATE_SERIES', values[0], o.typ)!
	stop := convert_to_combined_type(mut o.conn, 'in GENERATE_SERIES', values[1], o.typ)!
	step := if values.len == 3 {
		convert_to_combined_type(mut o.conn, 'in GENERATE_SERIES', values[2], o.step_typ)!
	} else {
		cast(mut o.conn, '', new_integer_value(1), o.typ)!
	}

	zero := if o.typ.typ.is_number() {
		cast(mut o.conn, '', new_integer_value(0), o.typ)!
	} else {
		new_interval_value(step.typ, 0)
	}
	direction := compare(o.conn, step, zero)!
	if direction == .is_equal {
		return sqlstate_22023('GENERATE_SERIES step cannot be zero')
	}
	// A value is past stop when it compares with stop the same way that step
	// compares with zero.
	past := direction

	mut rows := []Row{}
	mut value := start
	for i := i64(1); compare(o.conn, value, stop)! != past; i++ {
		rows << Row{
			data: new_row_data_from_map({
				'GENERATE_SERIES': value
			})
		}

		value = o.next_value(start, value, step, i) or {
			// An exact number that doesn't fit in the type is past stop, which
			// does fit.
			if o.typ.typ.is_number() && err is SQLState22003 {
				break
			}
			return err
		}
	}

	return rows
}

// next_value is value plus step for a number. For a datetime, it's start plus i
// times step, so that adding months always keeps the day of start, and it's
// 22008 (datetime field overflow) when that day isn't in the month, the same as
// adding the interval to start.
fn (mut o GenerateSeriesOperation) next_value(start Value, value Value, step Value, i i64) !Value {
	if o.typ.typ.is_number() {
		next := eval_binary(mut o.conn, value, '+', step)!
		return convert_to_combined_type(mut o.conn, 'in GENERATE_SERIES', next, o.typ)!
	}

	// i times step can't overflow, since the value before it was a datetime
	// (between the years 1 and 9999), and is far from the limits of an i64.
	return datetime_plus_interval(start, new_interval_value(step.typ, i * step.int_value()),
		false, o.typ)!
}
