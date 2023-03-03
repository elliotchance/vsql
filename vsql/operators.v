// operators.v contains functions that satify different unary and binary
// operators in expressions.

module vsql

type UnaryOperatorFunc = fn (conn &Connection, v Value) !Value

type BinaryOperatorFunc = fn (conn &Connection, a Value, b Value) !Value

fn register_operators(mut conn Connection) {
	register_unary_operators(mut conn)
	register_binary_operators(mut conn)
}

fn register_unary_operators(mut conn Connection) {
	conn.unary_operators['- NUMERIC'] = unary_negate_numeric
	conn.unary_operators['- BIGINT'] = unary_negate_bigint
	conn.unary_operators['- DOUBLE PRECISION'] = unary_negate_double_precision

	conn.unary_operators['+ NUMERIC'] = unary_passthru
	conn.unary_operators['+ BIGINT'] = unary_passthru
	conn.unary_operators['+ DOUBLE PRECISION'] = unary_passthru

	conn.unary_operators['NOT BOOLEAN'] = unary_not_boolean
}

fn register_binary_operators(mut conn Connection) {
	// Since many types share the same underlying memory, we can create a matrix
	// of compatible operators that use the same function.
	int_types := ['SMALLINT', 'INTEGER', 'BIGINT', 'NUMERIC']
	float_types := ['REAL', 'DOUBLE PRECISION', 'NUMERIC']
	text_types := ['CHARACTER VARYING']

	for typ1 in int_types {
		for typ2 in int_types {
			conn.binary_operators['${typ1} = ${typ2}'] = binary_int_equal_int
			conn.binary_operators['${typ1} <> ${typ2}'] = binary_int_not_equal_int
			conn.binary_operators['${typ1} < ${typ2}'] = binary_int_less_int
			conn.binary_operators['${typ1} > ${typ2}'] = binary_int_greater_int
			conn.binary_operators['${typ1} <= ${typ2}'] = binary_int_less_equal_int
			conn.binary_operators['${typ1} >= ${typ2}'] = binary_int_greater_equal_int
		}
	}

	for typ1 in float_types {
		for typ2 in float_types {
			conn.binary_operators['${typ1} = ${typ2}'] = binary_float_equal_float
			conn.binary_operators['${typ1} <> ${typ2}'] = binary_float_not_equal_float
			conn.binary_operators['${typ1} < ${typ2}'] = binary_float_less_float
			conn.binary_operators['${typ1} > ${typ2}'] = binary_float_greater_float
			conn.binary_operators['${typ1} <= ${typ2}'] = binary_float_less_equal_float
			conn.binary_operators['${typ1} >= ${typ2}'] = binary_float_greater_equal_float
		}
	}

	for typ1 in text_types {
		for typ2 in text_types {
			conn.binary_operators['${typ1} = ${typ2}'] = binary_string_equal_string
			conn.binary_operators['${typ1} <> ${typ2}'] = binary_string_not_equal_string
			conn.binary_operators['${typ1} < ${typ2}'] = binary_string_less_string
			conn.binary_operators['${typ1} > ${typ2}'] = binary_string_greater_string
			conn.binary_operators['${typ1} <= ${typ2}'] = binary_string_less_equal_string
			conn.binary_operators['${typ1} >= ${typ2}'] = binary_string_greater_equal_string
		}
	}

	conn.binary_operators['NUMERIC + SMALLINT'] = binary_numeric_plus_smallint
	conn.binary_operators['SMALLINT + NUMERIC'] = binary_smallint_plus_numeric
	conn.binary_operators['NUMERIC - SMALLINT'] = binary_numeric_minus_smallint
	conn.binary_operators['SMALLINT - NUMERIC'] = binary_smallint_minus_numeric
	conn.binary_operators['NUMERIC * SMALLINT'] = binary_numeric_multiply_smallint
	conn.binary_operators['SMALLINT * NUMERIC'] = binary_smallint_multiply_numeric
	conn.binary_operators['NUMERIC / SMALLINT'] = binary_numeric_divide_smallint
	conn.binary_operators['SMALLINT / NUMERIC'] = binary_smallint_divide_numeric

	conn.binary_operators['NUMERIC + INTEGER'] = binary_numeric_plus_integer
	conn.binary_operators['INTEGER + NUMERIC'] = binary_integer_plus_numeric
	conn.binary_operators['NUMERIC - INTEGER'] = binary_numeric_minus_integer
	conn.binary_operators['INTEGER - NUMERIC'] = binary_integer_minus_numeric
	conn.binary_operators['NUMERIC * INTEGER'] = binary_numeric_multiply_integer
	conn.binary_operators['INTEGER * NUMERIC'] = binary_integer_multiply_numeric
	conn.binary_operators['NUMERIC / INTEGER'] = binary_numeric_divide_integer
	conn.binary_operators['INTEGER / NUMERIC'] = binary_integer_divide_numeric

	conn.binary_operators['NUMERIC + BIGINT'] = binary_numeric_plus_bigint
	conn.binary_operators['BIGINT + NUMERIC'] = binary_bigint_plus_numeric
	conn.binary_operators['NUMERIC - BIGINT'] = binary_numeric_minus_bigint
	conn.binary_operators['BIGINT - NUMERIC'] = binary_bigint_minus_numeric
	conn.binary_operators['NUMERIC * BIGINT'] = binary_numeric_multiply_bigint
	conn.binary_operators['BIGINT * NUMERIC'] = binary_bigint_multiply_numeric
	conn.binary_operators['NUMERIC / BIGINT'] = binary_numeric_divide_bigint
	conn.binary_operators['BIGINT / NUMERIC'] = binary_bigint_divide_numeric

	conn.binary_operators['NUMERIC + DOUBLE PRECISION'] = binary_numeric_plus_double_precision
	conn.binary_operators['DOUBLE PRECISION + NUMERIC'] = binary_double_precision_plus_numeric
	conn.binary_operators['NUMERIC - DOUBLE PRECISION'] = binary_numeric_minus_double_precision
	conn.binary_operators['DOUBLE PRECISION - NUMERIC'] = binary_double_precision_minus_numeric
	conn.binary_operators['NUMERIC * DOUBLE PRECISION'] = binary_numeric_multiply_double_precision
	conn.binary_operators['DOUBLE PRECISION * NUMERIC'] = binary_double_precision_multiply_numeric
	conn.binary_operators['NUMERIC / DOUBLE PRECISION'] = binary_numeric_divide_double_precision
	conn.binary_operators['DOUBLE PRECISION / NUMERIC'] = binary_double_precision_divide_numeric

	conn.binary_operators['NUMERIC + REAL'] = binary_numeric_plus_real
	conn.binary_operators['REAL + NUMERIC'] = binary_real_plus_numeric
	conn.binary_operators['NUMERIC - REAL'] = binary_numeric_minus_real
	conn.binary_operators['REAL - NUMERIC'] = binary_real_minus_numeric
	conn.binary_operators['NUMERIC * REAL'] = binary_numeric_multiply_real
	conn.binary_operators['REAL * NUMERIC'] = binary_real_multiply_numeric
	conn.binary_operators['NUMERIC / REAL'] = binary_numeric_divide_real
	conn.binary_operators['REAL / NUMERIC'] = binary_real_divide_numeric

	conn.binary_operators['NUMERIC + NUMERIC'] = binary_numeric_plus_numeric
	conn.binary_operators['NUMERIC - NUMERIC'] = binary_numeric_minus_numeric
	conn.binary_operators['NUMERIC * NUMERIC'] = binary_numeric_multiply_numeric
	conn.binary_operators['NUMERIC / NUMERIC'] = binary_numeric_divide_numeric

	conn.binary_operators['DOUBLE PRECISION + DOUBLE PRECISION'] = binary_double_precision_plus_double_precision
	conn.binary_operators['INTEGER + INTEGER'] = binary_integer_plus_integer
	conn.binary_operators['BIGINT + BIGINT'] = binary_bigint_plus_bigint

	conn.binary_operators['DOUBLE PRECISION - DOUBLE PRECISION'] = binary_double_precision_minus_double_precision
	conn.binary_operators['INTEGER - INTEGER'] = binary_integer_minus_integer
	conn.binary_operators['BIGINT - BIGINT'] = binary_bigint_minus_bigint

	conn.binary_operators['DOUBLE PRECISION * DOUBLE PRECISION'] = binary_double_precision_multiply_double_precision
	conn.binary_operators['INTEGER * INTEGER'] = binary_integer_multiply_integer
	conn.binary_operators['BIGINT * BIGINT'] = binary_bigint_multiply_bigint

	conn.binary_operators['DOUBLE PRECISION / DOUBLE PRECISION'] = binary_double_precision_divide_double_precision
	conn.binary_operators['INTEGER / INTEGER'] = binary_integer_divide_integer
	conn.binary_operators['BIGINT / BIGINT'] = binary_bigint_divide_bigint

	conn.binary_operators['CHARACTER VARYING || CHARACTER VARYING'] = binary_varchar_concat_varchar

	conn.binary_operators['BOOLEAN AND BOOLEAN'] = binary_boolean_and_boolean

	conn.binary_operators['BOOLEAN OR BOOLEAN'] = binary_boolean_or_boolean
}

