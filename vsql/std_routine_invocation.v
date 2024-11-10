module vsql

// ISO/IEC 9075-2:2016(E), 10.4, <routine invocation>
//
// # Function
//
// Invoke an SQL-invoked routine.
//
// # Format
//~
//~ <routine invocation> /* RoutineInvocation */ ::=
//~     <routine name> <SQL argument list>   -> routine_invocation
//~
//~ <routine name> /* Identifier */ ::=
//~     <qualified identifier>   -> routine_name
//~
//~ <SQL argument list> /* []ValueExpression */ ::=
//~     <left paren> <right paren>                  -> sql_argument_list_1
//~   | <left paren> <SQL argument> <right paren>   -> sql_argument_list_2
//~   | <left paren> <SQL argument list> <comma>
//~     <SQL argument> <right paren>                -> sql_argument_list_3
//~
//~ <SQL argument> /* ValueExpression */ ::=
//~     <value expression>

struct RoutineInvocation {
	function_name string
	args          []ValueExpression
}

fn (e RoutineInvocation) pstr(params map[string]Value) string {
	args := e.args.map(it.pstr(params)).join(', ')
	return '${e.function_name}(${args})'
}

fn (e RoutineInvocation) compile(mut c Compiler) !CompileResult {
	mut arg_types := []Type{}
	for arg in e.args {
		arg_types << arg.compile(mut c)!.typ
	}

	func_name := e.function_name

	found_func := c.conn.find_function(func_name, arg_types)!

	if found_func.is_agg {
		return Identifier{
			custom_id:  e.pstr(c.params)
			custom_typ: found_func.return_type
		}.compile(mut c)!.with_agg(true)
	}

	if e.args.len != found_func.arg_types.len {
		return sqlstate_42883('${func_name} has ${e.args.len} ${pluralize(e.args.len,
			'argument')} but needs ${found_func.arg_types.len} ${pluralize(found_func.arg_types.len,
			'argument')}')
	}

	mut compiled_args := []CompileResult{}
	for i, _ in arg_types {
		compiled_args << e.args[i].compile(mut c)!
	}

	return CompileResult{
		run:          fn [found_func, func_name, arg_types, compiled_args] (mut conn Connection, data Row, params map[string]Value) !Value {
			mut args := []Value{}
			mut i := 0
			for typ in arg_types {
				arg := compiled_args[i].run(mut conn, data, params)!
				args << cast(mut conn, 'argument ${i + 1} in ${func_name}', arg, typ)!
				i++
			}

			return found_func.func(args)!
		}
		typ:          found_func.return_type
		contains_agg: found_func.is_agg
	}
}

fn (e RoutineInvocation) resolve_identifiers(conn &Connection, tables map[string]Table) !RoutineInvocation {
	return RoutineInvocation{e.function_name, e.args}
}

fn parse_routine_invocation(name Identifier, args []ValueExpression) !RoutineInvocation {
	return RoutineInvocation{name.entity_name, args}
}

fn parse_routine_name(identifier IdentifierChain) !Identifier {
	return new_function_identifier(identifier.identifier)
}

fn parse_sql_argument_list_1() ![]ValueExpression {
	return []ValueExpression{}
}

fn parse_sql_argument_list_2(expr ValueExpression) ![]ValueExpression {
	return [expr]
}

fn parse_sql_argument_list_3(element_list []ValueExpression, element ValueExpression) ![]ValueExpression {
	mut new_list := element_list.clone()
	new_list << element

	return new_list
}
