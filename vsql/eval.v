// eval.v executes expressions (such as you would find in a WHERE condition).

module vsql

fn eval_as_value(conn Connection, data Row, e Expr) ?Value {
	match e {
		BinaryExpr { return eval_binary(conn, data, e) }
		CallExpr { return eval_call(conn, data, e) }
		Identifier { return eval_identifier(data, e) }
		NamedExpr { return eval_as_value(conn, data, e.expr) }
		NullExpr { return eval_null(conn, data, e) }
		NoExpr { return sqlstate_42601('no expression provided') }
		UnaryExpr { return eval_unary(conn, data, e) }
		Value { return e }
	}
}

fn eval_as_bool(conn Connection, data Row, e Expr) ?bool {
	v := eval_as_value(conn, data, e) ?

	if v.typ.typ == .is_boolean {
		return v.f64_value != 0
	}

	return sqlstate_42804('in expression', 'BOOLEAN', v.typ.str())
}

fn eval_identifier(data Row, e Identifier) ?Value {
	col := identifier_name(e.name)
	value := data.data[col] or { panic(col) }

	return value
}

fn eval_call(conn Connection, data Row, e CallExpr) ?Value {
	func_name := identifier_name(e.function_name)

	func := conn.funcs[func_name] or {
		// function does not exist
		return sqlstate_42883(func_name)
	}

	if e.args.len != func.arg_types.len {
		return sqlstate_42883('$func_name has $e.args.len ${pluralize(e.args.len, 'argument')} but needs $func.arg_types.len ${pluralize(func.arg_types.len,
			'argument')}')
	}

	mut args := []Value{}
	mut i := 0
	for typ in func.arg_types {
		arg := eval_as_value(conn, data, e.args[i]) ?
		args << cast('argument ${i + 1} in $func_name', arg, typ) ?
		i++
	}

	return func.func(args)
}

fn eval_null(conn Connection, data Row, e NullExpr) ?Value {
	value := eval_as_value(conn, data, e.expr) ?

	if e.not {
		return new_boolean_value(value.typ.typ != .is_null)
	}

	return new_boolean_value(value.typ.typ == .is_null)
}

fn eval_binary(conn Connection, data Row, e BinaryExpr) ?Value {
	left := eval_as_value(conn, data, e.left) ?
	right := eval_as_value(conn, data, e.right) ?

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

fn eval_unary(conn Connection, data Row, e UnaryExpr) ?Value {
	value := eval_as_value(conn, data, e.expr) ?

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