fn unary_passthru(conn &Connection, v Value) !Value {
	return v
}

fn unary_negate_numeric(conn &Connection, v Value) !Value {
	if v.string_value().starts_with('-') {
		return new_numeric_value(v.string_value()[1..])
	}

	return new_numeric_value('-${v.string_value()}')
}

fn unary_negate_bigint(conn &Connection, v Value) !Value {
	return new_bigint_value(-v.int_value())
}

fn unary_negate_double_precision(conn &Connection, v Value) !Value {
	return new_double_precision_value(-v.f64_value())
}

fn unary_not_boolean(conn &Connection, v Value) !Value {
	return match v.bool_value() {
		.is_true { new_boolean_value(false) }
		.is_false { new_boolean_value(true) }
		.is_unknown { new_unknown_value() }
	}
}

fn binary_double_precision_plus_double_precision(conn &Connection, a Value, b Value) !Value {
	return new_double_precision_value(a.f64_value() + b.f64_value())
}

fn binary_integer_plus_integer(conn &Connection, a Value, b Value) !Value {
	return new_integer_value(int(a.as_int() + b.as_int()))
}

fn binary_bigint_plus_bigint(conn &Connection, a Value, b Value) !Value {
	return new_bigint_value(a.int_value() + b.int_value())
}

fn binary_double_precision_minus_double_precision(conn &Connection, a Value, b Value) !Value {
	return new_double_precision_value(a.f64_value() - b.f64_value())
}

