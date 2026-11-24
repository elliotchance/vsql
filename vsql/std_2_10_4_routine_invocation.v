module vsql

// ISO/IEC 9075-2:2023, 10.4, <routine invocation>
//
// Invoke an SQL-invoked routine.
//
// There are no SQL-invoked routines (T321), so a RoutineInvocation is always a
// built-in function (such as ABS or SUM) that's parsed with the same syntax,
// and most of the rules of 10.4 don't apply. The functions that aren't
// standard are the routines of the VSQL schema, so they can also be qualified
// by its name, such as VSQL.GCD (see find_function_in).
//
// The concepts are described by:
//
// ISO/IEC 9075-1:2023, 4.12, Routines
// ISO/IEC 9075-1:2023, 4.12.1, General routine information

struct RoutineInvocation {
	// catalog_name and schema_name are only set when the name of the function is
	// qualified, such as VSQL.GCD.
	catalog_name  string
	schema_name   string
	function_name string
	args          []ValueExpression
	// distinct is only for an aggregate function, such as COUNT(DISTINCT x),
	// see distinct_values.
	distinct bool
	// filter is the <search condition> of the <filter clause> of an aggregate
	// function, such as SUM(x) FILTER (WHERE x > 0).
	filter ?&BooleanValueExpression
}

fn (e RoutineInvocation) pstr(params map[string]Value) string {
	// The only builtin function that doesn't separate its arguments with commas
	// (see character_position_expression).
	if e.function_name == 'POSITION' && e.args.len == 2 {
		return 'POSITION(${e.args[0].pstr(params)} IN ${e.args[1].pstr(params)})'
	}

	args := e.args.map(it.pstr(params)).join(', ')
	quantifier := if e.distinct { 'DISTINCT ' } else { '' }
	return '${e.qualified_name()}(${quantifier}${args})${filter_pstr(e.filter, params)}'
}

// qualified_name is the name of the function, with the schema and catalog
// that it was qualified by, if any.
fn (e RoutineInvocation) qualified_name() string {
	mut name := e.function_name
	if e.schema_name != '' {
		name = '${requote_identifier(e.schema_name)}.${name}'
	}
	if e.catalog_name != '' {
		name = '${requote_identifier(e.catalog_name)}.${name}'
	}

	return name
}

