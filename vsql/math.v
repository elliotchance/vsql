// math.v contains all the mathematical/numeric built in SQL functions.

module vsql

import math

// ABS(DOUBLE PRECISION) DOUBLE PRECISION
fn func_abs(args []Value) ?Value {
	return new_double_precision_value(math.abs(args[0].f64_value))
}

// SIN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_sin(args []Value) ?Value {
	return new_double_precision_value(math.sin(args[0].f64_value))
}

// COS(DOUBLE PRECISION) DOUBLE PRECISION
fn func_cos(args []Value) ?Value {
	return new_double_precision_value(math.cos(args[0].f64_value))
}

// TAN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_tan(args []Value) ?Value {
	return new_double_precision_value(math.tan(args[0].f64_value))
}

// SINH(DOUBLE PRECISION) DOUBLE PRECISION
fn func_sinh(args []Value) ?Value {
	return new_double_precision_value(math.sinh(args[0].f64_value))
}

// COSH(DOUBLE PRECISION) DOUBLE PRECISION
fn func_cosh(args []Value) ?Value {
	return new_double_precision_value(math.cosh(args[0].f64_value))
}

// TANH(DOUBLE PRECISION) DOUBLE PRECISION
fn func_tanh(args []Value) ?Value {
	return new_double_precision_value(math.tanh(args[0].f64_value))
}

// ASIN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_asin(args []Value) ?Value {
	return new_double_precision_value(math.asin(args[0].f64_value))
}

// ACOS(DOUBLE PRECISION) DOUBLE PRECISION
fn func_acos(args []Value) ?Value {
	return new_double_precision_value(math.acos(args[0].f64_value))
}

// ATAN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_atan(args []Value) ?Value {
	return new_double_precision_value(math.atan(args[0].f64_value))
}

// MOD(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION
fn func_mod(args []Value) ?Value {
	return new_double_precision_value(math.fmod(args[0].f64_value, args[1].f64_value))
}

// LOG(DOUBLE PRECISION) DOUBLE PRECISION
fn func_log(args []Value) ?Value {
	return new_double_precision_value(math.log2(args[0].f64_value))
}

// LOG10(DOUBLE PRECISION) DOUBLE PRECISION
fn func_log10(args []Value) ?Value {
	return new_double_precision_value(math.log10(args[0].f64_value))
}

// LN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_ln(args []Value) ?Value {
	return new_double_precision_value(math.log(args[0].f64_value))
}

// EXP(DOUBLE PRECISION) DOUBLE PRECISION
fn func_exp(args []Value) ?Value {
	return new_double_precision_value(math.exp(args[0].f64_value))
}

// SQRT(DOUBLE PRECISION) DOUBLE PRECISION
fn func_sqrt(args []Value) ?Value {
	return new_double_precision_value(math.sqrt(args[0].f64_value))
}

// POWER(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION
fn func_power(args []Value) ?Value {
	return new_double_precision_value(math.pow(args[0].f64_value, args[1].f64_value))
}

// FLOOR(DOUBLE PRECISION) DOUBLE PRECISION
fn func_floor(args []Value) ?Value {
	return new_double_precision_value(math.floor(args[0].f64_value))
}

// CEIL(DOUBLE PRECISION) DOUBLE PRECISION
fn func_ceil(args []Value) ?Value {
	return new_double_precision_value(math.ceil(args[0].f64_value))
}