fn binary_integer_minus_integer(conn &Connection, a Value, b Value) !Value {
	return new_integer_value(int(a.as_int() - b.as_int()))
}

fn binary_bigint_minus_bigint(conn &Connection, a Value, b Value) !Value {
	return new_bigint_value(a.int_value() - b.int_value())
}

fn binary_double_precision_multiply_double_precision(conn &Connection, a Value, b Value) !Value {
	return new_double_precision_value(a.f64_value() * b.f64_value())
}

fn binary_integer_multiply_integer(conn &Connection, a Value, b Value) !Value {
	return new_integer_value(int(a.as_int() * b.as_int()))
}

fn binary_bigint_multiply_bigint(conn &Connection, a Value, b Value) !Value {
	return new_bigint_value(a.int_value() * b.int_value())
}

fn binary_double_precision_divide_double_precision(conn &Connection, a Value, b Value) !Value {
	if b.f64_value() == 0 {
		return sqlstate_22012() // division by zero
	}

	return new_double_precision_value(a.f64_value() / b.f64_value())
}

fn binary_integer_divide_integer(conn &Connection, a Value, b Value) !Value {
	if b.int_value() == 0 {
		return sqlstate_22012() // division by zero
	}

	return new_integer_value(int(a.as_int() / b.as_int()))
}

fn binary_bigint_divide_bigint(conn &Connection, a Value, b Value) !Value {
	if b.int_value() == 0 {
		return sqlstate_22012() // division by zero
	}

	return new_bigint_value(a.int_value() / b.int_value())
}

fn binary_varchar_concat_varchar(conn &Connection, a Value, b Value) !Value {
	return new_varchar_value(a.string_value() + b.string_value(), 0)
}

fn binary_boolean_and_boolean(conn &Connection, a Value, b Value) !Value {
	match a.bool_value() {
		.is_true {
			return match b.bool_value() {
				.is_true { new_boolean_value(true) }
				.is_false { new_boolean_value(false) }
				.is_unknown { new_unknown_value() }
			}
		}
		.is_false {
			return new_boolean_value(false)
		}
		.is_unknown {
			return match b.bool_value() {
				.is_true { new_unknown_value() }
				.is_false { new_boolean_value(false) }
				.is_unknown { new_unknown_value() }
			}
		}
	}
}

