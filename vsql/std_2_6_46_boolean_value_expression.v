module vsql

// ISO/IEC 9075-2:2023(E), 6.46, <boolean value expression>
//
// Specify a boolean value.
//
// The concept is described by ISO/IEC 9075-1:2003(E), 4.4.3.3, Boolean type.
//
// The concept is also described by:
//
// ISO/IEC 9075-2:2023(E), 4.6, Boolean types

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
		BooleanValueExpression {
			return e.compile(mut c)!
		}
		NonparenthesizedValueExpressionPrimary {
			// A predicate in it (such as in a CASE) can't be retrospectively
			// deterministic.
			retrospective := c.retrospective
			c.retrospective = false
			defer {
				c.retrospective = retrospective
			}

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

// check_boolean_operand returns an error if an operand of a boolean operator
// isn't a boolean.
//
// ISO/IEC 9075-2:2023(E), 6.46, <boolean value expression>, Syntax Rules, 3
fn check_boolean_operand(op string, operand CompileResult) ! {
	if operand.typ.typ != .is_boolean {
		return sqlstate_42804('in ${op}', 'BOOLEAN', operand.typ.str())
	}
}

fn (e BooleanValueExpression) compile(mut c Compiler) !CompileResult {
	if expr := e.expr {
		compiled_a := c.with_boolean_type(expr.compile(mut c)!)
		compiled_b := c.with_boolean_type(e.term.compile(mut c)!)
		check_boolean_operand('OR', compiled_a)!
		check_boolean_operand('OR', compiled_b)!

		return CompileResult{
			run:          fn [compiled_a, compiled_b] (mut conn Connection, data Row, params map[string]Value) !Value {
				a := compiled_a.run(mut conn, data, params)!
				b := compiled_b.run(mut conn, data, params)!

				// The truth table for OR (Table 14).
				//
				// ISO/IEC 9075-2:2023(E), 6.46, <boolean value expression>, General Rules, 3

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
		compiled_a := c.with_boolean_type(term.compile(mut c)!)
		compiled_b := c.with_boolean_type(e.factor.compile(mut c)!)
		check_boolean_operand('AND', compiled_a)!
		check_boolean_operand('AND', compiled_b)!

		return CompileResult{
			run:          fn [compiled_a, compiled_b] (mut conn Connection, data Row, params map[string]Value) !Value {
				a := compiled_a.run(mut conn, data, params)!
				b := compiled_b.run(mut conn, data, params)!

				// The truth table for AND (Table 13).
				//
				// ISO/IEC 9075-2:2023(E), 6.46, <boolean value expression>, General Rules, 3

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

// is_negative is true for a negative <boolean factor>: NOT BP, BP IS FALSE, BP IS
// NOT TRUE, NOT BP IS NOT FALSE and NOT BP IS TRUE.
//
// ISO/IEC 9075-2:2023(E), 6.46, <boolean value expression>, Syntax Rules, 7.e.i
fn (e BooleanTest) is_negative() bool {
	if v := e.value {
		return !v.is_null && ((v.bool_value() == .is_false) != e.not) != e.inverse
	}

	return e.inverse
}

fn (e BooleanTest) compile(mut c Compiler) !CompileResult {
	// A negative boolean factor can't contain anything that's possibly
	// non-deterministic.
	//
	// ISO/IEC 9075-2:2023(E), 6.46, <boolean value expression>, Syntax Rules, 7.e.ii
	retrospective := c.retrospective
	c.retrospective = retrospective && !e.is_negative()
	mut compiled := e.expr.compile(mut c)!
	c.retrospective = retrospective
	if e.value != none || e.inverse {
		compiled = c.with_boolean_type(compiled)
	}

	if v := e.value {
		check_boolean_operand('IS', compiled)!
		return CompileResult{
			run:          fn [e, v, compiled] (mut conn Connection, data Row, params map[string]Value) !Value {
				// The truth table for IS (Table 15).
				//
				// ISO/IEC 9075-2:2023(E), 6.46, <boolean value expression>, General Rules, 3

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
		check_boolean_operand('NOT', compiled)!
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
