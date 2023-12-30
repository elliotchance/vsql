// operators.v contains functions that satify different unary and binary
// operators in expressions.

module vsql

import math.big

type UnaryOperatorFunc = fn (conn &Connection, v Value) !Value

type BinaryOperatorFunc = fn (conn &Connection, a Value, b Value) !Value

fn register_operators(mut conn Connection) {
	register_unary_operators(mut conn)
	register_binary_operators(mut conn)
}

fn register_unary_operators(mut conn Connection) {
	conn.unary_operators['- NUMERIC'] = unary_negate_numeric
	conn.unary_operators['- DECIMAL'] = unary_negate_decimal
	conn.unary_operators['- BIGINT'] = unary_negate_bigint
	conn.unary_operators['- DOUBLE PRECISION'] = unary_negate_double_precision
	conn.unary_operators['- REAL'] = unary_negate_real
	conn.unary_operators['- SMALLINT'] = unary_negate_smallint
	conn.unary_operators['- INTEGER'] = unary_negate_integer

	conn.unary_operators['+ NUMERIC'] = unary_passthru
	conn.unary_operators['+ DECIMAL'] = unary_passthru
	conn.unary_operators['+ BIGINT'] = unary_passthru
	conn.unary_operators['+ DOUBLE PRECISION'] = unary_passthru
	conn.unary_operators['+ REAL'] = unary_passthru
	conn.unary_operators['+ INTEGER'] = unary_passthru
	conn.unary_operators['+ SMALLINT'] = unary_passthru
}

fn register_binary_operators(mut conn Connection) {
	conn.binary_operators['NUMERIC + NUMERIC'] = binary_numeric_plus_numeric
	conn.binary_operators['NUMERIC - NUMERIC'] = binary_numeric_minus_numeric
	conn.binary_operators['NUMERIC * NUMERIC'] = binary_numeric_multiply_numeric
	conn.binary_operators['NUMERIC / NUMERIC'] = binary_numeric_divide_numeric

	conn.binary_operators['DECIMAL + DECIMAL'] = binary_decimal_plus_decimal
	conn.binary_operators['DECIMAL - DECIMAL'] = binary_decimal_minus_decimal
	conn.binary_operators['DECIMAL * DECIMAL'] = binary_decimal_multiply_decimal
	conn.binary_operators['DECIMAL / DECIMAL'] = binary_decimal_divide_decimal

	conn.binary_operators['DOUBLE PRECISION + DOUBLE PRECISION'] = binary_double_precision_plus_double_precision
	conn.binary_operators['DOUBLE PRECISION - DOUBLE PRECISION'] = binary_double_precision_minus_double_precision
	conn.binary_operators['DOUBLE PRECISION * DOUBLE PRECISION'] = binary_double_precision_multiply_double_precision
	conn.binary_operators['DOUBLE PRECISION / DOUBLE PRECISION'] = binary_double_precision_divide_double_precision

	conn.binary_operators['REAL + REAL'] = binary_real_plus_real
	conn.binary_operators['REAL - REAL'] = binary_real_minus_real
	conn.binary_operators['REAL * REAL'] = binary_real_multiply_real
	conn.binary_operators['REAL / REAL'] = binary_real_divide_real

	conn.binary_operators['SMALLINT + SMALLINT'] = binary_smallint_plus_smallint
	conn.binary_operators['SMALLINT - SMALLINT'] = binary_smallint_minus_smallint
	conn.binary_operators['SMALLINT * SMALLINT'] = binary_smallint_multiply_smallint
	conn.binary_operators['SMALLINT / SMALLINT'] = binary_smallint_divide_smallint

	conn.binary_operators['INTEGER + INTEGER'] = binary_integer_plus_integer
	conn.binary_operators['INTEGER - INTEGER'] = binary_integer_minus_integer
	conn.binary_operators['INTEGER * INTEGER'] = binary_integer_multiply_integer
	conn.binary_operators['INTEGER / INTEGER'] = binary_integer_divide_integer

	conn.binary_operators['BIGINT + BIGINT'] = binary_bigint_plus_bigint
	conn.binary_operators['BIGINT - BIGINT'] = binary_bigint_minus_bigint
	conn.binary_operators['BIGINT * BIGINT'] = binary_bigint_multiply_bigint
	conn.binary_operators['BIGINT / BIGINT'] = binary_bigint_divide_bigint
}

fn unary_passthru(conn &Connection, v Value) !Value {
	return v
}

fn unary_negate_numeric(conn &Connection, v Value) !Value {
	return new_numeric_value_from_numeric(v.numeric_value().neg())
}

fn unary_negate_decimal(conn &Connection, v Value) !Value {
	return new_decimal_value_from_numeric(v.numeric_value().neg())
}

fn unary_negate_bigint(conn &Connection, v Value) !Value {
	return new_bigint_value(-v.int_value())
}

fn unary_negate_smallint(conn &Connection, v Value) !Value {
	// This can't be out of bounds becuase the input type is the same.
	return new_smallint_value(i16(-v.int_value()))
}

fn unary_negate_integer(conn &Connection, v Value) !Value {
	// This can't be out of bounds becuase the input type is the same.
	return new_integer_value(int(-v.int_value()))
}

fn unary_negate_double_precision(conn &Connection, v Value) !Value {
	return new_double_precision_value(-v.f64_value())
}

fn unary_negate_real(conn &Connection, v Value) !Value {
	return new_real_value(f32(-v.f64_value()))
}

fn unary_not_boolean(conn &Connection, v Value) !Value {
	if v.is_null {
		return new_unknown_value()
	}

	return match v.bool_value() {
		.is_true { new_boolean_value(false) }
		.is_false { new_boolean_value(true) }
	}
}

