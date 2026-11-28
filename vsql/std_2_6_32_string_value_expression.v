module vsql

import math

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
	return Concatenation{heap_copy(&left), heap_copy(&right)}
}

fn (e Concatenation) pstr(params map[string]Value) string {
	return '${e.left.pstr(params)} || ${e.right.pstr(params)}'
}

fn (e Concatenation) compile(mut c Compiler) !CompileResult {
	// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.ix
	compiled_left, compiled_right := c.with_pair_types(e.left.compile(mut c)!, e.right.compile(mut c)!,
		character_type)
	if compiled_left.typ.typ.is_binary_string() && compiled_right.typ.typ.is_binary_string() {
		return compile_binary_concatenation(mut c, compiled_left, compiled_right)
	}
	typ := concatenation_type(compiled_left.typ, compiled_right.typ)!

	// ISO/IEC 9075-2:2023, 6.32, <string value expression>, Conformance Rules, 4
	if c.conn.flagging && typ.typ == .is_clob {
		c.conn.flagged_features << 'T040'
	}

	return CompileResult{
		run:          fn [compiled_left, compiled_right, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			mut left := compiled_left.run(mut conn, data, params)!
			mut right := compiled_right.run(mut conn, data, params)!

			if left.typ.typ.is_string() && right.typ.typ.is_string() {
				// ISO/IEC 9075-2:2023, 6.32, <string value expression>, General Rules, 1 and 2.b.i
				if left.is_null || right.is_null {
					return new_null_value(.is_varchar).with_type(typ)
				}

				return new_varchar_value(limit_concatenation(left.string_value() +
					right.string_value(), typ)!).with_type(typ)
			}

			return sqlstate_42883('operator does not exist: ${left.typ.typ} || ${right.typ.typ}')
		}
		typ:          typ
		contains_agg: compiled_left.contains_agg || compiled_right.contains_agg
	}
}

// concatenation_type is the declared type of a concatenation, which has the
// combined length of both operands. It's a CHARACTER LARGE OBJECT if either
// operand is, and it's only fixed-length (CHARACTER) when both operands are.
//
// ISO/IEC 9075-2:2023, 6.32, <string value expression>, Syntax Rules, 3
fn concatenation_type(left Type, right Type) !Type {
	if !left.typ.is_string() || !right.typ.is_string() {
		return new_type('CHARACTER VARYING', 0, 0)
	}

	// A size of 0 means the length is unknown (or the maximum, for a CHARACTER
	// LARGE OBJECT), so the result is too.
	size := if left.size > 0 && right.size > 0 { i64(left.size) + right.size } else { 0 }

	// ISO/IEC 9075-2:2023, 6.32, <string value expression>, Syntax Rules, 3.b.i
	if left.typ == .is_clob || right.typ == .is_clob {
		return Type{.is_clob, if size >= max_large_object_length { 0 } else { int(size) }, 0, false, false}
	}

	if left.typ == .is_character && right.typ == .is_character && size > 0 {
		// ISO/IEC 9075-2:2023, 6.32, <string value expression>, Syntax Rules, 3.b.iii
		if size > max_character_length {
			return sqlstate_42601('CHARACTER(${size}) is longer than the maximum length of ${max_character_length}')
		}

		return new_type('CHARACTER', int(size), 0)
	}

	// ISO/IEC 9075-2:2023, 6.32, <string value expression>, Syntax Rules, 3.b.ii
	return new_type('CHARACTER VARYING', if size > max_character_length {
		max_character_length
	} else {
		int(size)
	}, 0)
}

// character_limit is the most characters that a concatenation of type typ can
// have: the maximum length of a CHARACTER LARGE OBJECT, or otherwise of a
// CHARACTER VARYING.
//
// ISO/IEC 9075-2:2023, 6.32, <string value expression>, General Rules, 2.b.ii.3.A and 2.b.ii.3.B
fn character_limit(typ Type) int {
	if typ.typ == .is_clob {
		return max_large_object_length
	}

	return max_character_length
}

// limit_concatenation returns the result of a concatenation of type typ that's
// no longer than the maximum length (see character_limit). A CHARACTER result
// can't be longer, since its type would've been rejected. Only <truncating
// whitespace> can be removed from the end of the result, otherwise it's an
// error.
//
// ISO/IEC 9075-2:2023, 6.32, <string value expression>, General Rules, 2.b.ii.3.A and 2.b.ii.3.B
fn limit_concatenation(s string, typ Type) !string {
	// The number of characters can't be more than the number of bytes.
	limit := character_limit(typ)
	if s.len <= limit {
		return own_string(s)
	}

	runes := s.runes()
	if runes.len <= limit {
		return own_string(s)
	}

	if !runes[limit..].all(is_truncating_whitespace(it)) {
		return sqlstate_22001(Type{typ.typ, limit, 0, false, false})
	}

	return runes[..limit].string()
}

