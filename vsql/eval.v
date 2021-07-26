// eval.v executes expressions (such as you would find in a WHERE condition).

module vsql

fn eval_as_value(data Row, e Expr) ?Value {
	match e {
		BinaryExpr { return eval_binary(data, e) }
		Identifier { return eval_identifier(data, e) }
		NullExpr { return eval_null(data, e) }
		NoExpr { return sqlstate_42601('no expression provided') }
		Value { return e }
	}
}

fn eval_as_bool(data Row, e Expr) ?bool {
	v := eval_as_value(data, e) ?

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

fn eval_null(data Row, e NullExpr) ?Value {
	value := eval_as_value(data, e.expr) ?

	if e.not {
		return new_boolean_value(value.typ.typ != .is_null)
	}

	return new_boolean_value(value.typ.typ == .is_null)
}

fn eval_binary(data Row, e BinaryExpr) ?Value {
	col := identifier_name(e.col)

	if data.data[col].typ.uses_f64() && e.value.typ.uses_f64() {
		return eval_cmp<f64>(data.get_f64(col), e.value.f64_value, e.op)
	}

	// TODO(elliotchance): Use the correct SQLSTATE error.
	return error('cannot $col $e.op $e.value.typ')
}

fn eval_cmp<T>(lhs T, rhs T, op string) Value {
	return new_boolean_value(match op {
		'=' { lhs == rhs }
		'!=' { lhs != rhs }
		'>' { lhs > rhs }
		'>=' { lhs >= rhs }
		'<' { lhs < rhs }
		'<=' { lhs <= rhs }
		// This should not be possible because the parser has already verified
		// this.
		else { false }
	})
}
