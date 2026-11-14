module vsql

// ISO/IEC 9075-2:2023, 6.32, <string value expression>
//
// Specify a character string value or a binary string value.

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

// left and right are references because a CharacterValueExpression can be a
// Concatenation, and V stores a sum type's value inline.
struct Concatenation {
	left  &CharacterValueExpression
	right &CharacterValueExpression
}

fn new_concatenation(left CharacterValueExpression, right CharacterValueExpression) Concatenation {
	return Concatenation{&left, &right}
}

fn (e Concatenation) pstr(params map[string]Value) string {
	return '${e.left.pstr(params)} || ${e.right.pstr(params)}'
}

fn (e Concatenation) compile(mut c Compiler) !CompileResult {
	// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.ix
	compiled_left, compiled_right := c.with_pair_types(e.left.compile(mut c)!, e.right.compile(mut c)!,
		character_type)
	typ := concatenation_type(compiled_left.typ, compiled_right.typ)!

	return CompileResult{
		run:          fn [compiled_left, compiled_right, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			mut left := compiled_left.run(mut conn, data, params)!
			mut right := compiled_right.run(mut conn, data, params)!

			if (left.typ.typ == .is_character || left.typ.typ == .is_varchar)
				&& (right.typ.typ == .is_character || right.typ.typ == .is_varchar) {
				// ISO/IEC 9075-2:2023, 6.32, <string value expression>, General Rules, 1 and 2.b.i
				if left.is_null || right.is_null {
					return new_null_value(.is_varchar).with_type(typ)
				}

				return new_varchar_value(limit_concatenation(left.string_value() +
					right.string_value())!).with_type(typ)
			}

			return sqlstate_42883('operator does not exist: ${left.typ.typ} || ${right.typ.typ}')
		}
		typ:          typ
		contains_agg: compiled_left.contains_agg || compiled_right.contains_agg
	}
}

// concatenation_type is the declared type of a concatenation, which has the
// combined length of both operands. It's only fixed-length (CHARACTER) when
// both operands are.
//
// ISO/IEC 9075-2:2023, 6.32, <string value expression>, Syntax Rules, 3
fn concatenation_type(left Type, right Type) !Type {
	if !left.typ.is_string() || !right.typ.is_string() {
		return new_type('CHARACTER VARYING', 0, 0)
	}

	// A size of 0 means the length is unknown, so the result is too.
	size := if left.size > 0 && right.size > 0 { left.size + right.size } else { 0 }
	if left.typ == .is_character && right.typ == .is_character && size > 0 {
		// ISO/IEC 9075-2:2023, 6.32, <string value expression>, Syntax Rules, 3.b.iii
		if size > max_character_length {
			return sqlstate_42601('CHARACTER(${size}) is longer than the maximum length of ${max_character_length}')
		}

		return new_type('CHARACTER', size, 0)
	}

	// ISO/IEC 9075-2:2023, 6.32, <string value expression>, Syntax Rules, 3.b.ii
	return new_type('CHARACTER VARYING', if size > max_character_length {
		max_character_length
	} else {
		size
	}, 0)
}

// limit_concatenation returns the result of a concatenation that's no longer
// than the maximum length. A CHARACTER result can't be longer, since its type
// would've been rejected. Only spaces can be removed from the end of the result,
// otherwise it's an error.
//
// ISO/IEC 9075-2:2023, 6.32, <string value expression>, General Rules, 2.b.ii.3.B
fn limit_concatenation(s string) !string {
	// The number of characters can't be more than the number of bytes.
	if s.len <= max_character_length {
		return s
	}

	runes := s.runes()
	if runes.len <= max_character_length {
		return s
	}

	if runes[max_character_length..].any(it != ` `) {
		return sqlstate_22001(new_type('CHARACTER VARYING', max_character_length, 0))
	}

	return runes[..max_character_length].string()
}
