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

	return CompileResult{
		run:          fn [e, compiled_value, compiled_from, compiled_for] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled_value.run(mut conn, data, params)!

			mut from := 0
			if e.from != none {
				from = int((compiled_from.run(mut conn, data, params)!).as_int() - 1)
			}

			if e.using == 'CHARACTERS' {
				characters := value.string_value().runes()

				if from >= characters.len || from < 0 {
					return new_varchar_value('')
				}

				mut @for := characters.len - from
				if e.@for != none {
					@for = int((compiled_for.run(mut conn, data, params)!).as_int())
				}

				return new_varchar_value(characters[from..from + @for].string())
			}

			if from >= value.string_value().len || from < 0 {
				return new_varchar_value('')
			}

			mut @for := value.string_value().len - from
			if e.@for != none {
				@for = int((compiled_for.run(mut conn, data, params)!).as_int())
			}

			return new_varchar_value(value.string_value().substr(from, from + @for))
		}
		typ:          new_type('CHARACTER VARYING', 0, 0)
		contains_agg: compiled_value.contains_agg
	}
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

	return CompileResult{
		run:          fn [e, compiled_source, compiled_character] (mut conn Connection, data Row, params map[string]Value) !Value {
			source := compiled_source.run(mut conn, data, params)!
			character := compiled_character.run(mut conn, data, params)!

			if e.specification == 'LEADING' {
				return new_varchar_value(source.string_value().trim_left(character.string_value()))
			}

			if e.specification == 'TRAILING' {
				return new_varchar_value(source.string_value().trim_right(character.string_value()))
			}

			return new_varchar_value(source.string_value().trim(character.string_value()))
		}
		typ:          new_type('CHARACTER VARYING', 0, 0)
		contains_agg: compiled_source.contains_agg || compiled_character.contains_agg
	}
}
