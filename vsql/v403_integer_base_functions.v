module vsql

// The functions that write an integer in another base (radix), and read it
// back (V403-18 to V403-21). The SQL standard doesn't have them. Any exact
// integer is implicitly cast to a BIGINT (see find_function), and the result
// is NULL when any argument is NULL.

// base_digits are the digits of every radix from 2 to 36, in order.
const base_digits = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'

fn register_base_funcs(mut conn Connection) ! {
	varchar := Type{SQLType.is_varchar, 0, 0, false, false}
	bigint := Type{SQLType.is_bigint, 0, 0, false, false}

	conn.register_func(Func{'INTEGER_TO_BASE', [bigint, bigint], false, fn (_ FunctionContext, args []Value) !Value {
		return new_varchar_value(integer_to_base(args[0].int_value(), args[1].int_value())!)
	}, varchar, false, true, [vsql_integer_to_base], [], false})!
	conn.register_func(Func{'BASE_TO_INTEGER', [varchar, bigint], false, fn (_ FunctionContext, args []Value) !Value {
		return new_bigint_value(base_to_integer(args[0].string_value(), args[1].int_value())!)
	}, bigint, false, true, [vsql_base_to_integer], [], false})!
	conn.register_func(Func{'INTEGER_TO_HEX', [bigint], false, fn (_ FunctionContext, args []Value) !Value {
		return new_varchar_value(integer_to_base(args[0].int_value(), 16)!)
	}, varchar, false, true, [vsql_integer_to_hex], [], false})!
	conn.register_func(Func{'HEX_TO_INTEGER', [varchar], false, fn (_ FunctionContext, args []Value) !Value {
		return new_bigint_value(base_to_integer(args[0].string_value(), 16)!)
	}, bigint, false, true, [vsql_hex_to_integer], [], false})!
}

// integer_to_base writes n with the upper case digits of the radix (2 to 36),
// and a - in front of a negative number. A radix outside of 2 to 36 is a 22003
// error.
fn integer_to_base(n i64, radix i64) !string {
	check_radix(radix)!

	// The magnitude of the smallest BIGINT doesn't fit in a BIGINT.
	mut magnitude := if n < 0 { u64(0) - u64(n) } else { u64(n) }
	mut digits := []u8{}
	for {
		digits << base_digits[magnitude % u64(radix)]
		magnitude /= u64(radix)
		if magnitude == 0 {
			break
		}
	}
	if n < 0 {
		digits << `-`
	}
	digits.reverse_in_place()

	return digits.bytestr()
}

// base_to_integer reads digits of the radix (2 to 36, in upper or lower case),
// with an optional - in front. A digit that isn't in the radix (or no digits)
// is a 22018 error, and a number that doesn't fit in a BIGINT is a 22003 error.
fn base_to_integer(text string, radix i64) !i64 {
	check_radix(radix)!

	negative := text.starts_with('-')
	digits := if negative { text[1..] } else { text }
	if digits == '' {
		return sqlstate_22018()
	}

	// The smallest BIGINT is one more than the largest.
	limit := if negative { u64(max_i64) + 1 } else { u64(max_i64) }
	mut magnitude := u64(0)
	for c in digits {
		digit := u64(match c {
			`0`...`9` { c - `0` }
			`A`...`Z` { c - `A` + 10 }
			`a`...`z` { c - `a` + 10 }
			else { 36 }
		})
		if digit >= u64(radix) {
			return sqlstate_22018()
		}
		if magnitude > (limit - digit) / u64(radix) {
			return sqlstate_22003()
		}
		magnitude = magnitude * u64(radix) + digit
	}

	return if negative { i64(u64(0) - magnitude) } else { i64(magnitude) }
}

fn check_radix(radix i64) ! {
	if radix < 2 || radix > 36 {
		return sqlstate_22003()
	}
}

// base_arg_names are the names of the parameters of the functions in this file
// (see builtin_arg_names).
const base_arg_names = {
	'BASE_TO_INTEGER': ['STRING', 'RADIX']
	'HEX_TO_INTEGER':  ['STRING']
	'INTEGER_TO_BASE': ['N', 'RADIX']
	'INTEGER_TO_HEX':  ['N']
}
