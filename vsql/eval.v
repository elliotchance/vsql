// eval.v executes expressions (such as you would find in a WHERE condition).

module vsql

fn eval(data Row, e BinaryExpr) ?bool {
	return eval_binary(data, e)
}

fn eval_binary(data Row, e BinaryExpr) ?bool {
	if data.data[e.col].typ == .is_f64 && e.value.typ == .is_f64 {
		return eval_cmp<f64>(data.get_f64(e.col), e.value.f64_value, e.op)
	}

	return error('cannot $e.col $e.op $e.value')
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
