// funcs.v registers all the inbuilt SQL functions.

module vsql

struct Func {
	name        string
	arg_types   []Type
	is_agg      bool
	func        fn ([]Value) !Value @[required]
	return_type Type
	// called_on_null_input means the function is still called when one of the
	// arguments is NULL. Otherwise, the result will be NULL without calling the
	// function, this is the case for all builtin functions. Custom functions are
	// always called because SQL defaults to CALLED ON NULL INPUT.
	//
	// ISO/IEC 9075-2:2016(E), 11.60, <SQL-invoked routine>
	called_on_null_input bool
}

fn register_builtin_funcs(mut conn Connection) ! {
	double_precision := Type{SQLType.is_double_precision, 0, 0, false}
	integer := Type{SQLType.is_integer, 0, 0, false}
	varchar := Type{SQLType.is_varchar, 0, 0, false}
	numeric := Type{SQLType.is_numeric, 0, 0, false}
	smallint := Type{SQLType.is_smallint, 0, 0, false}
	bigint := Type{SQLType.is_bigint, 0, 0, false}
	real := Type{SQLType.is_real, 0, 0, false}
	decimal := Type{SQLType.is_decimal, 0, 0, false}

	// Scalar functions.
	conn.register_func(Func{'ABS', [double_precision], false, func_abs, double_precision, false})!
	conn.register_func(Func{'ABS', [numeric], false, func_abs_numeric, numeric, false})!
	conn.register_func(Func{'ABS', [decimal], false, func_abs_decimal, decimal, false})!
	conn.register_func(Func{'ABS', [smallint], false, func_abs_integer, smallint, false})!
	conn.register_func(Func{'ABS', [integer], false, func_abs_integer, integer, false})!
	conn.register_func(Func{'ABS', [bigint], false, func_abs_integer, bigint, false})!
	conn.register_func(Func{'ABS', [real], false, func_abs_real, real, false})!
	conn.register_func(Func{'ACOS', [double_precision], false, func_acos, double_precision, false})!
	conn.register_func(Func{'ASIN', [double_precision], false, func_asin, double_precision, false})!
	conn.register_func(Func{'ATAN', [double_precision], false, func_atan, double_precision, false})!
	conn.register_func(Func{'CEIL', [double_precision], false, func_ceil, double_precision, false})!
	conn.register_func(Func{'CEIL', [numeric], false, func_ceil_numeric, numeric, false})!
	conn.register_func(Func{'CEILING', [double_precision], false, func_ceil, double_precision, false})!
	conn.register_func(Func{'CEILING', [numeric], false, func_ceil_numeric, numeric, false})!
	conn.register_func(Func{'CHARACTER_LENGTH', [varchar], false, func_char_length, integer, false})!
	conn.register_func(Func{'CHAR_LENGTH', [varchar], false, func_char_length, integer, false})!
	conn.register_func(Func{'COS', [double_precision], false, func_cos, double_precision, false})!
	conn.register_func(Func{'COSH', [double_precision], false, func_cosh, double_precision, false})!
	conn.register_func(Func{'EXP', [double_precision], false, func_exp, double_precision, false})!
	conn.register_func(Func{'FLOOR', [double_precision], false, func_floor, double_precision, false})!
	conn.register_func(Func{'FLOOR', [numeric], false, func_floor_numeric, numeric, false})!
	conn.register_func(Func{'LN', [double_precision], false, func_ln, double_precision, false})!
	conn.register_func(Func{'LOG10', [double_precision], false, func_log10, double_precision, false})!
	conn.register_func(Func{'LOWER', [varchar], false, func_lower, varchar, false})!
	conn.register_func(Func{'MOD', [double_precision, double_precision], false, func_mod, double_precision, false})!
	conn.register_func(Func{'MOD', [numeric, numeric], false, func_mod_numeric, numeric, false})!
	conn.register_func(Func{'OCTET_LENGTH', [varchar], false, func_octet_length, integer, false})!
	conn.register_func(Func{'POSITION', [varchar, varchar], false, func_position, integer, false})!
	conn.register_func(Func{'POWER', [double_precision, double_precision], false, func_power, double_precision, false})!
	conn.register_func(Func{'SIN', [double_precision], false, func_sin, double_precision, false})!
	conn.register_func(Func{'SINH', [double_precision], false, func_sinh, double_precision, false})!
	conn.register_func(Func{'SQRT', [double_precision], false, func_sqrt, double_precision, false})!
	conn.register_func(Func{'TAN', [double_precision], false, func_tan, double_precision, false})!
	conn.register_func(Func{'TANH', [double_precision], false, func_tanh, double_precision, false})!
	conn.register_func(Func{'UPPER', [varchar], false, func_upper, varchar, false})!

	// Aggregate functions.
	conn.register_func(Func{'AVG', [double_precision], true, func_avg, double_precision, false})!
	// COUNT accepts a value of any type because it only counts the non-NULL
	// values (10.9 General Rule 7). Every SQLType is registered, so a new type
	// is supported automatically.
	$for typ in SQLType.values {
		conn.register_func(Func{'COUNT', [Type{typ.value, 0, 0, false}], true, func_count, integer, false})!
	}
	conn.register_func(Func{'MAX', [double_precision], true, func_max, double_precision, false})!
	conn.register_func(Func{'MIN', [double_precision], true, func_min, double_precision, false})!
	conn.register_func(Func{'SUM', [double_precision], true, func_sum, double_precision, false})!
}
