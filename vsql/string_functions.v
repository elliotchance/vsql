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
