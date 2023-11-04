module vsql

// ISO/IEC 9075-2:2016(E), 6.31, <string value expression>
//
// # Function
//
// Specify a character string value or a binary string value.
//
// # Format
//~
//~ <string value expression> /* CharacterValueExpression */ ::=
//~     <character value expression>
//~
//~ <character value expression> /* CharacterValueExpression */ ::=
//~     <concatenation>      -> CharacterValueExpression
//~   | <character factor>   -> CharacterValueExpression
//~
//~ <concatenation> /* Concatenation */ ::=
//~     <character value expression>
//~     <concatenation operator>
//~     <character factor>             -> concatenation
//~
//~ <character factor> /* CharacterPrimary */ ::=
//~     <character primary>
//~
//~ <character primary> /* CharacterPrimary */ ::=
//~     <value expression primary>   -> CharacterPrimary
//~   | <string value function>      -> CharacterPrimary

type CharacterValueExpression = CharacterPrimary | Concatenation

fn (e CharacterValueExpression) pstr(params map[string]Value) string {
	return match e {
		Concatenation, CharacterPrimary {
			e.pstr(params)
		}
	}
}

fn (e CharacterValueExpression) compile(mut c Compiler) !CompileResult {
	match e {
		Concatenation, CharacterPrimary {
			return e.compile(mut c)!
		}
	}
}

type CharacterPrimary = CharacterValueFunction | ValueExpressionPrimary

fn (e CharacterPrimary) pstr(params map[string]Value) string {
	return match e {
		ValueExpressionPrimary, CharacterValueFunction {
			e.pstr(params)
		}
	}
}

fn (e CharacterPrimary) compile(mut c Compiler) !CompileResult {
	match e {
		ValueExpressionPrimary, CharacterValueFunction {
			return e.compile(mut c)!
		}
	}
}

struct Concatenation {
	left  CharacterValueExpression
	right CharacterValueExpression
}

fn (e Concatenation) pstr(params map[string]Value) string {
	return '${e.left.pstr(params)} || ${e.right.pstr(params)}'
}

fn (e Concatenation) compile(mut c Compiler) !CompileResult {
	compiled_left := e.left.compile(mut c)!
	compiled_right := e.right.compile(mut c)!

	return CompileResult{
		run: fn [compiled_left, compiled_right] (mut conn Connection, data Row, params map[string]Value) !Value {
			mut left := compiled_left.run(mut conn, data, params)!
			mut right := compiled_right.run(mut conn, data, params)!

			if (left.typ.typ == .is_character || left.typ.typ == .is_varchar)
				&& (right.typ.typ == .is_character || right.typ.typ == .is_varchar) {
				return new_varchar_value(left.string_value() + right.string_value())
			}

			return sqlstate_42883('operator does not exist: ${left.typ.typ} || ${right.typ.typ}')
		}
		typ: new_type('CHARACTER VARYING', 0, 0)
		contains_agg: compiled_left.contains_agg || compiled_right.contains_agg
	}
}

fn parse_concatenation(a CharacterValueExpression, b CharacterValueExpression) !Concatenation {
	return Concatenation{a, b}
}
