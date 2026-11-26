// funcs.v registers all the inbuilt SQL functions. They aren't SQL-invoked
// routines (there's no CREATE FUNCTION), but they have some of their
// characteristics (ISO/IEC 9075-2:2023, 4.35, SQL-invoked routines).

module vsql

import time

struct Func {
	name        string
	arg_types   []Type
	is_agg      bool
	func        fn (FunctionContext, []Value) !Value // not used by aggregates, see eval_set_function
	return_type Type
	// called_on_null_input means the function is still called when one of the
	// arguments is NULL. Otherwise, the result will be NULL without calling the
	// function, this is the case for all builtin functions. Custom functions are
	// always called because SQL defaults to CALLED ON NULL INPUT.
	//
	// ISO/IEC 9075-2:2023, 11.60, <SQL-invoked routine>
	called_on_null_input bool
	// is_deterministic is true when the function always returns the same result
	// for the same arguments, so it can be used in a CHECK constraint. That's
	// all builtin functions. Custom functions can't be declared DETERMINISTIC,
	// so they're NOT DETERMINISTIC (the SQL default, see ISO/IEC 9075-2:2023,
	// 4.24, Determinism).
	//
	// ISO/IEC 9075-2:2023, 11.60, <SQL-invoked routine>
	is_deterministic bool
	// features are flagged when the function is called (see
	// register_flagged_function). It's only used by the SQL Flagger.
	features []string
	// arg_names are the names of the parameters, in the same order as
	// arg_types, which are shown by the PARAMETERS view. They're empty when the
	// parameters don't have names, and the name of a built-in function's
	// parameter is in builtin_arg_names.
	arg_names []string
	// is_variadic means the function takes any number of arguments after the
	// arg_types, such as CONCAT. They're a parameter named VARIADIC that's an
	// ARRAY (see PARAMETERS). Only a built-in function can be variadic, and it
	// has its own compile (see RoutineInvocation.compile).
	is_variadic bool
}

// variadic_parameter_name is the name of the parameter that has the arguments
// of a variadic function (see Func.is_variadic).
const variadic_parameter_name = 'VARIADIC'

// builtin_arg_names are the names of the parameters of the built-in functions
// that are routines of the VSQL schema, by function name. An overload with
// fewer parameters has the first names, such as ROUND(X) and ROUND(X, PLACES).
// They aren't reserved words, so they never need to be quoted, and they match
// the documentation of each function.
const builtin_arg_names = {
	'ATAN2':            ['Y', 'X']
	'BASE64_TO_BINARY': ['STRING']
	'BINARY_TO_BASE64': ['OCTETS']
	'BINARY_TO_HEX':    ['OCTETS']
	'BINARY_TO_UUID':   ['OCTETS']
	'CBRT':             ['X']
	'CHR':              ['CODE_POINT']
	'DATE_TRUNC':       ['FIELD', 'SOURCE']
	'DEGREES':          ['X']
	'ENDS_WITH':        ['STRING', 'SUFFIX']
	'ERF':              ['X']
	'ERFC':             ['X']
	'FACTORIAL':        ['N']
	'FORMAT_SIZE':      ['BYTES', 'SIGNIFICANT_FIGURES', 'UNIT', 'BASE']
	'GAMMA':            ['X']
	'GCD':              ['A', 'B']
	'HEX_TO_BINARY':    ['STRING']
	'INITCAP':          ['STRING']
	'LCM':              ['A', 'B']
	'LENGTH':           ['STRING']
	'LGAMMA':           ['X']
	'MAKE_DATE':        ['YEARS', 'MONTHS', 'DAYS']
	'MAKE_INTERVAL':    make_interval_names
	'MAKE_TIME':        ['HOURS', 'MINUTES', 'SECONDS']
	'MAKE_TIMESTAMP':   ['YEARS', 'MONTHS', 'DAYS', 'HOURS', 'MINUTES', 'SECONDS']
	'MAKE_TIMESTAMPTZ': ['YEARS', 'MONTHS', 'DAYS', 'HOURS', 'MINUTES', 'SECONDS', 'TIME_ZONE']
	'MIN_SCALE':        ['X']
	'PARSE_SIZE':       ['SIZE', 'BASE']
	'QUOTE_IDENT':      ['NAME']
	'RADIANS':          ['X']
	'RANDOM':           ['MIN', 'MAX']
	'RANDOM_BINARY':    ['N']
	'RANDOM_NORMAL':    ['MEAN', 'STDDEV']
	'REPEAT':           ['STRING', 'N']
	'REPLACE':          ['STRING', 'TARGET', 'REPLACEMENT']
	'REVERSE':          ['STRING']
	'ROUND':            ['X', 'PLACES']
	'SIGN':             ['X']
	'SPLIT_PART':       ['STRING', 'DELIMITER', 'N']
	'STARTS_WITH':      ['STRING', 'PREFIX']
	'TRIM_SCALE':       ['X']
	'TRUNC':            ['X', 'PLACES']
	'UNICODE':          ['STRING']
	'UUID_TO_BINARY':   ['STRING']
}

