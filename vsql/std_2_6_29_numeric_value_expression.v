module vsql

// ISO/IEC 9075-2:2016(E), 6.29, <numeric value expression>
//
// Specify a numeric value.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2016(E), 4.4.3, Operations involving numbers

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

fn (e NumericValueExpression) compile(mut c Compiler) !CompileResult {
	compiled_term := e.term.compile(mut c)!

	if n := e.n {
		compiled_n := n.compile(mut c)!

		return CompileResult{
			run:          fn [e, compiled_n, compiled_term] (mut conn Connection, data Row, params map[string]Value) !Value {
				mut left := compiled_n.run(mut conn, data, params)!
				mut right := compiled_term.run(mut conn, data, params)!

				return eval_binary(mut conn, left, e.op, right)!
			}
			typ:          arithmetic_type(compiled_n.typ, compiled_term.typ, e.op)
			contains_agg: compiled_term.contains_agg || compiled_n.contains_agg
		}
	}

	return compiled_term
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

fn (e Term) compile(mut c Compiler) !CompileResult {
	compiled_factor := e.factor.compile(mut c)!

	if term := e.term {
		compiled_term := term.compile(mut c)!

		return CompileResult{
			run:          fn [e, compiled_term, compiled_factor] (mut conn Connection, data Row, params map[string]Value) !Value {
				mut left := compiled_term.run(mut conn, data, params)!
				mut right := compiled_factor.run(mut conn, data, params)!

				return eval_binary(mut conn, left, e.op, right)!
			}
			typ:          arithmetic_type(compiled_term.typ, compiled_factor.typ, e.op)
			contains_agg: compiled_factor.contains_agg || compiled_term.contains_agg
		}
	}

	return compiled_factor
}

// e is a reference because NumericPrimary can be a SignedValueExpressionPrimary,
// and V stores a sum type's value inline.
struct SignedValueExpressionPrimary {
	sign string
	e    &NumericPrimary
}

fn (e SignedValueExpressionPrimary) pstr(params map[string]Value) string {
	return e.sign + e.e.pstr(params)
}

fn (e SignedValueExpressionPrimary) compile(mut c Compiler) !CompileResult {
	compiled := e.e.compile(mut c)!

	return CompileResult{
		run:          fn [e, compiled] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled.run(mut conn, data, params)!

			key := '${e.sign} ${value.typ.typ}'
			if fnc := conn.unary_operators[key] {
				if value.is_null {
					return value
				}

				unary_fn := fnc as UnaryOperatorFunc
				return unary_fn(conn, value)!
			}

			return sqlstate_42883('operator does not exist: ${key}')
		}
		typ:          compiled.typ
		contains_agg: compiled.contains_agg
	}
}

type NumericPrimary = RoutineInvocation | SignedValueExpressionPrimary | ValueExpressionPrimary

fn (e NumericPrimary) pstr(params map[string]Value) string {
	return match e {
		SignedValueExpressionPrimary, ValueExpressionPrimary, RoutineInvocation {
			e.pstr(params)
		}
	}
}

fn (e NumericPrimary) compile(mut c Compiler) !CompileResult {
	match e {
		SignedValueExpressionPrimary, ValueExpressionPrimary, RoutineInvocation {
			return e.compile(mut c)!
		}
	}
}

fn (e NumericPrimary) value() ?Value {
	if e is ValueExpressionPrimary {
		if e is NonparenthesizedValueExpressionPrimary {
			if e is ValueSpecification {
				if e is Value {
					return e
				}
			}
		}
	}

	return none
}

fn parse_factor_2(sign string, expr NumericPrimary) !NumericPrimary {
	// Due to the graph nature of the parser, a negative number might end up be
	// parsed as an <unsigned numeric literal> and take the sign from this stage
	// instead.
	//
	// Normally that wouldn't be an issue because it would negate the value at
	// runtime. However, literals needs to be given the smallest exact type that
	// encapsulates the value. This leaves an edge case where negative values need
	// to support one value lower than their positive counterpart.
	//
	// For example, SMALLINT range is -32768 to 32767. However, if we consume
	// 32768 first it would be given an INTEGER type (because it's out of range)
	// so the negation would also be an INTEGER when -32768 really should be
	// stored in a SMALLINT.
	if v := expr.value() {
		if sign == '-' {
			if v.typ.typ == .is_integer && v.int_value() == 32768 {
				return ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(ValueSpecification(new_smallint_value(-32768))))
			}

			if v.typ.typ == .is_bigint && v.int_value() == 2147483648 {
				return ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(ValueSpecification(new_integer_value(-2147483648))))
			}

			if v.typ.typ == .is_numeric
				&& v.numeric_value().equals(new_numeric_from_string('9223372036854775808')) {
				return ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(ValueSpecification(new_bigint_value(-9223372036854775808))))
			}
		}
	}

	return SignedValueExpressionPrimary{sign, &expr}
}

// arithmetic_type is the declared type of a binary arithmetic expression. Two
// numbers of the same category have the more general type, except that an
// exact result with a NUMERIC or DECIMAL operand follows exact_arithmetic_type
// (division is done as multiplication, see Numeric.divide).
//
// ISO/IEC 9075-2:2016(E), 6.29, <numeric value expression>, Syntax Rules, 1
fn arithmetic_type(t1 Type, t2 Type, op string) Type {
	if t1.typ.is_number() && t2.typ.is_number() {
		t1_category, _ := t1.typ.supertype()
		t2_category, _ := t2.typ.supertype()
		if t1_category == 2 && t2_category == 2
			&& (t1.typ in [.is_numeric, .is_decimal] || t2.typ in [.is_numeric, .is_decimal]) {
			return exact_arithmetic_type(t1, t2, if op == '/' { '*' } else { op })
		}

		if t := most_specific_type(t1, t2) {
			return t
		}
	}

	return t1
}

fn eval_binary(mut conn Connection, x Value, op string, y Value) !Value {
	mut left := x
	mut right := y

	mut key := '${left.typ.typ} ${op} ${right.typ.typ}'
	if left.typ.typ.is_number() && right.typ.typ.is_number() {
		supertype := most_specific_type(left.typ, right.typ) or {
			return sqlstate_42883('operator does not exist: ${key}')
		}
		left = cast(mut conn, '', left, implicit_cast_type(left, supertype))!
		right = cast(mut conn, '', right, implicit_cast_type(right, supertype))!
		key = '${supertype.typ} ${op} ${supertype.typ}'
	}

	if fnc := conn.binary_operators[key] {
		// ISO/IEC 9075-2:2016(E), 6.29, <numeric value expression>, General
		// Rules, 1
		if left.is_null || right.is_null {
			return Value{
				typ:     left.typ
				is_null: true
			}
		}

		op_fn := fnc as BinaryOperatorFunc
		return op_fn(conn, left, right)
	}

	return sqlstate_42883('operator does not exist: ${key}')
}
