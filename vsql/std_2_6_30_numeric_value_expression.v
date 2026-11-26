module vsql

// ISO/IEC 9075-2:2023, 6.30, <numeric value expression>
//
// Specify a numeric value.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2023, 4.5.3, Operations involving numbers

struct NumericValueExpression {
	n    ?&NumericValueExpression
	op   string
	term Term
}

fn (e NumericValueExpression) pstr(params map[string]Value) string {
	if n := opt_copy(e.n) {
		return '${n.pstr(params)} ${e.op} ${e.term.pstr(params)}'
	}

	return e.term.pstr(params)
}

fn (e NumericValueExpression) compile(mut c Compiler) !CompileResult {
	// A pointer to a copy is captured instead of the value to work around
	// https://github.com/vlang/v/issues/32934 (-autofree).
	e_ref := &NumericValueExpression{
		...e
	}
	mut compiled_term := e.term.compile(mut c)!

	if n := opt_copy(e.n) {
		mut compiled_n := n.compile(mut c)!
		datetime_result, is_datetime := c.compile_datetime_arithmetic(compiled_n, e.op,
			compiled_term)!
		if is_datetime {
			return datetime_result
		}

		// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.xi
		compiled_n, compiled_term = c.with_pair_types(compiled_n, compiled_term, same_type)

		return CompileResult{
			run:          fn [e_ref, compiled_n, compiled_term] (mut conn Connection, data Row, params map[string]Value) !Value {
				mut left := compiled_n.run(mut conn, data, params)!
				mut right := compiled_term.run(mut conn, data, params)!

				return eval_binary(mut conn, left, e_ref.op, right)!
			}
			typ:          arithmetic_type(compiled_n.typ, compiled_term.typ, e.op)!
			contains_agg: compiled_term.contains_agg || compiled_n.contains_agg
			constant:     compiled_n.constant && compiled_term.constant
		}.fold()
	}

	return compiled_term
}

struct Term {
	term   ?&Term
	op     string
	factor NumericPrimary
}

fn (e Term) pstr(params map[string]Value) string {
	if term := opt_copy(e.term) {
		return '${term.pstr(params)} ${e.op} ${e.factor.pstr(params)}'
	}

	return e.factor.pstr(params)
}

fn (e Term) compile(mut c Compiler) !CompileResult {
	// A pointer to a copy is captured instead of the value to work around
	// https://github.com/vlang/v/issues/32934 (-autofree).
	e_ref := &Term{
		...e
	}
	mut compiled_factor := e.factor.compile(mut c)!

	if term := opt_copy(e.term) {
		mut compiled_term := term.compile(mut c)!
		datetime_result, is_datetime := c.compile_datetime_arithmetic(compiled_term, e.op,
			compiled_factor)!
		if is_datetime {
			return datetime_result
		}

		// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.x
		compiled_term, compiled_factor = c.with_pair_types(compiled_term, compiled_factor,
			same_type)

		return CompileResult{
			run:          fn [e_ref, compiled_term, compiled_factor] (mut conn Connection, data Row, params map[string]Value) !Value {
				mut left := compiled_term.run(mut conn, data, params)!
				mut right := compiled_factor.run(mut conn, data, params)!

				return eval_binary(mut conn, left, e_ref.op, right)!
			}
			typ:          arithmetic_type(compiled_term.typ, compiled_factor.typ, e.op)!
			contains_agg: compiled_factor.contains_agg || compiled_term.contains_agg
			constant:     compiled_term.constant && compiled_factor.constant
		}.fold()
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
	// A pointer to a copy is captured instead of the value to work around
	// https://github.com/vlang/v/issues/32934 (-autofree).
	e_ref := &SignedValueExpressionPrimary{
		...e
	}
	compiled := e.e.compile(mut c)!

	return CompileResult{
		run:          fn [e_ref, compiled] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled.run(mut conn, data, params)!

			key := '${e_ref.sign} ${value.typ.typ}'
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
		constant:     compiled.constant
	}.fold()
}

type NumericPrimary = &TimeZoneExpression
	| DatetimeValueFunction
	| ExtractExpression
	| IntervalQualifiedPrimary
	| RoutineInvocation
	| SignedValueExpressionPrimary
	| ValueExpressionPrimary

fn (e NumericPrimary) pstr(params map[string]Value) string {
	return match e {
		SignedValueExpressionPrimary, ValueExpressionPrimary, RoutineInvocation, ExtractExpression,
		IntervalQualifiedPrimary, DatetimeValueFunction, &TimeZoneExpression {
			e.pstr(params)
		}
	}
}

fn (e NumericPrimary) compile(mut c Compiler) !CompileResult {
	match e {
		SignedValueExpressionPrimary, ValueExpressionPrimary, RoutineInvocation, ExtractExpression,
		IntervalQualifiedPrimary, DatetimeValueFunction, &TimeZoneExpression {
			return e.compile(mut c)!
		}
	}
}

// numeric_primary_of_datetime is the NumericPrimary of a datetime_factor that's
// an operand of datetime arithmetic. A datetime_factor is never only a
// ValueExpressionPrimary (that's a numeric_primary already), so it's a datetime
// value function or has a time zone.
fn numeric_primary_of_datetime(e DatetimePrimary) NumericPrimary {
	if e is DatetimeValueFunction {
		return NumericPrimary(e)
	}

	return NumericPrimary(e as &TimeZoneExpression)
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
	// For example, INTEGER range is -2147483648 to 2147483647. However, if we
	// consume 2147483648 first it would be given a BIGINT type (because it's
	// out of range) so the negation would also be a BIGINT when -2147483648
	// really should be an INTEGER.
	if v := expr.value() {
		if sign == '-' {
			if v.typ.typ == .is_bigint && v.int_value() == 2147483648 {
				return ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(ValueSpecification(new_integer_value(-2147483648))))
			}

			if v.typ.typ == .is_numeric
				&& v.numeric_value().equals(new_numeric_from_string('9223372036854775808')) {
				return ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(ValueSpecification(new_bigint_value(-9223372036854775808))))
			}
		}
	}

	return SignedValueExpressionPrimary{sign, heap_copy(&expr)}
}