// A FunctionContext is passed to every function (including one registered
// with register_function) when it's called. It gives the function what it can
// know besides its arguments: the statement that's executing, the session and
// transaction it's in, and the database itself.
pub struct FunctionContext {
	conn &Connection
}

// current_timestamp is the same value as CURRENT_TIMESTAMP: the time that the
// statement started, as a TIMESTAMP(6) WITH TIME ZONE in the session's time
// zone. Every call in the same statement returns the same time.
pub fn (ctx FunctionContext) current_timestamp() !Value {
	return new_timestamp_value(local_now(ctx.conn).strftime('%Y-%m-%d ') +
		time_value(ctx.conn, 6, true))
}

// clock_timestamp is the time now, read from the wall clock each time it's
// called, as a TIMESTAMP(6) WITH TIME ZONE in the session's time zone. Unlike
// current_timestamp, two calls in the same statement can return different
// times. NOW() returns this.
pub fn (ctx FunctionContext) clock_timestamp() !Value {
	now, time_zone := ctx.conn.session_now()
	return new_timestamp_value(timestamp_with_time_zone_str(now, time_zone, 6))
}

// statement_timestamp is the time that the statement started (in UTC), and the
// time zone of the session (in minutes from UTC).
pub fn (ctx FunctionContext) statement_timestamp() (time.Time, i16) {
	return ctx.conn.statement_timestamp, ctx.conn.statement_time_zone
}

// current_catalog is the same as CURRENT_CATALOG.
pub fn (ctx FunctionContext) current_catalog() string {
	return ctx.conn.current_catalog
}

// current_schema is the same as CURRENT_SCHEMA.
pub fn (ctx FunctionContext) current_schema() string {
	return ctx.conn.current_schema
}

// version is the version of vsql, the same as build_version().
pub fn (ctx FunctionContext) version() string {
	return build_version()
}

// in_transaction is true if the statement is in a transaction that was started
// with START TRANSACTION, rather than being its own transaction.
pub fn (ctx FunctionContext) in_transaction() bool {
	return ctx.conn.in_transaction()
}