fn binary_boolean_or_boolean(conn &Connection, a Value, b Value) !Value {
	match a.bool_value() {
		.is_true {
			return new_boolean_value(true)
		}
		.is_false {
			return match b.bool_value() {
				.is_true { new_boolean_value(true) }
				.is_false { new_boolean_value(false) }
				.is_unknown { new_unknown_value() }
			}
		}
		.is_unknown {
			return match b.bool_value() {
				.is_true { new_boolean_value(true) }
				.is_false { new_unknown_value() }
				.is_unknown { new_unknown_value() }
			}
		}
	}
}

fn binary_float_equal_float(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.as_f64() == b.as_f64())
}

fn binary_int_equal_int(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.as_int() == b.as_int())
}

fn binary_string_equal_string(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.string_value() == b.string_value())
}

fn binary_float_not_equal_float(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.as_f64() != b.as_f64())
}

fn binary_int_not_equal_int(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.as_int() != b.as_int())
}

fn binary_string_not_equal_string(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.string_value() != b.string_value())
}

fn binary_float_less_float(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.as_f64() < b.as_f64())
}

fn binary_int_less_int(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.as_int() < b.as_int())
}

fn binary_string_less_string(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.string_value() < b.string_value())
}

fn binary_float_greater_float(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.as_f64() > b.as_f64())
}

fn binary_int_greater_int(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.as_int() > b.as_int())
}

fn binary_string_greater_string(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.string_value() > b.string_value())
}

fn binary_float_less_equal_float(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.as_f64() <= b.as_f64())
}

fn binary_int_less_equal_int(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.as_int() <= b.as_int())
}

fn binary_string_less_equal_string(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.string_value() <= b.string_value())
}

fn binary_float_greater_equal_float(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.as_f64() >= b.as_f64())
}

fn binary_int_greater_equal_int(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.as_int() >= b.as_int())
}

fn binary_string_greater_equal_string(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.string_value() >= b.string_value())
}

fn binary_smallint_plus_numeric(conn &Connection, a Value, b Value) !Value {
	// TODO(elliotchance): This should use NUMERIC math to catch all overflows.
	x := i64(a.int_value() + b.as_f64())
	check_integer_range(x, .is_smallint)!

	return new_smallint_value(i16(x))
}

fn binary_numeric_plus_smallint(conn &Connection, a Value, b Value) !Value {
	// TODO(elliotchance): This should use NUMERIC math to catch all overflows.
	x := i64(a.as_f64() + b.int_value())
	check_integer_range(x, .is_smallint)!

	return new_smallint_value(i16(x))
}

fn binary_smallint_minus_numeric(conn &Connection, a Value, b Value) !Value {
	// TODO(elliotchance): This should use NUMERIC math to catch all overflows.
	x := i64(a.int_value() - b.as_f64())
	check_integer_range(x, .is_smallint)!

	return new_smallint_value(i16(x))
}

fn binary_numeric_minus_smallint(conn &Connection, a Value, b Value) !Value {
	// TODO(elliotchance): This should use NUMERIC math to catch all overflows.
	x := i64(a.as_f64() - b.int_value())
	check_integer_range(x, .is_smallint)!

	return new_smallint_value(i16(x))
}

fn binary_smallint_multiply_numeric(conn &Connection, a Value, b Value) !Value {
	// TODO(elliotchance): This should use NUMERIC math to catch all overflows.
	x := i64(a.int_value() * b.as_f64())
	check_integer_range(x, .is_smallint)!

	return new_smallint_value(i16(x))
}

fn binary_numeric_multiply_smallint(conn &Connection, a Value, b Value) !Value {
	// TODO(elliotchance): This should use NUMERIC math to catch all overflows.
	x := i64(a.as_f64() * b.int_value())
	check_integer_range(x, .is_smallint)!

	return new_smallint_value(i16(x))
}

fn binary_smallint_divide_numeric(conn &Connection, a Value, b Value) !Value {
	if b.as_f64() == 0 {
		return sqlstate_22012() // division by zero
	}

	// TODO(elliotchance): This should use NUMERIC math to catch all overflows.
	x := i64(a.int_value() / b.as_f64())
	check_integer_range(x, .is_smallint)!

	return new_smallint_value(i16(x))
}

