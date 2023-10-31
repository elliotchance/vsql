// ISO/IEC 9075-2:2016(E), 6.29, <numeric value expression>

module vsql

// Format
//~
//~ <numeric value expression> /* NumericValueExpression */ ::=
//~     <term>                                           -> numeric_value_expression_1
//~   | <numeric value expression> <plus sign> <term>    -> numeric_value_expression_2
//~   | <numeric value expression> <minus sign> <term>   -> numeric_value_expression_2
//~
//~ <term> /* Term */ ::=
//~     <factor>                     -> term_1
//~   | <term> <asterisk> <factor>   -> term_2
//~   | <term> <solidus> <factor>    -> term_2
//~
//~ <factor> /* NumericPrimary */ ::=
//~     <numeric primary>
//~   | <sign> <numeric primary>   -> factor_2
//~
//~ <numeric primary> /* NumericPrimary */ ::=
//~     <value expression primary>   -> NumericPrimary
//~   | <numeric value function>     -> NumericPrimary

struct NumericValueExpression {
	n    ?&NumericValueExpression
	op   string
	term Term
}

fn (e NumericValueExpression) pstr(params map[string]Value) string {
	if n := e.n {
		return '${n.pstr(params)} ${e.op} ${e.term.pstr(params)}'
	}

	return e.term.pstr(params)
}

fn (e NumericValueExpression) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	if n := e.n {
		mut left := n.eval(mut conn, data, params)!
		mut right := e.term.eval(mut conn, data, params)!

		return eval_binary(mut conn, data, left, e.op, right, params)!
	}

	return e.term.eval(mut conn, data, params)
}

fn (e NumericValueExpression) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	if n := e.n {
		// TODO(elliotchance): This is not correct, we would have to return
		//  the highest resolution type (need to check the SQL standard about
		//  this behavior).
		return n.eval_type(conn, data, params)!
	}

	return e.term.eval_type(conn, data, params)
}

fn (e NumericValueExpression) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	if n := e.n {
		if n.is_agg(conn, row, params)! || e.term.is_agg(conn, row, params)! {
			return sqlstate_42601('nested aggregate functions are not supported: ${e.pstr(params)}')
		}
	}

	return e.term.is_agg(conn, row, params)!
}

fn (e NumericValueExpression) resolve_identifiers(conn &Connection, tables map[string]Table) !NumericValueExpression {
	term := e.term.resolve_identifiers(conn, tables)!
	if n := e.n {
		n2 := n.resolve_identifiers(conn, tables)!
		return NumericValueExpression{&n2, e.op, term}
	}

	return NumericValueExpression{none, e.op, term}
}

struct Term {
	term   ?&Term
	op     string
	factor NumericPrimary
}

fn (e Term) pstr(params map[string]Value) string {
	if term := e.term {
		return '${term.pstr(params)} ${e.op} ${e.factor.pstr(params)}'
	}

	return e.factor.pstr(params)
}

fn (e Term) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	if term := e.term {
		mut left := term.eval(mut conn, data, params)!
		mut right := e.factor.eval(mut conn, data, params)!

		return eval_binary(mut conn, data, left, e.op, right, params)!
	}

	return e.factor.eval(mut conn, data, params)
}

fn (e Term) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	if term := e.term {
		// TODO(elliotchance): This is not correct, we would have to return
		//  the highest resolution type (need to check the SQL standard about
		//  this behavior).
		return term.eval_type(conn, data, params)!
	}

	return e.factor.eval_type(conn, data, params)
}

fn (e Term) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	if term := e.term {
		if term.is_agg(conn, row, params)! || e.factor.is_agg(conn, row, params)! {
			return sqlstate_42601('nested aggregate functions are not supported: ${e.pstr(params)}')
		}
	}

	return e.factor.is_agg(conn, row, params)!
}

fn (e Term) resolve_identifiers(conn &Connection, tables map[string]Table) !Term {
	factor := e.factor.resolve_identifiers(conn, tables)!
	if term := e.term {
		term2 := term.resolve_identifiers(conn, tables)!
		return Term{&term2, e.op, factor}
	}

	return Term{none, e.op, factor}
}

struct SignedValueExpressionPrimary {
	sign string
	e    NumericPrimary
}

fn (e SignedValueExpressionPrimary) pstr(params map[string]Value) string {
	return e.sign + e.e.pstr(params)
}

fn (e SignedValueExpressionPrimary) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	value := e.e.eval(mut conn, data, params)!

	key := '${e.sign} ${value.typ.typ}'
	if fnc := conn.unary_operators[key] {
		unary_fn := fnc as UnaryOperatorFunc
		return unary_fn(conn, value)!
	}

	return sqlstate_42883('operator does not exist: ${key}')
}

fn (e SignedValueExpressionPrimary) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	// Any sign always results in the same type.
	return e.e.eval_type(conn, data, params)!
}

fn (e SignedValueExpressionPrimary) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	return e.e.is_agg(conn, row, params)!
}

fn (e SignedValueExpressionPrimary) resolve_identifiers(conn &Connection, tables map[string]Table) !SignedValueExpressionPrimary {
	return SignedValueExpressionPrimary{e.sign, e.e.resolve_identifiers(conn, tables)!}
}

type NumericPrimary = RoutineInvocation | SignedValueExpressionPrimary | ValueExpressionPrimary

fn (e NumericPrimary) pstr(params map[string]Value) string {
	return match e {
		SignedValueExpressionPrimary, ValueExpressionPrimary, RoutineInvocation {
			e.pstr(params)
		}
	}
}

fn (e NumericPrimary) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		SignedValueExpressionPrimary, ValueExpressionPrimary, RoutineInvocation {
			e.eval(mut conn, data, params)!
		}
	}
}

fn (e NumericPrimary) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		SignedValueExpressionPrimary, ValueExpressionPrimary, RoutineInvocation {
			e.eval_type(conn, data, params)!
		}
	}
}

fn (e NumericPrimary) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	return match e {
		SignedValueExpressionPrimary, ValueExpressionPrimary, RoutineInvocation {
			e.is_agg(conn, row, params)!
		}
	}
}

fn (e NumericPrimary) resolve_identifiers(conn &Connection, tables map[string]Table) !NumericPrimary {
	match e {
		SignedValueExpressionPrimary {
			return e.resolve_identifiers(conn, tables)!
		}
		ValueExpressionPrimary {
			return e.resolve_identifiers(conn, tables)!
		}
		RoutineInvocation {
			return e.resolve_identifiers(conn, tables)!
		}
	}
}

fn parse_factor_2(sign string, expr NumericPrimary) !NumericPrimary {
	return SignedValueExpressionPrimary{sign, expr}
}

fn parse_term_1(factor NumericPrimary) !Term {
	return Term{none, '', factor}
}

fn parse_term_2(term Term, op string, factor NumericPrimary) !Term {
	return Term{&term, op, factor}
}

fn parse_numeric_value_expression_1(term Term) !NumericValueExpression {
	return NumericValueExpression{none, '', term}
}

fn parse_numeric_value_expression_2(n NumericValueExpression, op string, term Term) !NumericValueExpression {
	return NumericValueExpression{&n, op, term}
}