// arithmetic_type is the declared type of a binary arithmetic expression. Two
// numbers of the same category have the more general type, except that an
// exact result with a NUMERIC or DECIMAL operand follows exact_arithmetic_type
// (see division_scale for a division), and it's an error
// if its scale is more than the maximum (see check_derived_scale). See
// arithmetic_supertype for an exact and an approximate number.
//
// ISO/IEC 9075-2:2023, 6.30, <numeric value expression>, Syntax Rules, 1
fn arithmetic_type(t1 Type, t2 Type, op string) !Type {
	// ISO/IEC 9075-2:2023, 6.30, <numeric value expression>, Syntax Rules, 1.a
	if t := decfloat_supertype(t1, t2) {
		return t
	}

	t1_category, _ := t1.typ.supertype()
	t2_category, _ := t2.typ.supertype()
	if t1_category == 2 && t2_category == 2
		&& (t1.typ in [.is_numeric, .is_decimal] || t2.typ in [.is_numeric, .is_decimal]) {
		return check_derived_scale(exact_arithmetic_type(t1, t2, op))!
	}

	// Two numbers always have one. The operator doesn't exist for anything else,
	// which eval_binary reports.
	return arithmetic_supertype(t1, t2) or { t1 }
}

// arithmetic_supertype is the type that both operands are cast to. If either is
// a DECFLOAT, it's a DECFLOAT (see decfloat_supertype). If either is
// approximate, the result is approximate (Syntax Rule 1b). Like the rows of a
// VALUES (9.5 Syntax Rule 3d), that's DOUBLE PRECISION, unless both are REAL.
fn arithmetic_supertype(t1 Type, t2 Type) !Type {
	if t := decfloat_supertype(t1, t2) {
		return t
	}

	if (t1.typ in approximate_types) != (t2.typ in approximate_types) {
		return Type{.is_double_precision, 0, 0, false, false}
	}

	return most_specific_type(t1, t2)
}

fn eval_binary(mut conn Connection, x Value, op string, y Value) !Value {
	mut left := x
	mut right := y

	mut key := '${left.typ.typ} ${op} ${right.typ.typ}'
	if left.typ.typ.is_number() && right.typ.typ.is_number() {
		supertype := arithmetic_supertype(left.typ, right.typ) or {
			return sqlstate_42883('operator does not exist: ${key}')
		}
		left = cast(mut conn, '', left, implicit_cast_type(left, supertype))!
		right = cast(mut conn, '', right, implicit_cast_type(right, supertype))!
		key = '${supertype.typ} ${op} ${supertype.typ}'
	}

	if fnc := conn.binary_operators[key] {
		// ISO/IEC 9075-2:2023, 6.30, <numeric value expression>, General
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

// decfloat_supertype is the type of an operation on two numbers when either is
// a DECFLOAT, or none if neither is. Its precision is implementation-defined,
// so it's the larger precision of the DECFLOATs, and the other number (an exact
// or approximate number) is cast to it.
//
// ISO/IEC 9075-2:2023, 6.30, <numeric value expression>, Syntax Rules, 1.a
fn decfloat_supertype(t1 Type, t2 Type) ?Type {
	if !t1.typ.is_number() || !t2.typ.is_number()
		|| (t1.typ != .is_decfloat && t2.typ != .is_decfloat) {
		return none
	}

	return Type{.is_decfloat, decfloat_precision([t1, t2]), 0, false, false}
}

// decfloat_precision is the largest precision of the DECFLOATs in types. A
// DECFLOAT without a precision has the maximum precision.
fn decfloat_precision(types []Type) int {
	mut p := 0
	for t in types {
		if t.typ == .is_decfloat {
			p = int_max(p, if t.size == 0 { max_decfloat_precision } else { t.size })
		}
	}

	return if p == 0 { max_decfloat_precision } else { p }
}
