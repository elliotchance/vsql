// funcs.v registers all the inbuilt SQL functions. They aren't SQL-invoked
// routines (there's no CREATE FUNCTION), but they have some of their
// characteristics (ISO/IEC 9075-2:2016(E), 4.33, SQL-invoked routines).

module vsql

struct Func {
	name        string
	arg_types   []Type
	is_agg      bool
	func        fn ([]Value) !Value // not used by aggregates, see eval_set_function
	return_type Type
	// called_on_null_input means the function is still called when one of the
	// arguments is NULL. Otherwise, the result will be NULL without calling the
	// function, this is the case for all builtin functions. Custom functions are
	// always called because SQL defaults to CALLED ON NULL INPUT.
	//
	// ISO/IEC 9075-2:2016(E), 11.60, <SQL-invoked routine>
	called_on_null_input bool
	// is_deterministic is true when the function always returns the same result
	// for the same arguments, so it can be used in a CHECK constraint. That's
	// all builtin functions. Custom functions can't be declared DETERMINISTIC,
	// so they're NOT DETERMINISTIC (the SQL default, see ISO/IEC 9075-2:2016(E),
	// 4.22, Determinism).
	//
	// ISO/IEC 9075-2:2016(E), 11.60, <SQL-invoked routine>
	is_deterministic bool
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

	// Scalar functions. The trigonometric functions, LN, EXP, POWER and SQRT
	// return a DOUBLE PRECISION (the approximate numeric type is
	// implementation-defined), and so do FLOOR and CEIL of an approximate number.
	// None of them are called with a NULL argument, the result is NULL.
	//
	// ISO/IEC 9075-2:2016(E), 6.30, <numeric value function>, Syntax Rules, 13.b and 16-18
	// ISO/IEC 9075-2:2016(E), 6.30, <numeric value function>, Syntax Rules, 20.b
	// ISO/IEC 9075-2:2016(E), 6.30, <numeric value function>, General Rules, 1.b
	conn.register_func(Func{'ABS', [double_precision], false, func_abs, double_precision, false, true})!
	conn.register_func(Func{'ABS', [numeric], false, func_abs_numeric, numeric, false, true})!
	conn.register_func(Func{'ABS', [decimal], false, func_abs_decimal, decimal, false, true})!
	conn.register_func(Func{'ABS', [smallint], false, func_abs_integer, smallint, false, true})!
	conn.register_func(Func{'ABS', [integer], false, func_abs_integer, integer, false, true})!
	conn.register_func(Func{'ABS', [bigint], false, func_abs_integer, bigint, false, true})!
	conn.register_func(Func{'ABS', [real], false, func_abs_real, real, false, true})!
	conn.register_func(Func{'ACOS', [double_precision], false, func_acos, double_precision, false, true})!
	conn.register_func(Func{'ASIN', [double_precision], false, func_asin, double_precision, false, true})!
	conn.register_func(Func{'ATAN', [double_precision], false, func_atan, double_precision, false, true})!
	conn.register_func(Func{'CEIL', [double_precision], false, func_ceil, double_precision, false, true})!
	conn.register_func(Func{'CEIL', [numeric], false, func_ceil_numeric, numeric, false, true})!
	conn.register_func(Func{'CEILING', [double_precision], false, func_ceil, double_precision, false, true})!
	conn.register_func(Func{'CEILING', [numeric], false, func_ceil_numeric, numeric, false, true})!
	conn.register_func(Func{'CHARACTER_LENGTH', [varchar], false, func_char_length, integer, false, true})!
	conn.register_func(Func{'CHAR_LENGTH', [varchar], false, func_char_length, integer, false, true})!
	conn.register_func(Func{'COS', [double_precision], false, func_cos, double_precision, false, true})!
	conn.register_func(Func{'COSH', [double_precision], false, func_cosh, double_precision, false, true})!
	conn.register_func(Func{'EXP', [double_precision], false, func_exp, double_precision, false, true})!
	conn.register_func(Func{'FLOOR', [double_precision], false, func_floor, double_precision, false, true})!
	conn.register_func(Func{'FLOOR', [numeric], false, func_floor_numeric, numeric, false, true})!
	conn.register_func(Func{'LN', [double_precision], false, func_ln, double_precision, false, true})!
	conn.register_func(Func{'LOG10', [double_precision], false, func_log10, double_precision, false, true})!
	conn.register_func(Func{'LOWER', [varchar], false, func_lower, varchar, false, true})!
	conn.register_func(Func{'MOD', [double_precision, double_precision], false, func_mod, double_precision, false, true})!
	conn.register_func(Func{'MOD', [numeric, numeric], false, func_mod_numeric, numeric, false, true})!
	// The result of MOD has the type of the divisor, so there is one for each
	// combination of integer types.
	//
	// ISO/IEC 9075-2:2016(E), 6.30, <numeric value function>, Syntax Rules, 12.b
	for dividend in [smallint, integer, bigint] {
		for divisor in [smallint, integer, bigint] {
			conn.register_func(Func{'MOD', [dividend, divisor], false, func_mod_integer, divisor, false, true})!
		}
	}
	conn.register_func(Func{'OCTET_LENGTH', [varchar], false, func_octet_length, integer, false, true})!
	conn.register_func(Func{'POSITION', [varchar, varchar], false, func_position, integer, false, true})!
	conn.register_func(Func{'POWER', [double_precision, double_precision], false, func_power, double_precision, false, true})!
	conn.register_func(Func{'SIN', [double_precision], false, func_sin, double_precision, false, true})!
	conn.register_func(Func{'SINH', [double_precision], false, func_sinh, double_precision, false, true})!
	conn.register_func(Func{'SQRT', [double_precision], false, func_sqrt, double_precision, false, true})!
	conn.register_func(Func{'TAN', [double_precision], false, func_tan, double_precision, false, true})!
	conn.register_func(Func{'TANH', [double_precision], false, func_tanh, double_precision, false, true})!
	conn.register_func(Func{'UPPER', [varchar], false, func_upper, varchar, false, true})!

	// Aggregate functions. COUNT accepts a value of any type because it only
	// counts the non-NULL values (GR 7.d.i). MAX and MIN accept any type that can
	// be ordered, which is every type (SR 7.d), and SUM and AVG accept any number
	// (SR 7.g.i). Every SQLType is registered, so a new type is supported
	// automatically. CHARACTER uses the CHARACTER VARYING one, see find_function.
	// The result type depends on the argument (see set_function_type) and the
	// result is calculated by eval_set_function.
	//
	// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 7.d and 7.g.i
	// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, General Rules, 7.d.i
	$for typ in SQLType.values {
		if typ.value != SQLType.is_character {
			arg := Type{typ.value, 0, 0, false}
			mut names := ['COUNT', 'MAX', 'MIN']
			if typ.value.is_number() {
				names << ['AVG', 'SUM']
			}
			for name in names {
				conn.register_func(Func{
					name:        name
					arg_types:   [arg]
					is_agg:      true
					return_type: set_function_type(name, arg)
				})!
			}
		}
	}
}