// compile_binary_concatenation is a <binary concatenation>, which is any
// concatenation of two binary strings. A BINARY LARGE OBJECT needs Feature T048,
// and otherwise it's T021 (either one is enough).
//
// ISO/IEC 9075-2:2023, 4.4.3.1, Operators that operate on binary strings and return binary strings
// ISO/IEC 9075-2:2023, 6.32, <string value expression>, Conformance Rules, 2 and 3
fn compile_binary_concatenation(mut c Compiler, compiled_left CompileResult, compiled_right CompileResult) !CompileResult {
	// A pointer to a copy is captured instead of the value to work around
	// https://github.com/vlang/v/issues/32934 (-autofree).
	compiled_left_ref := &CompileResult{
		...compiled_left
	}
	compiled_right_ref := &CompileResult{
		...compiled_right
	}
	typ := binary_concatenation_type(compiled_left.typ, compiled_right.typ)!
	if c.conn.flagging {
		c.conn.flagged_features << if typ.typ == .is_blob { 'T048' } else { 'T021' }
	}

	return CompileResult{
		run:          fn [compiled_left_ref, compiled_right_ref, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			left := compiled_left_ref.run(mut conn, data, params)!
			right := compiled_right_ref.run(mut conn, data, params)!

			// ISO/IEC 9075-2:2023, 6.32, <string value expression>, General Rules, 3.a
			if left.is_null || right.is_null {
				return new_null_value(typ.typ).with_type(typ)
			}

			// ISO/IEC 9075-2:2023, 6.32, <string value expression>, General Rules, 3.b
			return new_binary_string_value(typ.typ, limit_binary_concatenation(left.string_value() +
				right.string_value(), typ)!).with_type(typ)
		}
		typ:          typ
		contains_agg: compiled_left.contains_agg || compiled_right.contains_agg
	}
}

// binary_concatenation_type is the declared type of a <binary concatenation>,
// which has the combined length of both operands, up to the maximum length of
// its type. A BINARY LARGE OBJECT with a size of 0 has the maximum length, so
// a result that's as long as the maximum is also a size of 0.
//
// ISO/IEC 9075-2:2023, 6.32, <string value expression>, Syntax Rules, 6.a
fn binary_concatenation_type(left Type, right Type) !Type {
	size := i64(binary_length(left)) + binary_length(right)

	// ISO/IEC 9075-2:2023, 6.32, <string value expression>, Syntax Rules, 6.a.i
	if left.typ == .is_blob || right.typ == .is_blob {
		return Type{.is_blob, if size >= max_large_object_length { 0 } else { int(size) }, 0, false, false}
	}

	// ISO/IEC 9075-2:2023, 6.32, <string value expression>, Syntax Rules, 6.a.ii
	if left.typ == .is_varbinary || right.typ == .is_varbinary {
		return Type{.is_varbinary, int(math.min(size, max_binary_length)), 0, false, false}
	}

	// ISO/IEC 9075-2:2023, 6.32, <string value expression>, Syntax Rules, 6.a.iii
	if size > max_binary_length {
		return sqlstate_42601('BINARY(${size}) is longer than the maximum length of ${max_binary_length}')
	}

	return Type{.is_binary, int(size), 0, false, false}
}

// binary_length is the length or maximum length in octets of a binary string
// type.
fn binary_length(t Type) int {
	if t.typ == .is_blob && t.size == 0 {
		return max_large_object_length
	}

	return t.size
}

// limit_binary_concatenation returns the result of a <binary concatenation>
// that's no longer than the maximum length of its type. Only X'00' octets can be
// removed from the end of the result, otherwise it's an error. A BINARY result
// can't be longer, since its type would've been rejected.
//
// ISO/IEC 9075-2:2023, 6.32, <string value expression>, General Rules, 3.b.i and 3.b.ii
fn limit_binary_concatenation(s string, typ Type) !string {
	limit := binary_length(typ)
	if s.len <= limit {
		return own_string(s)
	}

	for i in limit .. s.len {
		if s[i] != 0 {
			return sqlstate_22001(typ)
		}
	}

	return s[..limit]
}
