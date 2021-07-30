// funcs.v registers all the inbuilt SQL functions.

module vsql

struct Func {
	name      string
	arg_types []Type
	func      fn ([]Value) ?Value
}

fn register_builtin_funcs(mut conn Connection) ? {
	conn.register_func(Func{'ABS', [Type{SQLType.is_double_precision, 0}], func_abs}) ?
	conn.register_func(Func{'ACOS', [Type{SQLType.is_double_precision, 0}], func_acos}) ?
	conn.register_func(Func{'ASIN', [Type{SQLType.is_double_precision, 0}], func_asin}) ?
	conn.register_func(Func{'ATAN', [Type{SQLType.is_double_precision, 0}], func_atan}) ?
	conn.register_func(Func{'CEIL', [Type{SQLType.is_double_precision, 0}], func_ceil}) ?
	conn.register_func(Func{'CEILING', [Type{SQLType.is_double_precision, 0}], func_ceil}) ?
	conn.register_func(Func{'COS', [Type{SQLType.is_double_precision, 0}], func_cos}) ?
	conn.register_func(Func{'COSH', [Type{SQLType.is_double_precision, 0}], func_cosh}) ?
	conn.register_func(Func{'EXP', [Type{SQLType.is_double_precision, 0}], func_exp}) ?
	conn.register_func(Func{'FLOOR', [Type{SQLType.is_double_precision, 0}], func_floor}) ?
	conn.register_func(Func{'LN', [Type{SQLType.is_double_precision, 0}], func_ln}) ?
	conn.register_func(Func{'LOG', [Type{SQLType.is_double_precision, 0}], func_log}) ?
	conn.register_func(Func{'LOG10', [Type{SQLType.is_double_precision, 0}], func_log10}) ?
	conn.register_func(Func{'MOD', [Type{SQLType.is_double_precision, 0},
		Type{SQLType.is_double_precision, 0},
	], func_mod}) ?
	conn.register_func(Func{'POWER', [Type{SQLType.is_double_precision, 0},
		Type{SQLType.is_double_precision, 0},
	], func_power}) ?
	conn.register_func(Func{'SIN', [Type{SQLType.is_double_precision, 0}], func_sin}) ?
	conn.register_func(Func{'SINH', [Type{SQLType.is_double_precision, 0}], func_sinh}) ?
	conn.register_func(Func{'SQRT', [Type{SQLType.is_double_precision, 0}], func_sqrt}) ?
	conn.register_func(Func{'TAN', [Type{SQLType.is_double_precision, 0}], func_tan}) ?
	conn.register_func(Func{'TANH', [Type{SQLType.is_double_precision, 0}], func_tanh}) ?
}