fn register_builtin_funcs(mut conn Connection) ! {
	double_precision := Type{SQLType.is_double_precision, 0, 0, false, false}
	integer := Type{SQLType.is_integer, 0, 0, false, false}
	varchar := Type{SQLType.is_varchar, 0, 0, false, false}
	numeric := Type{SQLType.is_numeric, 0, 0, false, false}
	smallint := Type{SQLType.is_smallint, 0, 0, false, false}
	bigint := Type{SQLType.is_bigint, 0, 0, false, false}
	real := Type{SQLType.is_real, 0, 0, false, false}
	decimal := Type{SQLType.is_decimal, 0, 0, false, false}
	varbinary := Type{SQLType.is_varbinary, 0, 0, false, false}
	blob := Type{SQLType.is_blob, 0, 0, false, false}
	clob := Type{SQLType.is_clob, 0, 0, false, false}

	// Scalar functions. The trigonometric functions, LOG, LN, EXP, POWER and SQRT
	// return a DOUBLE PRECISION (the approximate numeric type is
	// implementation-defined), and so do FLOOR and CEIL of an approximate number.
	// None of them are called with a NULL argument, the result is NULL.
	//
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 13.b, 14.b and 16-18
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 20.b
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 1.b
	conn.register_func(Func{'ABS', [double_precision], false, func_abs, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'ABS', [numeric], false, func_abs_numeric, numeric, false, true, [], [], false})!
	conn.register_func(Func{'ABS', [decimal], false, func_abs_decimal, decimal, false, true, [], [], false})!
	conn.register_func(Func{'ABS', [smallint], false, func_abs_integer, smallint, false, true, [], [], false})!
	conn.register_func(Func{'ABS', [integer], false, func_abs_integer, integer, false, true, [], [], false})!
	conn.register_func(Func{'ABS', [bigint], false, func_abs_integer, bigint, false, true, [], [], false})!
	conn.register_func(Func{'ABS', [real], false, func_abs_real, real, false, true, [], [], false})!
	conn.register_func(Func{'ACOS', [double_precision], false, func_acos, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'ASIN', [double_precision], false, func_asin, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'ATAN', [double_precision], false, func_atan, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'CEIL', [double_precision], false, func_ceil, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'CEIL', [numeric], false, func_ceil_numeric, numeric, false, true, [], [], false})!
	conn.register_func(Func{'CEIL', [smallint], false, func_floor_integer, smallint, false, true, [], [], false})!
	conn.register_func(Func{'CEIL', [integer], false, func_floor_integer, integer, false, true, [], [], false})!
	conn.register_func(Func{'CEIL', [bigint], false, func_floor_integer, bigint, false, true, [], [], false})!
	conn.register_func(Func{'CEILING', [double_precision], false, func_ceil, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'CEILING', [numeric], false, func_ceil_numeric, numeric, false, true, [], [], false})!
	conn.register_func(Func{'CEILING', [smallint], false, func_floor_integer, smallint, false, true, [], [], false})!
	conn.register_func(Func{'CEILING', [integer], false, func_floor_integer, integer, false, true, [], [], false})!
	conn.register_func(Func{'CEILING', [bigint], false, func_floor_integer, bigint, false, true, [], [], false})!
	conn.register_func(Func{'CHARACTER_LENGTH', [varchar], false, func_char_length, integer, false, true, [], [], false})!
	conn.register_func(Func{'CHAR_LENGTH', [varchar], false, func_char_length, integer, false, true, [], [], false})!
	// POSITION, CHAR_LENGTH, OCTET_LENGTH, LOWER and UPPER of a CHARACTER LARGE
	// OBJECT are Feature T050, and OCTET_LENGTH is also T047. The length of a
	// large value is known without reading it.
	//
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Conformance Rules, 7 and 8
	// ISO/IEC 9075-2:2023, 6.33, <string value function>, Conformance Rules, 17
	conn.register_func(Func{'CHARACTER_LENGTH', [clob], false, func_char_length, integer, false, true, ['T050'], [], false})!
	conn.register_func(Func{'CHAR_LENGTH', [clob], false, func_char_length, integer, false, true, ['T050'], [], false})!
	clob_octet_length := ['T047', 'T050']
	conn.register_func(Func{'OCTET_LENGTH', [clob], false, func_octet_length, integer, false, true, clob_octet_length, [], false})!
	conn.register_func(Func{'POSITION', [varchar, clob], false, func_position, integer, false, true, ['T050'], [], false})!
	conn.register_func(Func{'POSITION', [clob, varchar], false, func_position, integer, false, true, ['T050'], [], false})!
	conn.register_func(Func{'POSITION', [clob, clob], false, func_position, integer, false, true, ['T050'], [], false})!
	conn.register_func(Func{'LOWER', [clob], false, func_lower, clob, false, true, ['T050'], [], false})!
	conn.register_func(Func{'UPPER', [clob], false, func_upper, clob, false, true, ['T050'], [], false})!
	conn.register_func(Func{'COS', [double_precision], false, func_cos, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'COSH', [double_precision], false, func_cosh, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'EXP', [double_precision], false, func_exp, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'FLOOR', [double_precision], false, func_floor, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'FLOOR', [numeric], false, func_floor_numeric, numeric, false, true, [], [], false})!
	conn.register_func(Func{'FLOOR', [smallint], false, func_floor_integer, smallint, false, true, [], [], false})!
	conn.register_func(Func{'FLOOR', [integer], false, func_floor_integer, integer, false, true, [], [], false})!
	conn.register_func(Func{'FLOOR', [bigint], false, func_floor_integer, bigint, false, true, [], [], false})!
	conn.register_func(Func{'LN', [double_precision], false, func_ln, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'LOG', [double_precision, double_precision], false, func_log, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'LOG10', [double_precision], false, func_log10, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'LOWER', [varchar], false, func_lower, varchar, false, true, [], [], false})!
	conn.register_func(Func{'MOD', [double_precision, double_precision], false, func_mod, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'MOD', [numeric, numeric], false, func_mod_numeric, numeric, false, true, [], [], false})!
	// The result of MOD has the type of the divisor, so there is one for each
	// combination of integer types.
	//
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 12.b
	for dividend in [smallint, integer, bigint] {
		for divisor in [smallint, integer, bigint] {
			conn.register_func(Func{'MOD', [dividend, divisor], false, func_mod_integer, divisor, false, true, [], [], false})!
		}
	}
	conn.register_func(Func{'OCTET_LENGTH', [varchar], false, func_octet_length, integer, false, true, [], [], false})!
	// A binary string (and a BINARY is a BINARY VARYING, see find_function) has
	// a length in octets, and a <binary position expression> finds one binary
	// string in another. A BINARY LARGE OBJECT needs Feature T047 for both, and
	// otherwise the <binary position expression> is T021 (either one is
	// enough).
	//
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Conformance Rules, 6 and 8
	conn.register_func(Func{'OCTET_LENGTH', [varbinary], false, func_octet_length, integer, false, true, [], [], false})!
	conn.register_func(Func{'OCTET_LENGTH', [blob], false, func_octet_length, integer, false, true, ['T047'], [], false})!
	conn.register_func(Func{'POSITION', [varchar, varchar], false, func_position, integer, false, true, [], [], false})!
	conn.register_func(Func{'POSITION', [varbinary, varbinary], false, func_binary_position, integer, false, true, ['T021'], [], false})!
	conn.register_func(Func{'POSITION', [varbinary, blob], false, func_binary_position, integer, false, true, ['T047'], [], false})!
	conn.register_func(Func{'POSITION', [blob, varbinary], false, func_binary_position, integer, false, true, ['T047'], [], false})!
	conn.register_func(Func{'POSITION', [blob, blob], false, func_binary_position, integer, false, true, ['T047'], [], false})!
	conn.register_func(Func{'POWER', [double_precision, double_precision], false, func_power, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'SIN', [double_precision], false, func_sin, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'SINH', [double_precision], false, func_sinh, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'SQRT', [double_precision], false, func_sqrt, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'TAN', [double_precision], false, func_tan, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'TANH', [double_precision], false, func_tanh, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'UPPER', [varchar], false, func_upper, varchar, false, true, [], [], false})!
	// The operand and bounds of WIDTH_BUCKET are exact (NUMERIC) or approximate
	// (DOUBLE PRECISION). The result has the type of the count, which must be an
	// exact numeric (see numeric_function_type), so there's one for each.
	//
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 21
	for operand in [numeric, double_precision] {
		for count in [smallint, integer, bigint, numeric] {
			conn.register_func(Func{'WIDTH_BUCKET', [operand, operand, operand, count], false, func_width_bucket, count, false, true, [], [], false})!
		}
	}

	// NOW() is a vsql extension (V402-01) that reads the wall clock each time
	// it's called, so unlike CURRENT_TIMESTAMP (which is fixed for the whole
	// statement) it's NOT DETERMINISTIC. That's why it can't be in a CHECK, and as
	// a function it can't be where only a datetime value function can, such as a
	// DEFAULT.
	conn.register_func(Func{'NOW', [], false, func_now, new_type('TIMESTAMP WITH TIME ZONE',
		6, 0), false, false, [vsql_now], [], false})!

	register_datetime_funcs(mut conn)!
	register_date_trunc_funcs(mut conn)!
	register_make_interval_funcs(mut conn)!
	register_math_funcs(mut conn)!
	register_string_funcs(mut conn)!
	register_decfloat_funcs(mut conn)!
	register_binary_funcs(mut conn)!
	register_uuid_funcs(mut conn)!
	register_size_funcs(mut conn)!

	// Aggregate functions. COUNT accepts a value of any type because it only
	// counts the non-NULL values (GR 7.d.i). MAX and MIN accept any type that can
	// be ordered, which is every type (SR 7.d), SUM and AVG accept any number
	// or interval (SR 7.g.i), STDDEV_POP, STDDEV_SAMP, VAR_POP and VAR_SAMP also accept any
	// number (SR 7.h), and EVERY, ANY and SOME accept a BOOLEAN (SR 7.e). Every
	// SQLType is registered, so a new type is supported automatically. CHARACTER
	// uses the CHARACTER VARYING one, and BINARY uses the BINARY VARYING one, see
	// find_function. The result type depends
	// on the argument (see set_function_type) and the result is calculated by
	// eval_set_function. PRODUCT and MEDIAN are vsql extensions (V405-02 and
	// V405-03) that accept any number, like SUM. BIT_AND, BIT_OR and BIT_XOR are
	// vsql extensions (V405-04 to V405-06) that only accept an integer.
	//
	// ISO/IEC 9075-2:2023, 10.9, <aggregate function>, Syntax Rules, 7.d, 7.e, 7.g.i and 7.h
	// ISO/IEC 9075-2:2023, 10.9, <aggregate function>, General Rules, 7.d.i
	$for typ in SQLType.values {
		if typ.value !in [SQLType.is_character, .is_binary] {
			arg := Type{typ.value, 0, 0, false, false}
			mut names := ['ANY_VALUE', 'COUNT', 'MAX', 'MIN']
			if typ.value.is_number() {
				names << ['AVG', 'SUM', 'STDDEV_POP', 'STDDEV_SAMP', 'VAR_POP', 'VAR_SAMP', 'PRODUCT',
					'MEDIAN']
			}
			if typ.value in [SQLType.is_smallint, .is_integer, .is_bigint] {
				names << ['BIT_AND', 'BIT_OR', 'BIT_XOR']
			}
			if typ.value == SQLType.is_boolean {
				names << ['EVERY', 'ANY', 'SOME']
			}
			if typ.value.is_interval() {
				names << ['AVG', 'SUM']
			}
			for name in names {
				conn.register_func(Func{
					name:        name
					arg_types:   [arg]
					is_agg:      true
					return_type: set_function_type(name, arg)
					features:    named_aggregate_features[name] or { []string{} }
				})!
			}
		}
	}

	// The binary set functions accept any two numbers, which are used as DOUBLE
	// PRECISION, or as DECFLOAT if either one is (see binary_set_function_type
	// and eval_binary_set_function), so they're the only aggregate
	// functions with arguments that are implicitly cast (see find_function).
	//
	// ISO/IEC 9075-2:2023, 10.9, <aggregate function>, Format
	for name in binary_set_functions {
		conn.register_func(Func{
			name:        name
			arg_types:   [double_precision, double_precision]
			is_agg:      true
			return_type: set_function_type(name, double_precision)
		})!
	}
}

fn func_now(ctx FunctionContext, _ []Value) !Value {
	return ctx.clock_timestamp()
}
