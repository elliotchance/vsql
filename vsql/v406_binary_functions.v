module vsql

import encoding.base64

// The functions that convert between a binary string and its hexadecimal
// digits (V406-01 and V406-02) or base64 (V406-03 and V406-04). The SQL
// standard only has binary string literals (X'CAFE') and doesn't allow a CAST
// between a binary string and a character string. A BINARY argument is a
// BINARY VARYING (see find_function), and a BINARY LARGE OBJECT is converted to
// a CHARACTER LARGE OBJECT and back. A result that isn't a large object can be
// as long as the longest CHARACTER VARYING or BINARY VARYING.

fn register_binary_funcs(mut conn Connection) ! {
	varchar := Type{SQLType.is_varchar, 0, 0, false, false}
	varbinary := Type{SQLType.is_varbinary, 0, 0, false, false}
	longest_varbinary := Type{SQLType.is_varbinary, max_binary_length, 0, false, false}
	blob := Type{SQLType.is_blob, 0, 0, false, false}
	clob := Type{SQLType.is_clob, 0, 0, false, false}

	conn.register_func(Func{'BINARY_TO_HEX', [varbinary], false, fn (_ FunctionContext, args []Value) !Value {
		digits := hex_digits(args[0].string_value())
		if digits.len > max_character_length {
			return sqlstate_22001(Type{.is_varchar, max_character_length, 0, false, false})
		}

		return new_varchar_value(digits)
	}, varchar, false, true, [vsql_binary_to_hex], [], false})!
	conn.register_func(Func{'BINARY_TO_HEX', [blob], false, fn (_ FunctionContext, args []Value) !Value {
		return new_clob_value(hex_digits(args[0].string_value()))
	}, clob, false, true, [vsql_binary_to_hex], [], false})!
	conn.register_func(Func{'HEX_TO_BINARY', [varchar], false, fn (_ FunctionContext, args []Value) !Value {
		return new_binary_string_value(.is_varbinary, unhex_digits(args[0].string_value())!)
	}, longest_varbinary, false, true, [vsql_hex_to_binary], [], false})!
	conn.register_func(Func{'HEX_TO_BINARY', [clob], false, fn (_ FunctionContext, args []Value) !Value {
		return new_binary_string_value(.is_blob, unhex_digits(args[0].string_value())!)
	}, blob, false, true, [vsql_hex_to_binary], [], false})!

	conn.register_func(Func{'BINARY_TO_BASE64', [varbinary], false, fn (_ FunctionContext, args []Value) !Value {
		text := base64.encode(args[0].string_value().bytes())
		if text.len > max_character_length {
			return sqlstate_22001(Type{.is_varchar, max_character_length, 0, false, false})
		}

		return new_varchar_value(text)
	}, varchar, false, true, [vsql_binary_to_base64], [], false})!
	conn.register_func(Func{'BINARY_TO_BASE64', [blob], false, fn (_ FunctionContext, args []Value) !Value {
		return new_clob_value(base64.encode(args[0].string_value().bytes()))
	}, clob, false, true, [vsql_binary_to_base64], [], false})!
	conn.register_func(Func{'BASE64_TO_BINARY', [varchar], false, fn (_ FunctionContext, args []Value) !Value {
		return new_binary_string_value(.is_varbinary, base64_octets(args[0].string_value())!)
	}, longest_varbinary, false, true, [vsql_base64_to_binary], [], false})!
	conn.register_func(Func{'BASE64_TO_BINARY', [clob], false, fn (_ FunctionContext, args []Value) !Value {
		return new_binary_string_value(.is_blob, base64_octets(args[0].string_value())!)
	}, blob, false, true, [vsql_base64_to_binary], [], false})!
}

// hex_digits is two upper case hexadecimal digits for each octet, the same way
// that a binary string is shown.
fn hex_digits(octets string) string {
	return octets.bytes().hex().to_upper()
}

// unhex_digits is the octets of pairs of hexadecimal digits (in upper or lower
// case). Anything else, including an odd number of digits, is a 22018 error.
fn unhex_digits(digits string) !string {
	if digits.len % 2 != 0 {
		return sqlstate_22018()
	}

	mut octets := []u8{len: digits.len / 2}
	for i in 0 .. octets.len {
		octets[i] = hex_digit(digits[i * 2])! << 4 | hex_digit(digits[i * 2 + 1])!
	}

	return octets.bytestr()
}

fn hex_digit(c u8) !u8 {
	return match c {
		`0`...`9` { c - `0` }
		`A`...`F` { c - `A` + 10 }
		`a`...`f` { c - `a` + 10 }
		else { sqlstate_22018() }
	}
}

// base64_octets decodes base64 (RFC 4648, with + and /). Whitespace is ignored,
// so text that's split into lines (as other databases do) can be decoded, and
// the = padding at the end is optional. Anything else is a 22018 error.
fn base64_octets(text string) !string {
	mut sextets := []u8{cap: text.len}
	mut padding := 0
	for c in text {
		if c in [` `, `\t`, `\n`, `\r`] {
			continue
		}
		if c == `=` {
			padding++
			continue
		}
		if padding > 0 {
			return sqlstate_22018()
		}
		sextets << base64_sextet(c)!
	}

	// The last group of 4 characters has 2 to 4 sextets, and the padding (if
	// there is any) fills the rest of it.
	if sextets.len % 4 == 1 || (padding > 0 && (sextets.len + padding) % 4 != 0) {
		return sqlstate_22018()
	}

	mut octets := []u8{cap: sextets.len * 3 / 4}
	mut bits := u32(0)
	mut bit_count := 0
	for sextet in sextets {
		bits = bits << 6 | sextet
		bit_count += 6
		if bit_count >= 8 {
			bit_count -= 8
			octets << u8(bits >> bit_count)
			bits &= (u32(1) << bit_count) - 1
		}
	}

	return octets.bytestr()
}

fn base64_sextet(c u8) !u8 {
	return match c {
		`A`...`Z` { c - `A` }
		`a`...`z` { c - `a` + 26 }
		`0`...`9` { c - `0` + 52 }
		`+` { 62 }
		`/` { 63 }
		else { sqlstate_22018() }
	}
}

// binary_arg_names are the names of the parameters of the functions in this
// file (see builtin_arg_names).
const binary_arg_names = {
	'BASE64_TO_BINARY': ['STRING']
	'BINARY_TO_BASE64': ['OCTETS']
	'BINARY_TO_HEX':    ['OCTETS']
	'HEX_TO_BINARY':    ['STRING']
}
