module vsql

import math

// ISO/IEC 9075-2:2016(E), 6.30, <numeric value function>
//
// Specify a function yielding a value of type numeric.

// POSITION(CHARACTER VARYING IN CHARACTER VARYING) INTEGER
fn func_position(args []Value) !Value {
	index := args[1].string_value().index(args[0].string_value()) or { -1 }

	return new_integer_value(index + 1)
}

// CHAR_LENGTH(CHARACTER VARYING) INTEGER
fn func_char_length(args []Value) !Value {
	return new_integer_value(args[0].string_value().runes().len)
}

// OCTET_LENGTH(CHARACTER VARYING) INTEGER
fn func_octet_length(args []Value) !Value {
	return new_integer_value(args[0].string_value().len)
}

// UPPER(CHARACTER VARYING) CHARACTER VARYING
fn func_upper(args []Value) !Value {
	return new_varchar_value(args[0].string_value().to_upper())
}

// LOWER(CHARACTER VARYING) CHARACTER VARYING
fn func_lower(args []Value) !Value {
	return new_varchar_value(args[0].string_value().to_lower())
}

// ABS(DOUBLE PRECISION) DOUBLE PRECISION
fn func_abs(args []Value) !Value {
	return new_double_precision_value(math.abs(args[0].f64_value()))
}

// ABS(NUMERIC) NUMERIC
fn func_abs_numeric(args []Value) !Value {
	n := args[0].numeric_value()
	if n.is_negative() {
		return new_numeric_value_from_numeric(n.neg())
	}

	return args[0]
}

// SIN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_sin(args []Value) !Value {
	return new_double_precision_value(math.sin(args[0].f64_value()))
}

// COS(DOUBLE PRECISION) DOUBLE PRECISION
fn func_cos(args []Value) !Value {
	return new_double_precision_value(math.cos(args[0].f64_value()))
}

// TAN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_tan(args []Value) !Value {
	return new_double_precision_value(math.tan(args[0].f64_value()))
}

// SINH(DOUBLE PRECISION) DOUBLE PRECISION
fn func_sinh(args []Value) !Value {
	return new_double_precision_value(math.sinh(args[0].f64_value()))
}

// COSH(DOUBLE PRECISION) DOUBLE PRECISION
fn func_cosh(args []Value) !Value {
	return new_double_precision_value(math.cosh(args[0].f64_value()))
}

// TANH(DOUBLE PRECISION) DOUBLE PRECISION
fn func_tanh(args []Value) !Value {
	return new_double_precision_value(math.tanh(args[0].f64_value()))
}

// ASIN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_asin(args []Value) !Value {
	return new_double_precision_value(math.asin(args[0].f64_value()))
}

// ACOS(DOUBLE PRECISION) DOUBLE PRECISION
fn func_acos(args []Value) !Value {
	return new_double_precision_value(math.acos(args[0].f64_value()))
}

// ATAN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_atan(args []Value) !Value {
	return new_double_precision_value(math.atan(args[0].f64_value()))
}

// MOD(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION
fn func_mod(args []Value) !Value {
	return new_double_precision_value(math.fmod(args[0].f64_value(), args[1].f64_value()))
}

// MOD(NUMERIC, NUMERIC) NUMERIC
fn func_mod_numeric(args []Value) !Value {
	value := args[0].numeric_value()
	modulus := args[1].numeric_value()

	return new_numeric_value_from_numeric(value.subtract(value.divide(modulus)!.trunc().multiply(modulus)))
}

// LOG(DOUBLE PRECISION) DOUBLE PRECISION
fn func_log(args []Value) !Value {
	return new_double_precision_value(math.log2(args[0].f64_value()))
}

// LOG10(DOUBLE PRECISION) DOUBLE PRECISION
fn func_log10(args []Value) !Value {
	return new_double_precision_value(math.log10(args[0].f64_value()))
}

// LN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_ln(args []Value) !Value {
	return new_double_precision_value(math.log(args[0].f64_value()))
}

// EXP(DOUBLE PRECISION) DOUBLE PRECISION
fn func_exp(args []Value) !Value {
	return new_double_precision_value(math.exp(args[0].f64_value()))
}

// SQRT(DOUBLE PRECISION) DOUBLE PRECISION
fn func_sqrt(args []Value) !Value {
	return new_double_precision_value(math.sqrt(args[0].f64_value()))
}

// POWER(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION
fn func_power(args []Value) !Value {
	return new_double_precision_value(math.pow(args[0].f64_value(), args[1].f64_value()))
}

// FLOOR(DOUBLE PRECISION) DOUBLE PRECISION
fn func_floor(args []Value) !Value {
	return new_double_precision_value(math.floor(args[0].f64_value()))
}

// FLOOR(NUMERIC) NUMERIC
fn func_floor_numeric(args []Value) !Value {
	n := args[0].numeric_value()
	if n.is_negative() {
		return new_numeric_value_from_numeric(n.subtract(new_numeric_from_string('1')).trunc())
	}

	return new_numeric_value_from_numeric(n.trunc())
}

// CEIL(DOUBLE PRECISION) DOUBLE PRECISION
fn func_ceil(args []Value) !Value {
	return new_double_precision_value(math.ceil(args[0].f64_value()))
}

// CEIL(NUMERIC) NUMERIC
fn func_ceil_numeric(args []Value) !Value {
	n := args[0].numeric_value()
	t := n.trunc()
	if n.equals(t) {
		return args[0]
	}

	if n.is_negative() {
		return new_numeric_value_from_numeric(t)
	}

	return new_numeric_value_from_numeric(t.add(new_numeric_from_string('1')))
}
