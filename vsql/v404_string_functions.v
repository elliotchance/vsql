module vsql

import encoding.utf8
import strings

// The string functions that the SQL standard doesn't have, but most other
// databases do (V404-02 to V404-07). They follow PostgreSQL. Like the standard
// ones, a CHARACTER is implicitly cast to a CHARACTER VARYING (keeping its
// padding), any integer is implicitly cast to a BIGINT (see find_function), and
// the result is NULL when any argument is NULL. Text is counted and compared in
// characters, not bytes.

fn register_string_funcs(mut conn Connection) ! {
	register_concat_funcs(mut conn)!

	varchar := Type{SQLType.is_varchar, 0, 0, false, false}
	integer := Type{SQLType.is_integer, 0, 0, false, false}
	bigint := Type{SQLType.is_bigint, 0, 0, false, false}
	varbinary := Type{SQLType.is_varbinary, 0, 0, false, false}
	blob := Type{SQLType.is_blob, 0, 0, false, false}
	clob := Type{SQLType.is_clob, 0, 0, false, false}

	// The result of REPLACE can be longer than any of its arguments, so it's a
	// CHARACTER VARYING without a maximum length, rather than the type of the
	// first argument (like UPPER and LOWER).
	conn.register_func(Func{'REPLACE', [varchar, varchar, varchar], false, func_replace, varchar, false, true, [
		vsql_replace,
	], [], false})!
	conn.register_func(Func{'REPEAT', [varchar, bigint], false, func_repeat, varchar, false, true, [
		vsql_repeat,
	], [], false})!
	// INITCAP has the declared type of its operand, like UPPER and LOWER (see
	// fold_result).
	conn.register_func(Func{'INITCAP', [varchar], false, func_initcap, varchar, false, true, [
		vsql_initcap,
	], [], false})!
	conn.register_func(Func{'CHR', [bigint], false, func_chr, Type{SQLType.is_varchar, 1, 0, false, false}, false, true, [
		vsql_chr,
	], [], false})!
	conn.register_func(Func{'UNICODE', [varchar], false, func_unicode, integer, false, true, [
		vsql_unicode,
	], [], false})!
	// SPLIT_PART is a CHARACTER VARYING with the length of the string, like
	// SUBSTRING (see RoutineInvocation.compile).
	conn.register_func(Func{'SPLIT_PART', [varchar, varchar, bigint], false, func_split_part, varchar, false, true, [
		vsql_split_part,
	], [], false})!
	// LENGTH (V404-10) is another name for CHAR_LENGTH. Like PostgreSQL and
	// SQLite, the length of a binary string is its number of octets, the same
	// as OCTET_LENGTH.
	conn.register_func(Func{'LENGTH', [varchar], false, func_char_length, integer, false, true, [
		vsql_length,
	], [], false})!
	conn.register_func(Func{'LENGTH', [varbinary], false, func_octet_length, integer, false, true, [
		vsql_length,
	], [], false})!
	conn.register_func(Func{'LENGTH', [blob], false, func_octet_length, integer, false, true, [
		vsql_length,
	], [], false})!
	// REVERSE (V404-11) has the type of its argument (see
	// RoutineInvocation.compile).
	conn.register_func(Func{'REVERSE', [varchar], false, func_reverse, varchar, false, true, [
		vsql_reverse,
	], [], false})!
	conn.register_func(Func{'REVERSE', [varbinary], false, func_reverse_binary, varbinary, false, true, [
		vsql_reverse,
	], [], false})!
	conn.register_func(Func{'REVERSE', [blob], false, func_reverse_binary, blob, false, true, [
		vsql_reverse,
	], [], false})!
	// LEFT and RIGHT (V404-16 and V404-17) are the first or last n characters of
	// a character string, or octets of a binary string. The result is a varying
	// string with the length of the argument, like SUBSTRING, or a large object
	// for a large object (see RoutineInvocation.compile).
	for name, f in {
		'LEFT':  [func_left, func_left_binary]
		'RIGHT': [func_right, func_right_binary]
	} {
		features := [if name == 'LEFT' { vsql_left } else { vsql_right }]
		for t in [varchar, clob] {
			conn.register_func(Func{name, [t, bigint], false, f[0], t, false, true, features, [], false})!
		}
		for t in [varbinary, blob] {
			conn.register_func(Func{name, [t, bigint], false, f[1], t, false, true, features, [], false})!
		}
	}
	// STARTS_WITH and ENDS_WITH (V404-12 and V404-13) compare character strings
	// or binary strings (see func_starts_with), like POSITION.
	boolean := Type{SQLType.is_boolean, 0, 0, false, false}
	for name, f in {
		'STARTS_WITH': func_starts_with
		'ENDS_WITH':   func_ends_with
	} {
		features := [if name == 'STARTS_WITH' { vsql_starts_with } else { vsql_ends_with }]
		conn.register_func(Func{name, [varchar, varchar], false, f, boolean, false, true, features, [], false})!
		for a in [varbinary, blob] {
			for b in [varbinary, blob] {
				conn.register_func(Func{name, [a, b], false, f, boolean, false, true, features, [], false})!
			}
		}
	}

	// QUOTE (V404-14) accepts a value of any type, so there's one for each type
	// (a CHARACTER is a CHARACTER VARYING and a BINARY is a BINARY VARYING, see
	// find_function). It's always called, because a NULL is quoted as NULL. The
	// literal of a large object is a CHARACTER LARGE OBJECT.
	$for typ in SQLType.values {
		if typ.value !in [.is_character, .is_binary] {
			conn.register_func(Func{
				name:                 'QUOTE'
				arg_types:            [
					match typ.value {
						// An interval's size is its qualifier, so 0 isn't valid.
						.is_interval_year_month { make_interval_year_month }
						.is_interval_day_time { make_interval_day_time }
						else { Type{typ.value, 0, 0, false, false} }
					},
				]
				func:                 func_quote
				return_type:          if typ.value in [.is_clob, .is_blob] {
					Type{.is_clob, 0, 0, false, false}
				} else {
					varchar
				}
				called_on_null_input: true
				is_deterministic:     true
				features:             [vsql_quote]
				arg_names:            ['VALUE']
			})!
		}
	}
	conn.register_func(Func{'QUOTE_IDENT', [varchar], false, func_quote_ident, varchar, false, true, [
		vsql_quote_ident,
	], [], false})!
}

