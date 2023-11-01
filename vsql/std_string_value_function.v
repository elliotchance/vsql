module vsql

// ISO/IEC 9075-2:2016(E), 6.32, <string value function>
//
// # Function
//
// Specify a function yielding a value of type character string or binary string.
//
// # Format
//~
//~ <string value function> /* CharacterValueFunction */ ::=
//~     <character value function>
//~
//~ <character value function> /* CharacterValueFunction */ ::=
//~     <character substring function>   -> CharacterValueFunction
//~   | <fold>                           -> CharacterValueFunction
//~   | <trim function>                  -> CharacterValueFunction
//~
//~ <character substring function> /* CharacterSubstringFunction */ ::=
//~     SUBSTRING <left paren> <character value expression>
//~     FROM <start position> <right paren>                   -> character_substring_function_1
//~   | SUBSTRING <left paren> <character value expression>
//~     FROM <start position>
//~     FOR <string length> <right paren>                     -> character_substring_function_2
//~   | SUBSTRING <left paren> <character value expression>
//~     FROM <start position>
//~     USING <char length units> <right paren>               -> character_substring_function_3
//~   | SUBSTRING <left paren> <character value expression>
//~     FROM <start position>
//~     FOR <string length>
//~     USING <char length units> <right paren>               -> character_substring_function_4
//~
//~ <fold> /* RoutineInvocation */ ::=
//~     UPPER <left paren> <character value expression> <right paren>   -> upper
//~   | LOWER <left paren> <character value expression> <right paren>   -> lower
//~
//~ <trim function> /* TrimFunction */ ::=
//~   TRIM <left paren> <trim operands> <right paren>   -> trim_function
//~
//~ <trim operands> /* TrimFunction */ ::=
//~     <trim source>                                              -> trim_operands_1
//~   | FROM <trim source>                                         -> trim_operands_1
//~   | <trim specification> FROM <trim source>                    -> trim_operands_2
//~   | <trim character> FROM <trim source>                        -> trim_operands_3
//~   | <trim specification> <trim character> FROM <trim source>   -> trim_operands_4
//~
//~ <trim source> /* CharacterValueExpression */ ::=
//~     <character value expression>
//~
//~ <trim specification> /* string */ ::=
//~     LEADING
//~   | TRAILING
//~   | BOTH
//~
//~ <trim character> /* CharacterValueExpression */ ::=
//~     <character value expression>
//~
//~ <start position> /* NumericValueExpression */ ::=
//~     <numeric value expression>
//~
//~ <string length> /* NumericValueExpression */ ::=
//~     <numeric value expression>

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

fn (e CharacterValueFunction) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	return match e {
		CharacterSubstringFunction, TrimFunction, RoutineInvocation {
			e.eval(mut conn, data, params)!
		}
	}
}

fn (e CharacterValueFunction) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return new_type('CHARACTER VARYING', 0, 0)
}

fn (e CharacterValueFunction) resolve_identifiers(conn &Connection, tables map[string]Table) !CharacterValueFunction {
	match e {
		CharacterSubstringFunction {
			from := if t := e.from {
				?NumericValueExpression(t.resolve_identifiers(conn, tables)!)
			} else {
				?NumericValueExpression(none)
			}
			@for := if t := e.@for {
				?NumericValueExpression(t.resolve_identifiers(conn, tables)!)
			} else {
				?NumericValueExpression(none)
			}

			return CharacterSubstringFunction{e.value.resolve_identifiers(conn, tables)!, from, @for, e.using}
		}
		RoutineInvocation {
			return e.resolve_identifiers(conn, tables)!
		}
		TrimFunction {
			return TrimFunction{e.specification, e.character.resolve_identifiers(conn,
				tables)!, e.source.resolve_identifiers(conn, tables)!}
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

fn (e CharacterSubstringFunction) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	value := e.value.eval(mut conn, data, params)!

	mut from := 0
	if f := e.from {
		from = int((f.eval(mut conn, data, params)!).as_int() - 1)
	}

	if e.using == 'CHARACTERS' {
		characters := value.string_value().runes()

		if from >= characters.len || from < 0 {
			return new_varchar_value('')
		}

		mut @for := characters.len - from
		if f := e.@for {
			@for = int((f.eval(mut conn, data, params)!).as_int())
		}

		return new_varchar_value(characters[from..from + @for].string())
	}

	if from >= value.string_value().len || from < 0 {
		return new_varchar_value('')
	}

	mut @for := value.string_value().len - from
	if f := e.@for {
		@for = int((f.eval(mut conn, data, params)!).as_int())
	}

	return new_varchar_value(value.string_value().substr(from, from + @for))
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

fn (e TrimFunction) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	source := e.source.eval(mut conn, data, params)!
	character := e.character.eval(mut conn, data, params)!

	if e.specification == 'LEADING' {
		return new_varchar_value(source.string_value().trim_left(character.string_value()))
	}

	if e.specification == 'TRAILING' {
		return new_varchar_value(source.string_value().trim_right(character.string_value()))
	}

	return new_varchar_value(source.string_value().trim(character.string_value()))
}

fn parse_character_substring_function_1(value CharacterValueExpression, from NumericValueExpression) !CharacterSubstringFunction {
	return CharacterSubstringFunction{value, from, none, 'CHARACTERS'}
}

fn parse_character_substring_function_2(value CharacterValueExpression, from NumericValueExpression, @for NumericValueExpression) !CharacterSubstringFunction {
	return CharacterSubstringFunction{value, from, @for, 'CHARACTERS'}
}

fn parse_character_substring_function_3(value CharacterValueExpression, from NumericValueExpression, using string) !CharacterSubstringFunction {
	return CharacterSubstringFunction{value, from, none, using}
}

fn parse_character_substring_function_4(value CharacterValueExpression, from NumericValueExpression, @for NumericValueExpression, using string) !CharacterSubstringFunction {
	return CharacterSubstringFunction{value, from, @for, using}
}

fn parse_upper(expr CharacterValueExpression) !RoutineInvocation {
	return RoutineInvocation{'UPPER', [ValueExpression(CommonValueExpression(expr))]}
}

fn parse_lower(expr CharacterValueExpression) !RoutineInvocation {
	return RoutineInvocation{'LOWER', [ValueExpression(CommonValueExpression(expr))]}
}

fn parse_trim_operands_1(source CharacterValueExpression) !TrimFunction {
	space := CharacterValueExpression(CharacterPrimary(ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(ValueSpecification(new_varchar_value(' '))))))
	return TrimFunction{'BOTH', space, source}
}

fn parse_trim_operands_2(specification string, source CharacterValueExpression) !TrimFunction {
	space := CharacterValueExpression(CharacterPrimary(ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(ValueSpecification(new_varchar_value(' '))))))
	return TrimFunction{specification, space, source}
}

fn parse_trim_operands_3(character CharacterValueExpression, source CharacterValueExpression) !TrimFunction {
	return TrimFunction{'BOTH', character, source}
}

fn parse_trim_operands_4(specification string, character CharacterValueExpression, source CharacterValueExpression) !TrimFunction {
	return TrimFunction{specification, character, source}
}

fn parse_trim_function(e TrimFunction) !TrimFunction {
	return e
}
