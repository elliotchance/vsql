module vsql

// ISO/IEC 9075-2:2016(E), 10.4, <routine invocation>
//
// Invoke an SQL-invoked routine.
//
// The concepts are described by:
//
// ISO/IEC 9075-1:2003(E), 4.10, Routines
// ISO/IEC 9075-1:2003(E), 4.10.1, General routine information

struct RoutineInvocation {
	function_name string
	args          []ValueExpression
	// distinct is only for an aggregate function, such as COUNT(DISTINCT x),
	// see distinct_values.
	distinct bool
}

fn (e RoutineInvocation) pstr(params map[string]Value) string {
	// The only builtin function that doesn't separate its arguments with commas
	// (see character_position_expression).
	if e.function_name == 'POSITION' && e.args.len == 2 {
		return 'POSITION(${e.args[0].pstr(params)} IN ${e.args[1].pstr(params)})'
	}

	args := e.args.map(it.pstr(params)).join(', ')
	quantifier := if e.distinct { 'DISTINCT ' } else { '' }
	return '${e.function_name}(${quantifier}${args})'
}

fn (e RoutineInvocation) compile(mut c Compiler) !CompileResult {
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

	mut arg_types := []Type{}
	for arg in e.args {
		arg_types << arg.compile(mut c)!.typ
	}

	func_name := e.function_name

	found_func := c.conn.find_function(func_name, arg_types)!
	if !found_func.is_deterministic && !found_func.is_agg {
		c.check_deterministic('non-deterministic function ${func_name}')!
	}

	if found_func.is_agg {
		// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 1
		for arg in e.args {
			if arg.compile(mut c)!.contains_agg {
				return sqlstate_42601('nested set function: ${e.pstr(c.params)}')
			}
		}

		compiled := Identifier{
			custom_id:  e.pstr(c.params)
			custom_typ: set_function_type(func_name, arg_types[0])
		}.compile(mut c)!

		// An aggregate function of an outer query is calculated by that query
		// (see Subquery.plan), and is a value of its row.
		scope := c.aggregation_scope()!
		if scope >= 0 {
			c.conn.subquery_scopes[scope].aggregates << AggregateFunction(e)

			return CompileResult{
				run:          fn [compiled, scope] (mut conn Connection, data Row, params map[string]Value) !Value {
					return compiled.run(mut conn, conn.subquery_scopes[scope].row, params)!
				}
				typ:          compiled.typ
				contains_agg: false
			}
		}

		c.aggregates << AggregateFunction(e)

		return compiled.with_agg(true)
	}

	if e.args.len != found_func.arg_types.len {
		return sqlstate_42883('${func_name} has ${e.args.len} ${pluralize(e.args.len, 'argument')} but needs ${found_func.arg_types.len} ${pluralize(found_func.arg_types.len, 'argument')}')
	}

	mut compiled_args := []CompileResult{}
	for i, _ in arg_types {
		compiled_args << e.args[i].compile(mut c)!
	}

	// UPPER and LOWER have the declared type of their operand.
	//
	// ISO/IEC 9075-2:2016(E), 6.32, <string value function>, Syntax Rules, 9
	is_fold := func_name in ['UPPER', 'LOWER'] && arg_types[0].typ.is_string()
	return_type := if is_fold {
		Type{arg_types[0].typ, arg_types[0].size, 0, false}
	} else {
		numeric_function_type(func_name, found_func.return_type, arg_types)
	}
	is_exact := func_name in ['ABS', 'MOD', 'FLOOR', 'CEIL', 'CEILING']
		&& return_type.typ in [.is_numeric, .is_decimal]

	return CompileResult{
		run:          fn [found_func, func_name, arg_types, compiled_args, is_fold, is_exact, return_type] (mut conn Connection, data Row, params map[string]Value) !Value {
			mut args := []Value{}
			for i, typ in arg_types {
				// The argument may need to be implicitly cast to the parameter type,
				// such as a SMALLINT to a DOUBLE PRECISION. The size is stripped so
				// the value isn't truncated (see implicit_cast_type).
				arg := compiled_args[i].run(mut conn, data, params)!
				mut target := typ
				param_typ := found_func.arg_types[i]
				if typ.typ != param_typ.typ && typ.typ.is_number() {
					target = implicit_cast_type(arg, param_typ)
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

			result := found_func.func(args)!
			if is_fold {
				return result.with_type(return_type)
			}
			if is_exact {
				return with_numeric_type(result, return_type)
			}

			return result
		}
		typ:          return_type
		contains_agg: found_func.is_agg
	}
}
