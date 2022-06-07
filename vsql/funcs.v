// funcs.v registers all the inbuilt SQL functions.

module vsql

struct Func {
	name        string
	arg_types   []Type
	func        fn ([]Value) ?Value
	return_type Type
}

fn register_builtin_funcs(mut conn Connection) ? {
	double_precision := Type{SQLType.is_double_precision, 0}
	integer := Type{SQLType.is_integer, 0}
	varchar := Type{SQLType.is_varchar, 0}

	conn.register_func(Func{'ABS', [double_precision], func_abs, double_precision})?
	conn.register_func(Func{'ACOS', [double_precision], func_acos, double_precision})?
	conn.register_func(Func{'ASIN', [double_precision], func_asin, double_precision})?
	conn.register_func(Func{'ATAN', [double_precision], func_atan, double_precision})?
	conn.register_func(Func{'CEIL', [double_precision], func_ceil, double_precision})?
	conn.register_func(Func{'CEILING', [double_precision], func_ceil, double_precision})?
	conn.register_func(Func{'CHARACTER_LENGTH', [varchar], func_char_length, integer})?
	conn.register_func(Func{'CHAR_LENGTH', [varchar], func_char_length, integer})?
	conn.register_func(Func{'COS', [double_precision], func_cos, double_precision})?
	conn.register_func(Func{'COSH', [double_precision], func_cosh, double_precision})?
	conn.register_func(Func{'EXP', [double_precision], func_exp, double_precision})?
	conn.register_func(Func{'FLOOR', [double_precision], func_floor, double_precision})?
	conn.register_func(Func{'LN', [double_precision], func_ln, double_precision})?
	conn.register_func(Func{'LOG10', [double_precision], func_log10, double_precision})?
	conn.register_func(Func{'LOWER', [varchar], func_lower, varchar})?
	conn.register_func(Func{'MOD', [double_precision, double_precision], func_mod, double_precision})?
	conn.register_func(Func{'OCTET_LENGTH', [varchar], func_octet_length, integer})?
	conn.register_func(Func{'POSITION', [varchar, varchar], func_position, integer})?
	conn.register_func(Func{'POWER', [double_precision, double_precision], func_power, double_precision})?
	conn.register_func(Func{'SIN', [double_precision], func_sin, double_precision})?
	conn.register_func(Func{'SINH', [double_precision], func_sinh, double_precision})?
	conn.register_func(Func{'SQRT', [double_precision], func_sqrt, double_precision})?
	conn.register_func(Func{'TAN', [double_precision], func_tan, double_precision})?
	conn.register_func(Func{'TANH', [double_precision], func_tanh, double_precision})?
	conn.register_func(Func{'UPPER', [varchar], func_upper, varchar})?
}