fn binary_numeric_divide_smallint(conn &Connection, a Value, b Value) !Value {
	if b.as_f64() == 0 {
		return sqlstate_22012() // division by zero
	}

	// TODO(elliotchance): This should use NUMERIC math to catch all overflows.
	x := i64(a.as_f64() / b.int_value())
	check_integer_range(x, .is_smallint)!

	return new_smallint_value(i16(x))
}

fn binary_integer_plus_numeric(conn &Connection, a Value, b Value) !Value {
	// TODO(elliotchance): This should use NUMERIC math to catch all overflows.
	x := i64(a.int_value() + b.as_f64())
	check_integer_range(x, .is_integer)!

	return new_integer_value(int(x))
}

fn binary_numeric_plus_integer(conn &Connection, a Value, b Value) !Value {
	// TODO(elliotchance): This should use NUMERIC math to catch all overflows.
	x := i64(a.as_f64() + b.int_value())
	check_integer_range(x, .is_integer)!

	return new_integer_value(int(x))
}

fn binary_integer_minus_numeric(conn &Connection, a Value, b Value) !Value {
	// TODO(elliotchance): This should use NUMERIC math to catch all overflows.
	x := i64(a.int_value() - b.as_f64())
	check_integer_range(x, .is_integer)!

	return new_integer_value(int(x))
}

fn binary_numeric_minus_integer(conn &Connection, a Value, b Value) !Value {
	// TODO(elliotchance): This should use NUMERIC math to catch all overflows.
	x := i64(a.as_f64() - b.int_value())
	check_integer_range(x, .is_integer)!

	return new_integer_value(int(x))
}

fn binary_integer_multiply_numeric(conn &Connection, a Value, b Value) !Value {
	// TODO(elliotchance): This should use NUMERIC math to catch all overflows.
	x := i64(a.int_value() * b.as_f64())
	check_integer_range(x, .is_integer)!

	return new_integer_value(int(x))
}

fn binary_numeric_multiply_integer(conn &Connection, a Value, b Value) !Value {
	// TODO(elliotchance): This should use NUMERIC math to catch all overflows.
	x := i64(a.as_f64() * b.int_value())
	check_integer_range(x, .is_integer)!

	return new_integer_value(int(x))
}

fn binary_integer_divide_numeric(conn &Connection, a Value, b Value) !Value {
	if b.as_f64() == 0 {
		return sqlstate_22012() // division by zero
	}

	// TODO(elliotchance): This should use NUMERIC math to catch all overflows.
	x := i64(a.int_value() / b.as_f64())
	check_integer_range(x, .is_integer)!

	return new_integer_value(int(x))
}

fn binary_numeric_divide_integer(conn &Connection, a Value, b Value) !Value {
	if b.as_f64() == 0 {
		return sqlstate_22012() // division by zero
	}

	// TODO(elliotchance): This should use NUMERIC math to catch all overflows.
	x := i64(a.as_f64() / b.int_value())
	check_integer_range(x, .is_integer)!

	return new_integer_value(int(x))
}

fn binary_bigint_plus_numeric(conn &Connection, a Value, b Value) !Value {
	x := a.as_numeric()! + b.as_numeric()!
	check_numeric_range(x, .is_bigint)!

	return new_bigint_value(x.str().i64())
}

fn binary_numeric_plus_bigint(conn &Connection, a Value, b Value) !Value {
	x := a.as_numeric()! + b.as_numeric()!
	check_numeric_range(x, .is_bigint)!

	return new_bigint_value(x.str().i64())
}

fn binary_bigint_minus_numeric(conn &Connection, a Value, b Value) !Value {
	x := a.as_numeric()! - b.as_numeric()!
	check_numeric_range(x, .is_bigint)!

	return new_bigint_value(x.str().i64())
}

fn binary_numeric_minus_bigint(conn &Connection, a Value, b Value) !Value {
	x := a.as_numeric()! - b.as_numeric()!
	check_numeric_range(x, .is_bigint)!

	return new_bigint_value(x.str().i64())
}

fn binary_bigint_multiply_numeric(conn &Connection, a Value, b Value) !Value {
	x := a.as_numeric()! * b.as_numeric()!
	check_numeric_range(x, .is_bigint)!

	return new_bigint_value(x.str().i64())
}

fn binary_numeric_multiply_bigint(conn &Connection, a Value, b Value) !Value {
	x := a.as_numeric()! * b.as_numeric()!
	check_numeric_range(x, .is_bigint)!

	return new_bigint_value(x.str().i64())
}

