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
	conn.unary_operators['- BIGINT'] = unary_negate_bigint
	conn.unary_operators['- DOUBLE PRECISION'] = unary_negate_double_precision

	conn.unary_operators['+ BIGINT'] = unary_passthru
	conn.unary_operators['+ DOUBLE PRECISION'] = unary_passthru

	conn.unary_operators['NOT BOOLEAN'] = unary_not_boolean
}

fn register_binary_operators(mut conn Connection) {
	// Since many types share the same underlying memory, we can create a matrix
	// of compatible operators that use the same function.
	int_types := ['SMALLINT', 'INTEGER', 'BIGINT']
	float_types := ['REAL', 'DOUBLE PRECISION']
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
	return new_integer_value(int(a.int_value() + b.int_value()))
}

fn binary_bigint_plus_bigint(conn &Connection, a Value, b Value) !Value {
	return new_bigint_value(a.int_value() + b.int_value())
}

fn binary_double_precision_minus_double_precision(conn &Connection, a Value, b Value) !Value {
	return new_double_precision_value(a.f64_value() - b.f64_value())
}

fn binary_integer_minus_integer(conn &Connection, a Value, b Value) !Value {
	return new_integer_value(int(a.int_value() - b.int_value()))
}

fn binary_bigint_minus_bigint(conn &Connection, a Value, b Value) !Value {
	return new_bigint_value(a.int_value() - b.int_value())
}

fn binary_double_precision_multiply_double_precision(conn &Connection, a Value, b Value) !Value {
	return new_double_precision_value(a.f64_value() * b.f64_value())
}

fn binary_integer_multiply_integer(conn &Connection, a Value, b Value) !Value {
	return new_integer_value(int(a.int_value() * b.int_value()))
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

	return new_integer_value(int(a.int_value() / b.int_value()))
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
	return new_boolean_value(a.f64_value() == b.f64_value())
}

fn binary_int_equal_int(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.int_value() == b.int_value())
}

fn binary_string_equal_string(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.string_value() == b.string_value())
}

fn binary_float_not_equal_float(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.f64_value() != b.f64_value())
}

fn binary_int_not_equal_int(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.int_value() != b.int_value())
}

fn binary_string_not_equal_string(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.string_value() != b.string_value())
}

fn binary_float_less_float(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.f64_value() < b.f64_value())
}

fn binary_int_less_int(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.int_value() < b.int_value())
}

fn binary_string_less_string(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.string_value() < b.string_value())
}

fn binary_float_greater_float(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.f64_value() > b.f64_value())
}

fn binary_int_greater_int(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.int_value() > b.int_value())
}

fn binary_string_greater_string(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.string_value() > b.string_value())
}

fn binary_float_less_equal_float(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.f64_value() <= b.f64_value())
}

fn binary_int_less_equal_int(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.int_value() <= b.int_value())
}

fn binary_string_less_equal_string(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.string_value() <= b.string_value())
}

fn binary_float_greater_equal_float(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.f64_value() >= b.f64_value())
}

fn binary_int_greater_equal_int(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.int_value() >= b.int_value())
}

fn binary_string_greater_equal_string(conn &Connection, a Value, b Value) !Value {
	return new_boolean_value(a.string_value() >= b.string_value())
}
