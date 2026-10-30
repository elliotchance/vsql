module vsql

// ISO/IEC 9075-2:2016(E), 6.39, <boolean value expression>
//
// Specify a boolean value.
//
// The concept is described by ISO/IEC 9075-1:2003(E), 4.4.3.3, Boolean type.

type BooleanPrimary = BooleanPredicand | Predicate

fn (e BooleanPrimary) pstr(params map[string]Value) string {
	return match e {
		Predicate, BooleanPredicand {
			e.pstr(params)
		}
	}
}

fn (e BooleanPrimary) compile(mut c Compiler) !CompileResult {
	match e {
		Predicate, BooleanPredicand {
			return e.compile(mut c)!
		}
	}
}

type BooleanPredicand = BooleanValueExpression | NonparenthesizedValueExpressionPrimary

fn (e BooleanPredicand) pstr(params map[string]Value) string {
	return match e {
		// The parentheses can't be left out, otherwise "NOT (a AND b)" would be
		// "NOT a AND b".
		BooleanValueExpression { '(${e.pstr(params)})' }
		NonparenthesizedValueExpressionPrimary { e.pstr(params) }
	}
}

fn (e BooleanPredicand) compile(mut c Compiler) !CompileResult {
	match e {
		BooleanValueExpression, NonparenthesizedValueExpressionPrimary {
			return e.compile(mut c)!
		}
	}
}

struct BooleanValueExpression {
	expr ?&BooleanValueExpression
	term BooleanTerm
}

fn (e BooleanValueExpression) pstr(params map[string]Value) string {
	if expr := e.expr {
		return '${expr.pstr(params)} OR ${e.term.pstr(params)}'
	}

	return e.term.pstr(params)
}

fn (e BooleanValueExpression) compile(mut c Compiler) !CompileResult {
	if expr := e.expr {
		compiled_a := expr.compile(mut c)!
		compiled_b := e.term.compile(mut c)!

		return CompileResult{
			run:          fn [compiled_a, compiled_b] (mut conn Connection, data Row, params map[string]Value) !Value {
				a := compiled_a.run(mut conn, data, params)!
				b := compiled_b.run(mut conn, data, params)!

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
			typ:          new_type('BOOLEAN', 0, 0)
			contains_agg: compiled_a.contains_agg || compiled_b.contains_agg
		}
	}

	return e.term.compile(mut c)!
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

fn (e BooleanTerm) compile(mut c Compiler) !CompileResult {
	if term := e.term {
		compiled_a := term.compile(mut c)!
		compiled_b := e.factor.compile(mut c)!

		return CompileResult{
			run:          fn [compiled_a, compiled_b] (mut conn Connection, data Row, params map[string]Value) !Value {
				a := compiled_a.run(mut conn, data, params)!
				b := compiled_b.run(mut conn, data, params)!

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
			typ:          new_type('BOOLEAN', 0, 0)
			contains_agg: compiled_a.contains_agg || compiled_b.contains_agg
		}
	}

	return e.factor.compile(mut c)!
}

// BooleanTest for "IS [ NOT ] { TRUE | FALSE | UNKNOWN }".
// expr is a reference because a BooleanPrimary can contain another BooleanTest
// (such as in parentheses), and V stores a sum type's value inline.
struct BooleanTest {
	expr  &BooleanPrimary
	not   bool
	value ?Value
	// If a unary NOT exists before. We do not need to keep this separate as
	// stacking NOT operations simply inverts this value.
	inverse bool
}

fn new_boolean_test(expr BooleanPrimary, not bool, value ?Value, inverse bool) BooleanTest {
	return BooleanTest{&expr, not, value, inverse}
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

fn (e BooleanTest) compile(mut c Compiler) !CompileResult {
	compiled := e.expr.compile(mut c)!

	if v := e.value {
		return CompileResult{
			run:          fn [e, v, compiled] (mut conn Connection, data Row, params map[string]Value) !Value {
				// See ISO/IEC 9075-2:2016(E), 6.39, <boolean value expression>,
				// "Table 15 — Truth table for the IS boolean operator"

				value := compiled.run(mut conn, data, params)!
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

				return e.unary_not(result)!
			}
			typ:          new_type('BOOLEAN', 0, 0)
			contains_agg: compiled.contains_agg
		}
	}

	if e.inverse {
		return CompileResult{
			run:          fn [e, compiled] (mut conn Connection, data Row, params map[string]Value) !Value {
				return e.unary_not(compiled.run(mut conn, data, params)!)!
			}
			typ:          compiled.typ
			contains_agg: compiled.contains_agg
		}
	}

	return compiled
}
