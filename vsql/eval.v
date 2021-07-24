// eval.v executes expressions (such as you would find in a WHERE condition).

module vsql

fn eval(data Row, e BinaryExpr) ?bool {
	return eval_binary(data, e)
}

fn eval_binary(data Row, e BinaryExpr) ?bool {
	col := identifier_name(e.col)

	if data.data[col].typ.uses_f64() && e.value.typ.uses_f64() {
		return eval_cmp<f64>(data.get_f64(col), e.value.f64_value, e.op)
	}

	return error('cannot $col $e.op $e.value.typ')
}

fn eval_cmp<T>(lhs T, rhs T, op string) bool {
	return match op {
		'=' { lhs == rhs }
		'!=' { lhs != rhs }
		'>' { lhs > rhs }
		'>=' { lhs >= rhs }
		'<' { lhs < rhs }
		'<=' { lhs <= rhs }
		// This should not be possible because the parser has already verified
		// this.
		else { false }
	}
}
