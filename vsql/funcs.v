// funcs.v registers all the inbuilt SQL functions.

module vsql

struct Func {
	name        string
	arg_types   []Type
	is_agg      bool
	func        fn ([]Value) ?Value
	return_type Type
}

fn register_builtin_funcs(mut conn Connection) ? {
	double_precision := Type{SQLType.is_double_precision, 0, 0, false}
	integer := Type{SQLType.is_integer, 0, 0, false}
	varchar := Type{SQLType.is_varchar, 0, 0, false}

	// Scalar functions.
	conn.register_func(Func{'ABS', [double_precision], false, func_abs, double_precision})?
	conn.register_func(Func{'ACOS', [double_precision], false, func_acos, double_precision})?
	conn.register_func(Func{'ASIN', [double_precision], false, func_asin, double_precision})?
	conn.register_func(Func{'ATAN', [double_precision], false, func_atan, double_precision})?
	conn.register_func(Func{'CEIL', [double_precision], false, func_ceil, double_precision})?
	conn.register_func(Func{'CEILING', [double_precision], false, func_ceil, double_precision})?
	conn.register_func(Func{'CHARACTER_LENGTH', [varchar], false, func_char_length, integer})?
	conn.register_func(Func{'CHAR_LENGTH', [varchar], false, func_char_length, integer})?
	conn.register_func(Func{'COS', [double_precision], false, func_cos, double_precision})?
	conn.register_func(Func{'COSH', [double_precision], false, func_cosh, double_precision})?
	conn.register_func(Func{'EXP', [double_precision], false, func_exp, double_precision})?
	conn.register_func(Func{'FLOOR', [double_precision], false, func_floor, double_precision})?
	conn.register_func(Func{'LN', [double_precision], false, func_ln, double_precision})?
	conn.register_func(Func{'LOG10', [double_precision], false, func_log10, double_precision})?
	conn.register_func(Func{'LOWER', [varchar], false, func_lower, varchar})?
	conn.register_func(Func{'MOD', [double_precision, double_precision], false, func_mod, double_precision})?
	conn.register_func(Func{'OCTET_LENGTH', [varchar], false, func_octet_length, integer})?
	conn.register_func(Func{'POSITION', [varchar, varchar], false, func_position, integer})?
	conn.register_func(Func{'POWER', [double_precision, double_precision], false, func_power, double_precision})?
	conn.register_func(Func{'SIN', [double_precision], false, func_sin, double_precision})?
	conn.register_func(Func{'SINH', [double_precision], false, func_sinh, double_precision})?
	conn.register_func(Func{'SQRT', [double_precision], false, func_sqrt, double_precision})?
	conn.register_func(Func{'TAN', [double_precision], false, func_tan, double_precision})?
	conn.register_func(Func{'TANH', [double_precision], false, func_tanh, double_precision})?
	conn.register_func(Func{'UPPER', [varchar], false, func_upper, varchar})?

	// Aggregate functions.
	conn.register_func(Func{'AVG', [double_precision], true, func_avg, double_precision})?
	conn.register_func(Func{'COUNT', [double_precision], true, func_count, integer})?
	conn.register_func(Func{'MAX', [double_precision], true, func_max, double_precision})?
	conn.register_func(Func{'MIN', [double_precision], true, func_min, double_precision})?
	conn.register_func(Func{'SUM', [double_precision], true, func_sum, double_precision})?
}
