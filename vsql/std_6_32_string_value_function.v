module vsql

// ISO/IEC 9075-2:2016(E), 6.32, <string value function>
//
// Specify a function yielding a value of type character string or binary
// string.

type CharacterValueFunction = CharacterSubstringFunction
	| RoutineInvocation // <fold>
	| TrimFunction

fn (e CharacterValueFunction) pstr(params map[string]Value) string {
	return match e {
		RoutineInvocation, CharacterSubstringFunction, TrimFunction {
			e.pstr(params)
		}
	}
}

fn (e CharacterValueFunction) compile(mut c Compiler) !CompileResult {
	match e {
		CharacterSubstringFunction, TrimFunction, RoutineInvocation {
			return e.compile(mut c)!
		}
	}
}

struct CharacterSubstringFunction {
	value CharacterValueExpression
	from  ?NumericValueExpression
	@for  ?NumericValueExpression
	using string // CHARACTERS or OCTETS or ''
}

fn (e CharacterSubstringFunction) pstr(params map[string]Value) string {
	mut s := 'SUBSTRING(${e.value.pstr(params)}'

	if from := e.from {
		s += ' FROM ${from.pstr(params)}'
	}

	if @for := e.@for {
		s += ' FOR ${@for.pstr(params)}'
	}

	return s + ' USING ${e.using})'
}

fn (e CharacterSubstringFunction) compile(mut c Compiler) !CompileResult {
	compiled_value := e.value.compile(mut c)!
	compiled_from := if f := e.from {
		f.compile(mut c)!
	} else {
		CompileResult{
			run:          unsafe { nil }
			typ:          Type{}
			contains_agg: false
		}
	}
	compiled_for := if f := e.@for {
		f.compile(mut c)!
	} else {
		CompileResult{
			run:          unsafe { nil }
			typ:          Type{}
			contains_agg: false
		}
	}

	// ISO/IEC 9075-2:2016(E), 6.32, <string value function>, Syntax Rules, 4
	typ := varying_string_type(compiled_value.typ)

	return CompileResult{
		run:          fn [e, compiled_value, compiled_from, compiled_for, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled_value.run(mut conn, data, params)!
			from_value := if e.from != none {
				compiled_from.run(mut conn, data, params)!
			} else {
				new_integer_value(1)
			}
			for_value := if e.@for != none {
				compiled_for.run(mut conn, data, params)!
			} else {
				new_integer_value(0)
			}

			// ISO/IEC 9075-2:2016(E), 6.32, <string value function>, General
			// Rules, 3d
			if value.is_null || from_value.is_null || for_value.is_null {
				return new_null_value(.is_varchar).with_type(typ)
			}

			if e.using == 'CHARACTERS' {
				characters := value.string_value().runes()
				start, end := substring_range(characters.len, from_value.as_int(),
					e.@for != none, for_value.as_int())!

				return new_varchar_value(characters[start..end].string()).with_type(typ)
			}

			str := value.string_value()
			start, end := substring_range(str.len, from_value.as_int(), e.@for != none,
				for_value.as_int())!

			return new_varchar_value(str.substr(start, end)).with_type(typ)
		}
		typ:          typ
		contains_agg: compiled_value.contains_agg
	}
}

// substring_range returns the zero-based start (inclusive) and end (exclusive)
// of a SUBSTRING for a string of length characters or octets, following 6.32
// General Rule 3. from is the one-based start position, which may be before the
// start or past the end of the string. Positions before the start of the string
// are skipped, so SUBSTRING('hello' FROM 0 FOR 3) is 'he'.
fn substring_range(length int, from i64, has_for bool, @for i64) !(int, int) {
	mut end := i64(0)
	if has_for {
		if @for < 0 {
			return sqlstate_22011()
		}

		end = from + @for
		// The end can only overflow when both are very large, in which case it's
		// past the end of the string.
		if end < from {
			end = max_i64
		}
	} else {
		end = if length + 1 > from { i64(length + 1) } else { from }
	}

	if from > length || end < 1 {
		return 0, 0
	}

	start := if from < 1 { i64(1) } else { from }
	if end > length + 1 {
		end = length + 1
	}

	return int(start - 1), int(end - 1)
}

struct TrimFunction {
	// LEADING, TRAILING or BOTH
	specification string
	// When not provided, it will default to ' '.
	character CharacterValueExpression
	source    CharacterValueExpression
}

fn (e TrimFunction) pstr(params map[string]Value) string {
	return 'TRIM(${e.specification} ${e.character.pstr(params)} FROM ${e.source.pstr(params)})'
}

fn (e TrimFunction) compile(mut c Compiler) !CompileResult {
	compiled_source := e.source.compile(mut c)!
	compiled_character := e.character.compile(mut c)!
	// ISO/IEC 9075-2:2016(E), 6.32, <string value function>, Syntax Rules, 13
	typ := varying_string_type(compiled_source.typ)

	return CompileResult{
		run:          fn [e, compiled_source, compiled_character, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			source := compiled_source.run(mut conn, data, params)!
			character := compiled_character.run(mut conn, data, params)!

			// ISO/IEC 9075-2:2016(E), 6.32, <string value function>, General
			// Rules, 11c
			if source.is_null || character.is_null {
				return new_null_value(.is_varchar).with_type(typ)
			}

			// ISO/IEC 9075-2:2016(E), 6.32, <string value function>, General
			// Rules, 11d
			trim_character := character.string_value().runes()
			if trim_character.len != 1 {
				return sqlstate_22027()
			}

			// Compare whole characters rather than using V's trim functions
			// which work on bytes and could split a multibyte character.
			chars := source.string_value().runes()
			mut start := 0
			mut end := chars.len
			if e.specification != 'TRAILING' {
				for start < end && chars[start] == trim_character[0] {
					start++
				}
			}
			if e.specification != 'LEADING' {
				for end > start && chars[end - 1] == trim_character[0] {
					end--
				}
			}

			return new_varchar_value(chars[start..end].string()).with_type(typ)
		}
		typ:          typ
		contains_agg: compiled_source.contains_agg || compiled_character.contains_agg
	}
}

// varying_string_type is the declared type of SUBSTRING and TRIM, which is a
// CHARACTER VARYING with the (maximum) length of the source string.
fn varying_string_type(source Type) Type {
	if !source.typ.is_string() {
		return new_type('CHARACTER VARYING', 0, 0)
	}

	return new_type('CHARACTER VARYING', source.size, 0)
}