fn binary_bigint_divide_numeric(conn &Connection, a Value, b Value) !Value {
	if b.as_int() == 0 {
		return sqlstate_22012() // division by zero
	}

	x := a.as_numeric()! / b.as_numeric()!
	check_numeric_range(x, .is_bigint)!

	return new_bigint_value(x.str().i64())
}

fn binary_numeric_divide_bigint(conn &Connection, a Value, b Value) !Value {
	if b.as_int() == 0 {
		return sqlstate_22012() // division by zero
	}

	x := a.as_numeric()! / b.as_numeric()!
	check_numeric_range(x, .is_bigint)!

	return new_bigint_value(x.str().i64())
}

fn binary_double_precision_plus_numeric(conn &Connection, a Value, b Value) !Value {
	return new_double_precision_value(a.as_f64() + b.as_f64())
}

fn binary_numeric_plus_double_precision(conn &Connection, a Value, b Value) !Value {
	return new_double_precision_value(a.as_f64() + b.as_f64())
}

fn binary_double_precision_minus_numeric(conn &Connection, a Value, b Value) !Value {
	return new_double_precision_value(a.as_f64() - b.as_f64())
}

fn binary_numeric_minus_double_precision(conn &Connection, a Value, b Value) !Value {
	return new_double_precision_value(a.as_f64() - b.as_f64())
}

fn binary_double_precision_multiply_numeric(conn &Connection, a Value, b Value) !Value {
	return new_double_precision_value(a.as_f64() * b.as_f64())
}

fn binary_numeric_multiply_double_precision(conn &Connection, a Value, b Value) !Value {
	return new_double_precision_value(a.as_f64() * b.as_f64())
}

fn binary_double_precision_divide_numeric(conn &Connection, a Value, b Value) !Value {
	if b.as_f64() == 0 {
		return sqlstate_22012() // division by zero
	}

	return new_double_precision_value(a.as_f64() / b.as_f64())
}

fn binary_numeric_divide_double_precision(conn &Connection, a Value, b Value) !Value {
	if b.as_f64() == 0 {
		return sqlstate_22012() // division by zero
	}

	return new_double_precision_value(a.as_f64() / b.as_f64())
}

fn binary_real_plus_numeric(conn &Connection, a Value, b Value) !Value {
	return new_real_value(f32(a.as_f64() + b.as_f64()))
}

fn binary_numeric_plus_real(conn &Connection, a Value, b Value) !Value {
	return new_real_value(f32(a.as_f64() + b.as_f64()))
}

fn binary_real_minus_numeric(conn &Connection, a Value, b Value) !Value {
	return new_real_value(f32(a.as_f64() - b.as_f64()))
}

fn binary_numeric_minus_real(conn &Connection, a Value, b Value) !Value {
	return new_real_value(f32(a.as_f64() - b.as_f64()))
}

fn binary_real_multiply_numeric(conn &Connection, a Value, b Value) !Value {
	return new_real_value(f32(a.as_f64() * b.as_f64()))
}

fn binary_numeric_multiply_real(conn &Connection, a Value, b Value) !Value {
	return new_real_value(f32(a.as_f64() * b.as_f64()))
}

fn binary_real_divide_numeric(conn &Connection, a Value, b Value) !Value {
	if b.as_f64() == 0 {
		return sqlstate_22012() // division by zero
	}

	return new_real_value(f32(a.as_f64() / b.as_f64()))
}

fn binary_numeric_divide_real(conn &Connection, a Value, b Value) !Value {
	if b.as_f64() == 0 {
		return sqlstate_22012() // division by zero
	}

	return new_real_value(f32(a.as_f64() / b.as_f64()))
}

fn binary_numeric_plus_numeric(conn &Connection, a Value, b Value) !Value {
	return new_numeric_value(f64_string(a.as_f64() + b.as_f64()))
}

fn binary_numeric_minus_numeric(conn &Connection, a Value, b Value) !Value {
	return new_numeric_value(f64_string(a.as_f64() - b.as_f64()))
}

fn binary_numeric_multiply_numeric(conn &Connection, a Value, b Value) !Value {
	return new_numeric_value(f64_string(a.as_f64() * b.as_f64()))
}

fn binary_numeric_divide_numeric(conn &Connection, a Value, b Value) !Value {
	if b.as_f64() == 0 {
		return sqlstate_22012() // division by zero
	}

	return new_numeric_value(f64_string(a.as_f64() / b.as_f64()))
}
