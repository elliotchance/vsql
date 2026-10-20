module vsql

// ISO/IEC 9075-2:2016(E), 10.4, <routine invocation>
//
// Invoke an SQL-invoked routine.

struct RoutineInvocation {
	function_name string
	args          []ValueExpression
}

fn (e RoutineInvocation) pstr(params map[string]Value) string {
	args := e.args.map(it.pstr(params)).join(', ')
	return '${e.function_name}(${args})'
}

fn (e RoutineInvocation) compile(mut c Compiler) !CompileResult {
	// The arguments of an aggregate function may use any column of a grouped
	// query.
	in_aggregate := c.in_aggregate
	c.in_aggregate = in_aggregate || c.conn.funcs.any(it.name == e.function_name && it.is_agg)
	defer {
		c.in_aggregate = in_aggregate
	}

	mut arg_types := []Type{}
	for arg in e.args {
		arg_types << arg.compile(mut c)!.typ
	}

	func_name := e.function_name

	found_func := c.conn.find_function(func_name, arg_types)!

	if found_func.is_agg {
		// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 1
		for arg in e.args {
			if arg.compile(mut c)!.contains_agg {
				return sqlstate_42601('nested set function: ${e.pstr(c.params)}')
			}
		}

		c.aggregates << AggregateFunction(e)

		return Identifier{
			custom_id:  e.pstr(c.params)
			custom_typ: found_func.return_type
		}.compile(mut c)!.with_agg(true)
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
		found_func.return_type
	}

	return CompileResult{
		run:          fn [found_func, func_name, arg_types, compiled_args, is_fold, return_type] (mut conn Connection, data Row, params map[string]Value) !Value {
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

			return result
		}
		typ:          return_type
		contains_agg: found_func.is_agg
	}
}

fn (e RoutineInvocation) resolve_identifiers(conn &Connection, tables map[string]Table) !RoutineInvocation {
	return RoutineInvocation{e.function_name, e.args}
}
