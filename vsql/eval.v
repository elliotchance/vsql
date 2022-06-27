// eval.v executes expressions (such as you would find in a WHERE condition).

module vsql

import regex

// A ExprOperation executes expressions for each row.
struct ExprOperation {
	conn    &Connection
	params  map[string]Value
	exprs   []DerivedColumn
	columns []Column
}

fn new_expr_operation(conn &Connection, params map[string]Value, select_list SelectList, table Table) ?ExprOperation {
	mut exprs := []DerivedColumn{}
	mut columns := []Column{}

	match select_list {
		AsteriskExpr {
			columns = table.columns
			for column in table.columns {
				exprs << DerivedColumn{new_identifier('"${table.name}.$column.name"'), new_identifier('"$column.name"')}
			}
		}
		[]DerivedColumn {
			empty_row := new_empty_row(table.columns, '')
			for i, column in select_list {
				mut column_name := 'COL${i + 1}'
				if column.as_clause.name != '' {
					column_name = column.as_clause.name
				} else if column.expr is Identifier {
					column_name = column.expr.name
				}

				columns << Column{column_name, eval_as_type(conn, empty_row, column.expr,
					params)?, false}

				exprs << DerivedColumn{resolve_identifiers(column.expr, table)?, new_identifier('"$column_name"')}
			}
		}
	}

	return ExprOperation{conn, params, exprs, columns}
}

fn (o ExprOperation) str() string {
	return 'EXPR ($o.columns())'
}

fn (o ExprOperation) columns() Columns {
	return o.columns
}

fn (mut o ExprOperation) execute(rows []Row) ?[]Row {
	mut new_rows := []Row{}

	for row in rows {
		mut data := map[string]Value{}
		for expr in o.exprs {
			data[expr.as_clause.name] = eval_as_value(o.conn, row, expr.expr, o.params)?
		}
		new_rows << new_row(data)
	}

	return new_rows
}

fn eval_row(conn &Connection, data Row, exprs []Expr, params map[string]Value) ?Row {
	mut col_number := 1
	mut row := map[string]Value{}
	for expr in exprs {
		row['COL$col_number'] = eval_as_value(conn, data, expr, params)?
		col_number++
	}

	return Row{
		data: row
	}
}

fn eval_as_type(conn &Connection, data Row, e Expr, params map[string]Value) ?Type {
	match e {
		CallExpr {
			func := conn.funcs[e.function_name] or { return sqlstate_42883(e.function_name) }

			return func.return_type
		}
		CountAllExpr {
			return new_type('INTEGER', 0)
		}
		BetweenExpr, NullExpr, LikeExpr, SimilarExpr {
			return new_type('BOOLEAN', 0)
		}
		Parameter {
			p := params[e.name] or { return sqlstate_42p02(e.name) }

			return eval_as_type(conn, data, p, params)
		}
		Value {
			return e.typ
		}
		UnaryExpr {
			return eval_as_type(conn, data, e.expr, params)
		}
		BinaryExpr {
			// TODO(elliotchance): This is not correct, we would have to return
			// the highest resolution type (need to check the SQL standard about
			// this behavior).
			return eval_as_type(conn, data, e.left, params)
		}
		Identifier {
			col := data.data[e.name] or {
				panic(e.name)
				return sqlstate_42601('unknown column: $e.name')
			}

			return col.typ
		}
		NoExpr, RowExpr, QueryExpression {
			return sqlstate_42601('invalid expression provided')
		}
	}
}

fn eval_as_value(conn &Connection, data Row, e Expr, params map[string]Value) ?Value {
	match e {
		BetweenExpr {
			return eval_between(conn, data, e, params)
		}
		BinaryExpr {
			return eval_binary(conn, data, e, params)
		}
		CallExpr {
			return eval_call(conn, data, e, params)
		}
		CountAllExpr {
			return eval_identifier(data, new_identifier('COUNT(*)'))
		}
		Identifier {
			return eval_identifier(data, e)
		}
		LikeExpr {
			return eval_like(conn, data, e, params)
		}
		NullExpr {
			return eval_null(conn, data, e, params)
		}
		Parameter {
			return params[e.name] or { return sqlstate_42p02(e.name) }
		}
		SimilarExpr {
			return eval_similar(conn, data, e, params)
		}
		UnaryExpr {
			return eval_unary(conn, data, e, params)
		}
		Value {
			return e
		}
		NoExpr, RowExpr, QueryExpression {
			// RowExpr should never make it to eval because it will be
			// reformatted into a ValuesOperation.
			//
			// QueryExpression will have already been resolved to a
			// ValuesOperation.
			return sqlstate_42601('missing or invalid expression provided')
		}
	}
}

fn eval_as_bool(conn &Connection, data Row, e Expr, params map[string]Value) ?bool {
	v := eval_as_value(conn, data, e, params)?

	if v.typ.typ == .is_boolean {
		return v.f64_value != 0
	}

	return sqlstate_42804('in expression', 'BOOLEAN', v.typ.str())
}

fn eval_identifier(data Row, e Identifier) ?Value {
	value := data.data[e.name] or { return sqlstate_42601('unknown column: $e.name') }

	return value
}

fn eval_call(conn &Connection, data Row, e CallExpr, params map[string]Value) ?Value {
	func_name := e.function_name

	func := conn.funcs[func_name] or {
		// function does not exist
		return sqlstate_42883(func_name)
	}

	if func.is_agg {
		return eval_identifier(data, new_identifier('"${e.pstr(params)}"'))
	}

	if e.args.len != func.arg_types.len {
		return sqlstate_42883('$func_name has $e.args.len ${pluralize(e.args.len, 'argument')} but needs $func.arg_types.len ${pluralize(func.arg_types.len,
			'argument')}')
	}

	mut args := []Value{}
	mut i := 0
	for typ in func.arg_types {
		arg := eval_as_value(conn, data, e.args[i], params)?
		args << cast('argument ${i + 1} in $func_name', arg, typ)?
		i++
	}

	return func.func(args)
}