// QUOTE(any) CHARACTER VARYING
//
// The value as an SQL literal that results in the same value, such as 'it''s',
// 1.5e0 or DATE '2026-11-17' (see Value.literal). A NULL of any type is NULL.
fn func_quote(_ FunctionContext, args []Value) !Value {
	s := args[0].literal()
	if args[0].typ.typ in [.is_clob, .is_blob] {
		return new_clob_value(s)
	}

	// The type is a CHARACTER VARYING without a maximum length, like the
	// declared type, even for NULL.
	return new_varchar_value(s).with_type(Type{.is_varchar, 0, 0, false, false})
}

// QUOTE_IDENT(CHARACTER VARYING) CHARACTER VARYING
//
// The name as a <delimited identifier>, in double quotes with each double quote
// doubled. It's always quoted, so it keeps its case. An empty name is a 22023
// error, because a <delimited identifier> can't be empty.
fn func_quote_ident(_ FunctionContext, args []Value) !Value {
	name := args[0].string_value()
	if name == '' {
		return sqlstate_22023("QUOTE_IDENT: an identifier can't be empty")
	}

	return new_varchar_value('"${name.replace('"', '""')}"')
}

// STARTS_WITH(CHARACTER VARYING, CHARACTER VARYING) BOOLEAN, and for binary
// strings
//
// TRUE if the string starts with the prefix. No character is special (unlike
// LIKE), and nothing is padded (unlike =), so the padding of a CHARACTER is
// compared like any other character. An empty prefix is always TRUE. Comparing
// the UTF-8 bytes is the same as comparing the code points, because a
// character can't start in the middle of another one. A binary string is
// compared by octet.
fn func_starts_with(_ FunctionContext, args []Value) !Value {
	return new_boolean_value(args[0].string_value().starts_with(args[1].string_value()))
}

// ENDS_WITH(CHARACTER VARYING, CHARACTER VARYING) BOOLEAN, and for binary
// strings
//
// TRUE if the string ends with the suffix, see func_starts_with.
fn func_ends_with(_ FunctionContext, args []Value) !Value {
	return new_boolean_value(args[0].string_value().ends_with(args[1].string_value()))
}

// REVERSE(CHARACTER VARYING) CHARACTER VARYING
//
// The characters in the opposite order, by code point. A character that's made
// of several code points (such as a letter followed by a combining accent)
// isn't kept together.
fn func_reverse(_ FunctionContext, args []Value) !Value {
	return new_varchar_value(args[0].string_value().runes().reverse().string())
}

// REVERSE(BINARY VARYING) BINARY VARYING, and for a BINARY LARGE OBJECT
//
// The octets in the opposite order.
fn func_reverse_binary(_ FunctionContext, args []Value) !Value {
	return new_binary_string_value(args[0].typ.typ, args[0].string_value().bytes().reverse().bytestr())
}

// LEFT(CHARACTER VARYING, BIGINT) CHARACTER VARYING
//
// The first n characters. Like PostgreSQL, a negative n is all but the last -n
// characters. It's the whole string when n is longer than it, and an empty
// string when -n is.
fn func_left(_ FunctionContext, args []Value) !Value {
	runes := args[0].string_value().runes()
	return new_varchar_value(runes[..left_right_keep(runes.len, args[1].int_value())].string())
}

// RIGHT(CHARACTER VARYING, BIGINT) CHARACTER VARYING
//
// The last n characters, or all but the first -n, see func_left.
fn func_right(_ FunctionContext, args []Value) !Value {
	runes := args[0].string_value().runes()
	return new_varchar_value(runes[runes.len - left_right_keep(runes.len, args[1].int_value())..].string())
}

// LEFT(BINARY VARYING, BIGINT) BINARY VARYING, and for a BINARY LARGE OBJECT
//
// The same as func_left, in octets.
fn func_left_binary(_ FunctionContext, args []Value) !Value {
	s := args[0].string_value()
	return new_binary_string_value(args[0].typ.typ, s[..left_right_keep(s.len, args[1].int_value())])
}

// RIGHT(BINARY VARYING, BIGINT) BINARY VARYING, and for a BINARY LARGE OBJECT
//
// The same as func_right, in octets.
fn func_right_binary(_ FunctionContext, args []Value) !Value {
	s := args[0].string_value()
	return new_binary_string_value(args[0].typ.typ, s[s.len - left_right_keep(s.len, args[1].int_value())..])
}

// left_right_keep is how many characters (or octets) LEFT or RIGHT keep from a
// string of length len: n, or len + n for a negative n, between 0 and len.
fn left_right_keep(len int, n i64) int {
	keep := if n >= 0 { n } else { len + n }
	if keep < 0 {
		return 0
	}
	if keep > len {
		return len
	}
	return int(keep)
}

// REPLACE(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING) CHARACTER VARYING
//
// Every occurrence of the second argument is replaced with the third, from left
// to right, so the occurrences don't overlap. An empty second argument doesn't
// change anything. Comparing the UTF-8 bytes is the same as comparing the
// characters, because a character can't start in the middle of another one.
fn func_replace(_ FunctionContext, args []Value) !Value {
	return new_varchar_value(args[0].string_value().replace(args[1].string_value(),
		args[2].string_value()))
}

// REPEAT(CHARACTER VARYING, BIGINT) CHARACTER VARYING
//
// The string repeated n times, or an empty string if n isn't positive. A result
// that would be longer than the maximum length of a CHARACTER VARYING is a 22001
// error, which is checked before the string is built.
fn func_repeat(_ FunctionContext, args []Value) !Value {
	s := args[0].string_value()
	n := args[1].int_value()
	if n <= 0 || s == '' {
		return new_varchar_value('')
	}

	if n > max_character_length / s.len_utf8() {
		return sqlstate_22001(new_type('CHARACTER VARYING', max_character_length, 0))
	}

	return new_varchar_value(s.repeat(int(n)))
}

// INITCAP(CHARACTER VARYING) CHARACTER VARYING
//
// The first letter of each word in upper case and the rest in lower case, with
// the same case mappings as UPPER and LOWER. A word is a run of letters and
// digits, any other character separates words.
fn func_initcap(_ FunctionContext, args []Value) !Value {
	s := args[0].string_value()
	mut result := strings.new_builder(s.len)
	mut in_word := false
	for r in s.runes_iterator() {
		if !utf8.is_letter(r) && !utf8.is_number(r) {
			result.write_rune(r)
			in_word = false
			continue
		}

		result.write_string(replace_case_mappings(r.str(), if in_word {
			lower_case_mappings
		} else {
			upper_case_mappings
		}))
		in_word = true
	}

	return new_varchar_value(result.str())
}

// CHR(BIGINT) CHARACTER VARYING(1)
//
// The character with a Unicode code point. 0, a surrogate (which can't be in
// UTF-8) or a number outside of the Unicode range is a 22023 error, and a
// noncharacter is a 22029 error like it is in a U& literal.
fn func_chr(_ FunctionContext, args []Value) !Value {
	n := args[0].int_value()
	if n <= 0 || n > 0x10FFFF || (n >= 0xD800 && n <= 0xDFFF) {
		return sqlstate_22023('CHR: ${n} is not a valid Unicode code point')
	}

	s := rune(n).str()
	check_noncharacters(s)!

	return new_varchar_value(s)
}

// UNICODE(CHARACTER VARYING) INTEGER
//
// The Unicode code point of the first character, or 0 for an empty string.
fn func_unicode(_ FunctionContext, args []Value) !Value {
	for r in args[0].string_value().runes_iterator() {
		return new_integer_value(int(r))
	}

	return new_integer_value(0)
}

// SPLIT_PART(CHARACTER VARYING, CHARACTER VARYING, BIGINT) CHARACTER VARYING
//
// The nth field (from 1) of the string split on the delimiter, or counted from
// the end when n is negative. A field that doesn't exist is an empty string,
// and n = 0 is a 22023 error. An empty delimiter doesn't split the string.
fn func_split_part(_ FunctionContext, args []Value) !Value {
	s := args[0].string_value()
	delimiter := args[1].string_value()
	n := args[2].int_value()
	if n == 0 {
		return sqlstate_22023('SPLIT_PART: field position must not be zero')
	}

	// The delimiter is valid UTF-8 so splitting the bytes can't split a
	// character.
	fields := if delimiter == '' { [s] } else { s.split(delimiter) }
	index := if n > 0 { n - 1 } else { fields.len + n }
	if index < 0 || index >= fields.len {
		return new_varchar_value('')
	}

	return new_varchar_value(fields[index])
}

// string_arg_names are the names of the parameters of the functions in this
// file (see builtin_arg_names).
const string_arg_names = {
	'CHR':         ['CODE_POINT']
	'ENDS_WITH':   ['STRING', 'SUFFIX']
	'INITCAP':     ['STRING']
	'LEFT':        ['STRING', 'N']
	'LENGTH':      ['STRING']
	'QUOTE_IDENT': ['NAME']
	'REPEAT':      ['STRING', 'N']
	'REPLACE':     ['STRING', 'TARGET', 'REPLACEMENT']
	'REVERSE':     ['STRING']
	'RIGHT':       ['STRING', 'N']
	'SPLIT_PART':  ['STRING', 'DELIMITER', 'N']
	'STARTS_WITH': ['STRING', 'PREFIX']
	'UNICODE':     ['STRING']
}
