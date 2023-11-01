module vsql

// ISO/IEC 9075-2:2016(E), 6.39, <boolean value expression>
//
// # Function
//
// Specify a boolean value.
//
// # Format
//~
//~ <boolean value expression> /* BooleanValueExpression */ ::=
//~     <boolean term>                                 -> boolean_value_expression_1
//~   | <boolean value expression> OR <boolean term>   -> boolean_value_expression_2
//~
//~ <boolean term> /* BooleanTerm */ ::=
//~     <boolean factor>                      -> boolean_term_1
//~   | <boolean term> AND <boolean factor>   -> boolean_term_2
//~
//~ <boolean factor> /* BooleanTest */ ::=
//~     <boolean test>
//~   | NOT <boolean test>   -> boolean_factor_not
//~
//~ <boolean test> /* BooleanTest */ ::=
//~     <boolean primary>                        -> boolean_test_1
//~   | <boolean primary> IS <truth value>       -> boolean_test_2
//~   | <boolean primary> IS NOT <truth value>   -> boolean_test_3
//~
//~ <truth value> /* Value */ ::=
//~     TRUE      -> true
//~   | FALSE     -> false
//~   | UNKNOWN   -> unknown
//~
//~ <boolean primary> /* BooleanPrimary */ ::=
//~     <predicate>           -> BooleanPrimary
//~   | <boolean predicand>   -> BooleanPrimary
//~
//~ <boolean predicand> /* BooleanPredicand */ ::=
//~     <parenthesized boolean value expression>      -> BooleanPredicand
//~   | <nonparenthesized value expression primary>   -> BooleanPredicand
//~
//~ <parenthesized boolean value expression> /* BooleanValueExpression */ ::=
//~     <left paren> <boolean value expression> <right paren>   -> parenthesized_boolean_value_expression

type BooleanPrimary = BooleanPredicand | Predicate

fn (e BooleanPrimary) pstr(params map[string]Value) string {
	return match e {
		Predicate, BooleanPredicand {
			e.pstr(params)
		}
	}
}

fn (e BooleanPrimary) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		Predicate, BooleanPredicand {
			e.eval(mut conn, data, params)!
		}
	}
}

fn (e BooleanPrimary) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		Predicate, BooleanPredicand {
			e.eval_type(conn, data, params)!
		}
	}
}

fn (e BooleanPrimary) resolve_identifiers(conn &Connection, tables map[string]Table) !BooleanPrimary {
	return match e {
		Predicate {
			e.resolve_identifiers(conn, tables)!
		}
		BooleanPredicand {
			e.resolve_identifiers(conn, tables)!
		}
	}
}

type BooleanPredicand = BooleanValueExpression | NonparenthesizedValueExpressionPrimary

fn (e BooleanPredicand) pstr(params map[string]Value) string {
	return match e {
		BooleanValueExpression, NonparenthesizedValueExpressionPrimary {
			e.pstr(params)
		}
	}
}

fn (e BooleanPredicand) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		BooleanValueExpression, NonparenthesizedValueExpressionPrimary {
			e.eval(mut conn, data, params)!
		}
	}
}

fn (e BooleanPredicand) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		BooleanValueExpression, NonparenthesizedValueExpressionPrimary {
			e.eval_type(conn, data, params)!
		}
	}
}

fn (e BooleanPredicand) resolve_identifiers(conn &Connection, tables map[string]Table) !BooleanPredicand {
	return match e {
		BooleanValueExpression {
			BooleanPredicand(e.resolve_identifiers(conn, tables)!)
		}
		NonparenthesizedValueExpressionPrimary {
			BooleanPredicand(e.resolve_identifiers(conn, tables)!)
		}
	}
}

struct BooleanValueExpression {
	expr ?&BooleanValueExpression
	term BooleanTerm
}

fn (e BooleanValueExpression) pstr(params map[string]Value) string {
	if expr := e.expr {
		return '${expr.pstr(params)} AND ${e.term.pstr(params)}'
	}

	return e.term.pstr(params)
}

fn (e BooleanValueExpression) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	if expr := e.expr {
		a := expr.eval(mut conn, data, params)!
		b := e.term.eval(mut conn, data, params)!

		// See ISO/IEC 9075-2:2016(E), 6.39, <boolean value expression>,
		// "Table 14 — Truth table for the OR boolean operator"

		if a.is_null {
			if b.bool_value() == .is_true {
				return new_boolean_value(true)
			}

			return new_unknown_value()
		}

		if a.bool_value() == .is_true {
			return new_boolean_value(true)
		}

		return b
	}

	return e.term.eval(mut conn, data, params)
}

fn (e BooleanValueExpression) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	if e.expr == none {
		return e.term.eval_type(conn, data, params)
	}

	return new_type('BOOLEAN', 0, 0)
}

fn (e BooleanValueExpression) resolve_identifiers(conn &Connection, tables map[string]Table) !BooleanValueExpression {
	term := e.term.resolve_identifiers(conn, tables)!
	if expr := e.expr {
		expr2 := expr.resolve_identifiers(conn, tables)!
		return BooleanValueExpression{&expr2, term}
	}

	return BooleanValueExpression{none, term}
}