fn eval_null(conn &Connection, data Row, e NullExpr, params map[string]Value) ?Value {
	value := eval_as_value(conn, data, e.expr, params)?

	if e.not {
		return new_boolean_value(!value.is_null())
	}

	return new_boolean_value(value.is_null())
}

fn eval_like(conn &Connection, data Row, e LikeExpr, params map[string]Value) ?Value {
	left := eval_as_value(conn, data, e.left, params)?
	right := eval_as_value(conn, data, e.right, params)?

	// Make sure we escape any regexp characters.
	escaped_regex := right.string_value.replace('+', '\\+').replace('?', '\\?').replace('*',
		'\\*').replace('|', '\\|').replace('.', '\\.').replace('(', '\\(').replace(')',
		'\\)').replace('[', '\\[').replace('{', '\\{').replace('_', '.').replace('%',
		'.*')

	mut re := regex.regex_opt('^$escaped_regex$')?
	result := re.matches_string(left.string_value)

	if e.not {
		return new_boolean_value(!result)
	}

	return new_boolean_value(result)
}

fn eval_binary(conn &Connection, data Row, e BinaryExpr, params map[string]Value) ?Value {
	left := eval_as_value(conn, data, e.left, params)?
	right := eval_as_value(conn, data, e.right, params)?

	match e.op {
		'=', '<>', '>', '<', '>=', '<=' {
			if left.typ.uses_f64() && right.typ.uses_f64() {
				return eval_cmp<f64>(left.f64_value, right.f64_value, e.op)
			}

			if left.typ.uses_string() && right.typ.uses_string() {
				return eval_cmp<string>(left.string_value, right.string_value, e.op)
			}
		}
		'||' {
			if left.typ.uses_string() && right.typ.uses_string() {
				return new_varchar_value(left.string_value + right.string_value, 0)
			}
		}
		'+' {
			if left.typ.uses_f64() && right.typ.uses_f64() {
				return new_double_precision_value(left.f64_value + right.f64_value)
			}
		}
		'-' {
			if left.typ.uses_f64() && right.typ.uses_f64() {
				return new_double_precision_value(left.f64_value - right.f64_value)
			}
		}
		'*' {
			if left.typ.uses_f64() && right.typ.uses_f64() {
				return new_double_precision_value(left.f64_value * right.f64_value)
			}
		}
		'/' {
			if left.typ.uses_f64() && right.typ.uses_f64() {
				if right.f64_value == 0 {
					return sqlstate_22012() // division by zero
				}

				return new_double_precision_value(left.f64_value / right.f64_value)
			}
		}
		'AND' {
			if left.typ.typ == .is_boolean && right.typ.typ == .is_boolean {
				return new_boolean_value((left.f64_value != 0) && (right.f64_value != 0))
			}
		}
		'OR' {
			if left.typ.typ == .is_boolean && right.typ.typ == .is_boolean {
				return new_boolean_value((left.f64_value != 0) || (right.f64_value != 0))
			}
		}
		else {}
	}

	return sqlstate_42804('cannot $left.typ $e.op $right.typ', 'another type', '$left.typ and $right.typ')
}

fn eval_unary(conn &Connection, data Row, e UnaryExpr, params map[string]Value) ?Value {
	value := eval_as_value(conn, data, e.expr, params)?

	match e.op {
		'-' {
			if value.typ.uses_f64() {
				return new_double_precision_value(-value.f64_value)
			}
		}
		'+' {
			if value.typ.uses_f64() {
				return new_double_precision_value(value.f64_value)
			}
		}
		'NOT' {
			if value.typ.typ == .is_boolean {
				return new_boolean_value(!(value.f64_value != 0))
			}
		}
		else {}
	}

	return sqlstate_42804('cannot $e.op$value.typ', 'another type', value.typ.str())
}

fn eval_cmp<T>(lhs T, rhs T, op string) Value {
	return new_boolean_value(match op {
		'=' { lhs == rhs }
		'<>' { lhs != rhs }
		'>' { lhs > rhs }
		'>=' { lhs >= rhs }
		'<' { lhs < rhs }
		'<=' { lhs <= rhs }
		// This should not be possible because the parser has already verified
		// this.
		else { false }
	})
}

fn eval_between(conn &Connection, data Row, e BetweenExpr, params map[string]Value) ?Value {
	expr := eval_as_value(conn, data, e.expr, params)?
	mut left := eval_as_value(conn, data, e.left, params)?
	mut right := eval_as_value(conn, data, e.right, params)?

	// SYMMETRIC operandsmight need to be swapped.
	cmp, is_null := left.cmp(right)?
	if e.symmetric && !is_null && cmp > 0 {
		left, right = right, left
	}

	lower, lower_is_null := expr.cmp(left)?
	upper, upper_is_null := expr.cmp(right)?

	if lower_is_null || upper_is_null {
		return new_null_value()
	}

	mut result := lower >= 0 && upper <= 0

	if e.not {
		result = !result
	}

	return new_boolean_value(result)
}

fn eval_similar(conn &Connection, data Row, e SimilarExpr, params map[string]Value) ?Value {
	left := eval_as_value(conn, data, e.left, params)?
	right := eval_as_value(conn, data, e.right, params)?

	mut re := regex.regex_opt('^${right.string_value.replace('.', '\\.').replace('_',
		'.').replace('%', '.*')}$')?
	result := re.matches_string(left.string_value)

	if e.not {
		return new_boolean_value(!result)
	}

	return new_boolean_value(result)
}
