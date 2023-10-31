// ISO/IEC 9075-2:2016(E), 10.4, <routine invocation>

module vsql

// Format
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

fn (e RoutineInvocation) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	func_name := e.function_name

	mut arg_types := []Type{}
	for arg in e.args {
		mut arg_type := arg.eval_type(conn, data, params)!

		// TODO(elliotchance): There is a special case where numeric literals are
		// treated as DOUBLE PRECISION. This will be changed in the future when we
		// have proper support for NUMERIC.
		if arg_type.typ == .is_numeric && arg_type.scale == 0 {
			arg_type = Type{.is_double_precision, 0, 0, false}
		}

		arg_types << arg_type
	}

	func := conn.find_function(func_name, arg_types)!

	if func.is_agg {
		return Identifier{
			custom_id: e.pstr(params)
		}.eval(mut conn, data, params)
	}

	if e.args.len != func.arg_types.len {
		return sqlstate_42883('${func_name} has ${e.args.len} ${pluralize(e.args.len,
			'argument')} but needs ${func.arg_types.len} ${pluralize(func.arg_types.len,
			'argument')}')
	}

	mut args := []Value{}
	mut i := 0
	for typ in arg_types {
		arg := e.args[i].eval(mut conn, data, params)!
		args << cast(mut conn, 'argument ${i + 1} in ${func_name}', arg, typ)!
		i++
	}

	return func.func(args)
}

fn (e RoutineInvocation) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	mut arg_types := []Type{}
	for arg in e.args {
		arg_types << arg.eval_type(conn, data, params)!
	}

	func := conn.find_function(e.function_name, arg_types)!

	return func.return_type
}

fn (e RoutineInvocation) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	mut arg_types := []Type{}
	for arg in e.args {
		arg_types << arg.eval_type(conn, row, params)!
	}

	func := conn.find_function(e.function_name, arg_types)!

	if func.is_agg {
		return true
	}

	for arg in e.args {
		if arg.is_agg(conn, row, params)! {
			return sqlstate_42601('nested aggregate functions are not supported: ${e.pstr(params)}')
		}
	}

	return false
}

fn (e RoutineInvocation) resolve_identifiers(conn &Connection, tables map[string]Table) !RoutineInvocation {
	return RoutineInvocation{e.function_name, e.args.map(it.resolve_identifiers(conn,
		tables)!)}
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