struct BooleanTerm {
	term   ?&BooleanTerm
	factor BooleanTest
}

fn (e BooleanTerm) pstr(params map[string]Value) string {
	if term := e.term {
		return '${term.pstr(params)} AND ${e.factor.pstr(params)}'
	}

	return e.factor.pstr(params)
}

fn (e BooleanTerm) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	if term := e.term {
		a := term.eval(mut conn, data, params)!
		b := e.factor.eval(mut conn, data, params)!

		// See ISO/IEC 9075-2:2016(E), 6.39, <boolean value expression>,
		// "Table 13 — Truth table for the AND boolean operator"

		if a.is_null {
			if b.bool_value() == .is_false {
				return new_boolean_value(false)
			}

			return new_unknown_value()
		}

		if a.bool_value() == .is_true {
			return b
		}

		return new_boolean_value(false)
	}

	return e.factor.eval(mut conn, data, params)
}

fn (e BooleanTerm) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	if e.term == none {
		return e.factor.eval_type(conn, data, params)
	}

	return new_type('BOOLEAN', 0, 0)
}

fn (e BooleanTerm) resolve_identifiers(conn &Connection, tables map[string]Table) !BooleanTerm {
	factor := e.factor.resolve_identifiers(conn, tables)!
	if term := e.term {
		term2 := term.resolve_identifiers(conn, tables)!
		return BooleanTerm{&term2, factor}
	}

	return BooleanTerm{none, factor}
}

// BooleanTest for "IS [ NOT ] { TRUE | FALSE | UNKNOWN }".
struct BooleanTest {
	expr  BooleanPrimary
	not   bool
	value ?Value
	// If a unary NOT exists before. We do not need to keep this separate as
	// stacking NOT operations simply inverts this value.
	inverse bool
}

fn (e BooleanTest) pstr(params map[string]Value) string {
	prefix := if e.inverse { 'NOT ' } else { '' }
	if v := e.value {
		if e.not {
			return '${prefix}${e.expr.pstr(params)} IS NOT ${v.str()}'
		}

		return '${prefix}${e.expr.pstr(params)} IS ${v.str()}'
	}

	return prefix + e.expr.pstr(params)
}

fn (e BooleanTest) unary_not(v Value) !Value {
	if v.is_null {
		return new_unknown_value()
	}

	if e.inverse {
		return match v.bool_value() {
			.is_true { new_boolean_value(false) }
			.is_false { new_boolean_value(true) }
		}
	}

	return v
}

fn (e BooleanTest) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	if v := e.value {
		// See ISO/IEC 9075-2:2016(E), 6.39, <boolean value expression>,
		// "Table 15 — Truth table for the IS boolean operator"

		value := e.expr.eval(mut conn, data, params)!
		mut result := new_boolean_value(false)

		if value.is_null {
			result = new_boolean_value(v.is_null)
		} else if value.bool_value() == .is_true {
			result = new_boolean_value(v.bool_value() == .is_true)
		} else {
			result = new_boolean_value(v.bool_value() == .is_false)
		}

		if e.not {
			result = match result.bool_value() {
				.is_true { new_boolean_value(false) }
				.is_false { new_boolean_value(true) }
			}
		}

		return e.unary_not(result)
	}

	return e.unary_not(e.expr.eval(mut conn, data, params)!)
}

fn (e BooleanTest) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	if e.value == none {
		return e.expr.eval_type(conn, data, params)
	}

	return new_type('BOOLEAN', 0, 0)
}

fn (e BooleanTest) resolve_identifiers(conn &Connection, tables map[string]Table) !BooleanTest {
	return BooleanTest{e.expr.resolve_identifiers(conn, tables)!, e.not, e.value, e.inverse}
}

fn parse_boolean_term_1(factor BooleanTest) !BooleanTerm {
	return BooleanTerm{none, factor}
}

fn parse_boolean_term_2(term BooleanTerm, factor BooleanTest) !BooleanTerm {
	return BooleanTerm{&term, factor}
}

fn parse_boolean_factor_not(b BooleanTest) !BooleanTest {
	return BooleanTest{b.expr, b.not, b.value, !b.inverse}
}

fn parse_boolean_test_1(e BooleanPrimary) !BooleanTest {
	return BooleanTest{e, false, none, false}
}

fn parse_boolean_test_2(e BooleanPrimary, v Value) !BooleanTest {
	return BooleanTest{e, false, v, false}
}

fn parse_boolean_test_3(e BooleanPrimary, v Value) !BooleanTest {
	return BooleanTest{e, true, v, false}
}

fn parse_true() !Value {
	return new_boolean_value(true)
}

fn parse_false() !Value {
	return new_boolean_value(false)
}

fn parse_unknown() !Value {
	return new_unknown_value()
}

fn parse_boolean_value_expression_1(term BooleanTerm) !BooleanValueExpression {
	return BooleanValueExpression{none, term}
}

fn parse_boolean_value_expression_2(expr BooleanValueExpression, term BooleanTerm) !BooleanValueExpression {
	return BooleanValueExpression{&expr, term}
}

fn parse_parenthesized_boolean_value_expression(b BooleanValueExpression) !BooleanValueExpression {
	return b
}