fn (e RoutineInvocation) compile(mut c Compiler) !CompileResult {
	// A qualified name must be of a schema that exists, and only finds the
	// routines of that schema.
	//
	// ISO/IEC 9075-2:2023, 9.18, Invoking an SQL-invoked routine, Syntax Rules, 9.c.ii
	mut schema_name := ''
	if e.schema_name != '' {
		schema_name = c.conn.resolve_schema_identifier(Identifier{
			catalog_name: e.catalog_name
			schema_name:  e.schema_name
		})!.schema_name
	}

	// CONCAT and CONCAT_WS take any number of arguments (V404-08 and V404-09),
	// so they have their own compile. They're routines of the VSQL schema, so
	// they're only found in it.
	if is_concat_function(e.function_name) && schema_name in ['', vsql_schema_name] {
		return compile_concat(mut c, e)
	}

	// The arguments of an aggregate function may use any column of a grouped
	// query.
	in_aggregate := c.in_aggregate
	is_agg := c.conn.funcs.any(it.name == e.function_name && it.is_agg)
	c.in_aggregate = in_aggregate || is_agg
	aggregated_columns := c.aggregated_columns
	if is_agg {
		c.aggregated_columns = []
	}
	defer {
		c.in_aggregate = in_aggregate
		if is_agg {
			c.aggregated_columns = aggregated_columns
		}
	}

	// The column references of each argument are kept for the flagger.
	mut args := []CompileResult{}
	mut arg_columns := [][]AggregatedColumn{}
	for arg in e.args {
		columns := c.aggregated_columns.len
		args << arg.compile(mut c)!
		arg_columns << c.aggregated_columns[columns..].clone()
	}
	arg_types := c.with_argument_types(e.function_name, args).map(it.typ)
	if is_agg {
		c.flag_set_function(e, arg_columns)
		if arg_types.len > 0 {
			// A DISTINCT argument is an operand of a grouping operation, and MAX or
			// MIN is an ordering operation.
			//
			// ISO/IEC 9075-2:2023, 9.12, Grouping operations, Syntax Rules, 1.c
			// ISO/IEC 9075-2:2023, 9.14, Ordering operations, Syntax Rules, 1.d
			if e.distinct {
				check_grouping_operand(arg_types[0], 'DISTINCT argument of ${e.function_name}')!
			}
			if e.function_name in ['MAX', 'MIN'] {
				check_ordering_operand(arg_types[0], 'argument of ${e.function_name}')!
			}
		}
	}

	func_name := e.function_name

	// ABS of an interval is an <interval absolute value function>.
	if func_name == 'ABS' && arg_types.len == 1 && arg_types[0].typ.is_interval() {
		return c.compile_interval_abs(args[0])
	}

	found_func := c.conn.find_function_in(schema_name, func_name, arg_types)!
	if c.conn.flagging {
		c.conn.flagged_features << found_func.features

		// A DATE argument of a TIMESTAMP parameter needs TIMESTAMP in the type
		// precedence list of DATE.
		//
		// ISO/IEC 9075-2:2023, 9.7, Type precedence list determination, Conformance Rules, 1
		for i, t in arg_types {
			if t.typ == .is_date && found_func.arg_types[i].typ != .is_date {
				c.conn.flagged_features << 'F054'
			}
		}
	}
	// Only an aggregate function can have DISTINCT or a <filter clause>, such as
	// PRODUCT(DISTINCT x).
	if !found_func.is_agg && (e.distinct || e.filter != none) {
		return sqlstate_42601('${func_name} is not an aggregate function')
	}
	// The median of the distinct values isn't allowed, like in Oracle (V405-03).
	if found_func.name == 'MEDIAN' && e.distinct {
		return sqlstate_42601('MEDIAN cannot be used with DISTINCT')
	}
	if !found_func.is_deterministic && !found_func.is_agg {
		c.check_deterministic('non-deterministic function ${func_name}')!
		c.conn.vary_subqueries(0)
	}

	if found_func.is_agg {
		// ISO/IEC 9075-2:2023, 6.9, <set function specification>, Syntax Rules, 1
		for arg in e.args {
			if arg.compile(mut c)!.contains_agg {
				return sqlstate_42601('nested set function: ${e.pstr(c.params)}')
			}
		}

		// The columns of the filter are also aggregated, so they're used to find
		// the query that it's an aggregate of.
		compile_filter(mut c, e.filter, e.pstr(c.params))!

		typ := if func_name in binary_set_functions {
			binary_set_function_type(func_name, arg_types)
		} else {
			set_function_type(func_name, arg_types[0])
		}
		return aggregate_result(mut c, AggregateFunction(e), typ, in_aggregate)!
	}

	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 21
	if func_name == 'WIDTH_BUCKET' && arg_types[3].scale != 0 {
		return sqlstate_42883('function does not exist: ${func_name}(${arg_types.map(it.str()).join(', ')})')
	}

	if e.args.len != found_func.arg_types.len {
		return sqlstate_42883('${func_name} has ${e.args.len} ${pluralize(e.args.len, 'argument')} but needs ${found_func.arg_types.len} ${pluralize(found_func.arg_types.len, 'argument')}')
	}

	mut compiled_args := []CompileResult{}
	for i, _ in arg_types {
		compiled_args << e.args[i].compile(mut c)!
	}

	// UPPER and LOWER have the declared type of their operand (see fold_result).
	// So does INITCAP (V404-04).
	//
	// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 9
	is_fold := func_name in ['UPPER', 'LOWER', 'INITCAP'] && arg_types[0].typ.is_string()
	// SPLIT_PART (V404-07) is a CHARACTER VARYING with the length of the string,
	// like SUBSTRING, and CHR (V404-05) is a CHARACTER VARYING(1). REVERSE
	// (V404-11) has the same type as its argument, which is always the same
	// length. MAKE_INTERVAL (V402-21) has the interval type of its arguments.
	is_text := func_name in ['SPLIT_PART', 'CHR', 'REVERSE', 'MAKE_INTERVAL']
	mut return_type := if is_fold || func_name == 'REVERSE' {
		Type{arg_types[0].typ, arg_types[0].size, 0, false, false}
	} else if func_name == 'SPLIT_PART' {
		Type{.is_varchar, arg_types[0].size, 0, false, false}
	} else if func_name == 'RANDOM' && arg_types.len == 2 {
		random_range_type(arg_types[0], arg_types[1])
	} else {
		numeric_function_type(func_name, found_func.return_type, arg_types)
	}

	// The scale of ROUND or TRUNC of a NUMERIC is the number of decimal places,
	// when it's a constant (V403-02 and V403-03).
	if func_name in ['ROUND', 'TRUNC'] && e.args.len == 2
		&& return_type.typ in [.is_numeric, .is_decimal] && compiled_args[1].constant {
		places := compiled_args[1].run(mut c.conn, Row{}, c.params)!
		if !places.is_null {
			return_type = rounding_function_type(func_name, arg_types[0], places.as_int())
		}
	}
	// DATE_TRUNC (V402-20) has the type of its source, and its field is
	// checked when it's compiled.
	if func_name == 'DATE_TRUNC' && found_func.features == [vsql_date_trunc] {
		return_type = date_trunc_type(mut c, compiled_args[0], arg_types[1])!
	}
	// MAKE_INTERVAL (V402-21) is a year-month or day-time interval, depending
	// on which arguments are given.
	if func_name == 'MAKE_INTERVAL' && found_func.features == [vsql_make_interval] {
		return_type = make_interval_type(mut c, compiled_args)!
	}
	// RANDOM_BINARY(n) is a BINARY VARYING(n) when n is a constant (V403-26).
	if func_name == 'RANDOM_BINARY' && compiled_args[0].constant {
		n := compiled_args[0].run(mut c.conn, Row{}, c.params)!
		if !n.is_null && n.int_value() >= 0 && n.int_value() <= max_binary_length {
			return_type = Type{.is_varbinary, int(n.int_value()), 0, false, false}
		}
	}
	is_exact := func_name in ['ABS', 'MOD', 'FLOOR', 'CEIL', 'CEILING', 'ROUND', 'TRUNC', 'SIGN']
		&& return_type.typ in [.is_numeric, .is_decimal]

	return CompileResult{
		run:          fn [found_func, func_name, arg_types, compiled_args, is_fold, is_text, is_exact, return_type] (mut conn Connection, data Row, params map[string]Value) !Value {
			mut args := []Value{}
			for i, typ in arg_types {
				// The argument may need to be implicitly cast to the parameter type,
				// such as a SMALLINT to a DOUBLE PRECISION. The size is stripped so
				// the value isn't truncated (see implicit_cast_type).
				arg := compiled_args[i].run(mut conn, data, params)!
				mut target := typ
				param_typ := found_func.arg_types[i]
				if param_typ.typ == .is_decfloat && return_type.typ == .is_decfloat {
					// Every argument of a DECFLOAT function has the precision of the
					// result (see register_decfloat_funcs).
					target = return_type
				} else if func_name == 'RANDOM' {
					// Both arguments have the type of the result (V403-24).
					target = return_type
				} else if typ.typ != param_typ.typ && typ.typ.is_number() {
					target = implicit_cast_type(arg, param_typ)
				} else if typ.typ == .is_date && param_typ.typ != .is_date {
					// A DATE argument of a TIMESTAMP parameter (see implicit_cast_cost)
					// is cast to the TIMESTAMP.
					//
					// ISO/IEC 9075-2:2023, 9.18, Invoking an SQL-invoked routine, General Rules, 4.b
					target = param_typ
				}

				args << cast(mut conn, 'argument ${i + 1} in ${func_name}', arg, target)!
			}

			// All of the builtin scalar functions return NULL if any argument is
			// NULL. Custom functions are always called.
			if !found_func.called_on_null_input && args.any(it.is_null) {
				return Value{
					typ:     return_type
					is_null: true
				}
			}

			result := found_func.func(FunctionContext{ conn: conn }, args)!
			// The bucket after the range (count + 1) may not fit in the type of
			// the count, which is a 22003 error.
			//
			// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 17.d.ii and 17.e.ii
			if func_name == 'WIDTH_BUCKET' {
				return cast(mut conn, 'WIDTH_BUCKET', result, return_type)!
			}
			if is_fold {
				return fold_result(mut conn, result, return_type)
			}
			if is_exact {
				return with_numeric_type(result, return_type)
			}
			if is_text {
				return result.with_type(return_type)
			}

			return result
		}
		typ:          return_type
		contains_agg: compiled_args.any(it.contains_agg)
		// UPPER and LOWER can add a warning, see fold.
		constant:     found_func.is_deterministic && !is_fold
			&& compiled_args.all(it.constant)
	}.fold()
}

// fold_result gives the result of UPPER or LOWER the declared type of its
// operand. A CHARACTER result is padded, and a result that's longer than the
// maximum length is truncated, with a warning if any of the removed characters
// aren't <truncating whitespace>. A type that doesn't have a length never truncates.
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 7.g.i
// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 7.g.ii
fn fold_result(mut conn Connection, result Value, typ Type) Value {
	if typ.size == 0 {
		return result.with_type(typ)
	}

	return cast_character_to_character(mut conn, result, typ)
}