fn binary_double_precision_plus_double_precision(conn &Connection, a Value, b Value) !Value {
	return new_double_precision_value(a.f64_value() + b.f64_value())
}

fn binary_integer_plus_integer(conn &Connection, a Value, b Value) !Value {
	x := i64(a.int_value() + b.int_value())
	check_integer_range(x, .is_integer)!

	return new_integer_value(int(x))
}

fn binary_bigint_plus_bigint(conn &Connection, a Value, b Value) !Value {
	x := big.integer_from_i64(a.as_int())
	y := big.integer_from_i64(b.as_int())
	z := x + y
	check_numeric_range(new_numeric_from_string(z.str()), .is_bigint)!
	return new_bigint_value(z.int())
}

fn binary_double_precision_minus_double_precision(conn &Connection, a Value, b Value) !Value {
	return new_double_precision_value(a.f64_value() - b.f64_value())
}

fn binary_integer_minus_integer(conn &Connection, a Value, b Value) !Value {
	x := i64(a.int_value() - b.as_f64()!)
	check_integer_range(x, .is_integer)!

	return new_integer_value(i16(x))
}

fn binary_bigint_minus_bigint(conn &Connection, a Value, b Value) !Value {
	x := big.integer_from_i64(a.as_int())
	y := big.integer_from_i64(b.as_int())
	z := x - y
	check_numeric_range(new_numeric_from_string(z.str()), .is_bigint)!
	return new_bigint_value(z.int())
}

fn binary_double_precision_multiply_double_precision(conn &Connection, a Value, b Value) !Value {
	return new_double_precision_value(a.f64_value() * b.f64_value())
}

fn binary_integer_multiply_integer(conn &Connection, a Value, b Value) !Value {
	x := i64(a.int_value() * b.as_f64()!)
	check_integer_range(x, .is_integer)!

	return new_integer_value(i16(x))
}

fn binary_bigint_multiply_bigint(conn &Connection, a Value, b Value) !Value {
	x := big.integer_from_i64(a.as_int())
	y := big.integer_from_i64(b.as_int())
	z := x * y
	check_numeric_range(new_numeric_from_string(z.str()), .is_bigint)!
	return new_bigint_value(z.int())
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

fn binary_numeric_plus_numeric(conn &Connection, a Value, b Value) !Value {
	return new_numeric_value_from_numeric(a.numeric_value().add(b.numeric_value()))
}

fn binary_numeric_minus_numeric(conn &Connection, a Value, b Value) !Value {
	return new_numeric_value_from_numeric(a.numeric_value().subtract(b.numeric_value()))
}

fn binary_numeric_multiply_numeric(conn &Connection, a Value, b Value) !Value {
	return new_numeric_value_from_numeric(a.numeric_value().multiply(b.numeric_value()))
}

fn binary_numeric_divide_numeric(conn &Connection, a Value, b Value) !Value {
	if b.as_f64()! == 0 {
		return sqlstate_22012() // division by zero
	}

	return new_numeric_value_from_numeric(a.numeric_value().divide(b.numeric_value())!)
}

fn binary_smallint_plus_smallint(conn &Connection, a Value, b Value) !Value {
	x := i64(a.int_value() + b.int_value())
	check_integer_range(x, .is_smallint)!

	return new_smallint_value(i16(x))
}

fn binary_smallint_minus_smallint(conn &Connection, a Value, b Value) !Value {
	x := i64(a.int_value() - b.int_value())
	check_integer_range(x, .is_smallint)!

	return new_smallint_value(i16(x))
}

fn binary_smallint_multiply_smallint(conn &Connection, a Value, b Value) !Value {
	x := i64(a.int_value() * b.int_value())
	check_integer_range(x, .is_smallint)!

	return new_smallint_value(i16(x))
}

fn binary_smallint_divide_smallint(conn &Connection, a Value, b Value) !Value {
	if b.int_value() == 0 {
		return sqlstate_22012() // division by zero
	}

	return new_smallint_value(i16(a.int_value() / b.int_value()))
}

fn binary_real_plus_real(conn &Connection, a Value, b Value) !Value {
	return new_real_value(f32(a.f64_value() + b.f64_value()))
}

fn binary_real_minus_real(conn &Connection, a Value, b Value) !Value {
	return new_real_value(f32(a.f64_value() - b.f64_value()))
}

fn binary_real_multiply_real(conn &Connection, a Value, b Value) !Value {
	return new_real_value(f32(a.f64_value() * b.f64_value()))
}

fn binary_real_divide_real(conn &Connection, a Value, b Value) !Value {
	if b.f64_value() == 0 {
		return sqlstate_22012() // division by zero
	}

	return new_real_value(f32(a.f64_value() / b.f64_value()))
}

fn binary_decimal_plus_decimal(conn &Connection, a Value, b Value) !Value {
	return new_decimal_value_from_numeric(a.numeric_value().add(b.numeric_value()))
}

fn binary_decimal_minus_decimal(conn &Connection, a Value, b Value) !Value {
	return new_decimal_value_from_numeric(a.numeric_value().subtract(b.numeric_value()))
}

fn binary_decimal_multiply_decimal(conn &Connection, a Value, b Value) !Value {
	return new_decimal_value_from_numeric(a.numeric_value().multiply(b.numeric_value()))
}

fn binary_decimal_divide_decimal(conn &Connection, a Value, b Value) !Value {
	if b.as_f64()! == 0 {
		return sqlstate_22012() // division by zero
	}

	return new_decimal_value_from_numeric(a.numeric_value().divide(b.numeric_value())!)
}
