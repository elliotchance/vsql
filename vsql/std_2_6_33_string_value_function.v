module vsql

import math

// ISO/IEC 9075-2:2023, 6.33, <string value function>
//
// Specify a function yielding a value of type character string or binary
// string.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2023, 4.3.3, Operations involving character strings

type CharacterValueFunction = CharacterSubstringFunction
	| MultiCharacterTrimFunction
	| OverlayFunction
	| PadFunction
	| RegularExpressionSubstringFunction
	| RoutineInvocation // <fold>
	| TrimFunction

fn (e CharacterValueFunction) pstr(params map[string]Value) string {
	return match e {
		RoutineInvocation, CharacterSubstringFunction, OverlayFunction,
		RegularExpressionSubstringFunction, TrimFunction, MultiCharacterTrimFunction, PadFunction {
			e.pstr(params)
		}
	}
}

fn (e CharacterValueFunction) compile(mut c Compiler) !CompileResult {
	match e {
		CharacterSubstringFunction, OverlayFunction, RegularExpressionSubstringFunction,
		TrimFunction, RoutineInvocation, MultiCharacterTrimFunction, PadFunction {
			return e.compile(mut c)!
		}
	}
}

// value is a reference because it can contain another CharacterSubstringFunction,
// and V stores a sum type's value inline.
struct CharacterSubstringFunction {
	value &CharacterValueExpression
	from  ?&NumericValueExpression
	@for  ?&NumericValueExpression
	// CHARACTERS or OCTETS, or '' without USING, which is CHARACTERS for a
	// character string. A binary string can't have USING.
	//
	// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 6
	using string
}

fn new_character_substring_function(value CharacterValueExpression, from NumericValueExpression, @for ?NumericValueExpression, using string) CharacterSubstringFunction {
	mut for_ref := ?&NumericValueExpression(none)
	if f := @for {
		for_ref = ref_numeric_value_expression(f)
	}
	return CharacterSubstringFunction{heap_copy(&value), heap_copy(&from), for_ref, using}
}

fn ref_numeric_value_expression(e NumericValueExpression) &NumericValueExpression {
	return heap_copy(&e)
}

fn (e CharacterSubstringFunction) pstr(params map[string]Value) string {
	mut s := 'SUBSTRING(${e.value.pstr(params)}'

	if from := opt_copy(e.from) {
		s += ' FROM ${from.pstr(params)}'
	}

	if @for := e.@for {
		s += ' FOR ${@for.pstr(params)}'
	}

	if e.using != '' {
		s += ' USING ${e.using}'
	}

	return s + ')'
}

// A dynamic parameter that is the start position or string length has the type
// position_parameter_type.
//
// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.vi
fn (e CharacterSubstringFunction) compile(mut c Compiler) !CompileResult {
	// A pointer to a copy is captured instead of the value to work around
	// https://github.com/vlang/v/issues/32934 (-autofree).
	e_ref := &CharacterSubstringFunction{
		...e
	}
	compiled_value := e.value.compile(mut c)!
	compiled_from := if f := opt_copy(e.from) {
		check_substring_argument('SUBSTRING', 'start position', f, c.with_type(f.compile(mut c)!,
			position_parameter_type).typ)!
		f.compile(mut c)!
	} else {
		CompileResult{
			run:          unsafe { nil }
			typ:          Type{}
			contains_agg: false
		}
	}
	compiled_for := if f := opt_copy(e.@for) {
		check_substring_argument('SUBSTRING', 'string length', f, c.with_type(f.compile(mut c)!,
			position_parameter_type).typ)!
		f.compile(mut c)!
	} else {
		CompileResult{
			run:          unsafe { nil }
			typ:          Type{}
			contains_agg: false
		}
	}

	if compiled_value.typ.typ.is_binary_string() {
		return e.compile_binary(mut c, compiled_value, compiled_from, compiled_for)
	}

	// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 4
	typ := varying_string_type('SUBSTRING', compiled_value.typ)!
	c.flag_clob_function(typ)

	return CompileResult{
		run:          fn [e_ref, compiled_value, compiled_from, compiled_for, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled_value.run(mut conn, data, params)!
			from_value := if e_ref.from != none {
				compiled_from.run(mut conn, data, params)!
			} else {
				new_integer_value(1)
			}
			for_value := if e_ref.@for != none {
				compiled_for.run(mut conn, data, params)!
			} else {
				new_integer_value(0)
			}

			// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 3.d
			if value.is_null || from_value.is_null || for_value.is_null {
				return new_null_value(.is_varchar).with_type(typ)
			}

			// A large value where each character is one octet is counted in
			// octets, so that only the part that's in the result is read.
			if e_ref.using == 'OCTETS' || value.is_large_single_octet() {
				start, end := substring_range(value.octet_length(), substring_position('SUBSTRING',
					'start position', from_value)!, e_ref.@for != none, substring_position('SUBSTRING',
					'string length', for_value)!)!

				return new_varchar_value(value.octets(start, end)!).with_type(typ)
			}

			characters := value.string_value().runes()
			start, end := substring_range(characters.len, substring_position('SUBSTRING',
				'start position', from_value)!, e_ref.@for != none, substring_position('SUBSTRING',
				'string length', for_value)!)!

			return new_varchar_value(characters[start..end].string()).with_type(typ)
		}
		typ:          typ
		contains_agg: compiled_value.contains_agg || compiled_from.contains_agg
			|| compiled_for.contains_agg
	}
}

// compile_binary is a <binary substring function>, which is a <binary value
// function> (Feature T022). The value is counted in octets, and only the octets
// of a large value that are in the result are read. It needs Feature T047 for a
// BINARY LARGE OBJECT.
//
// ISO/IEC 9075-2:2023, 4.4.3, Operations involving binary strings
// ISO/IEC 9075-2:2023, 4.4.3.1, Operators that operate on binary strings and return binary strings
// ISO/IEC 9075-2:2023, 6.33, <string value function>, Conformance Rules, 5 and 18
fn (e CharacterSubstringFunction) compile_binary(mut c Compiler, compiled_value CompileResult, compiled_from CompileResult, compiled_for CompileResult) !CompileResult {
	// A pointer to a copy is captured instead of the value to work around
	// https://github.com/vlang/v/issues/32934 (-autofree).
	compiled_for_ref := &CompileResult{
		...compiled_for
	}
	compiled_from_ref := &CompileResult{
		...compiled_from
	}
	compiled_value_ref := &CompileResult{
		...compiled_value
	}
	e_ref := &CharacterSubstringFunction{
		...e
	}
	if e.using != '' {
		return sqlstate_42601('SUBSTRING of ${compiled_value.typ} cannot have USING ${e.using}')
	}

	// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 20 and 21
	typ := binary_value_function_type(compiled_value.typ)
	c.flag_binary_value_function(typ)

	return CompileResult{
		run:          fn [e_ref, compiled_value_ref, compiled_from_ref, compiled_for_ref, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled_value_ref.run(mut conn, data, params)!
			from_value := compiled_from_ref.run(mut conn, data, params)!
			for_value := if e_ref.@for != none {
				compiled_for_ref.run(mut conn, data, params)!
			} else {
				new_integer_value(0)
			}

			// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 17.c
			if value.is_null || from_value.is_null || for_value.is_null {
				return new_null_value(typ.typ).with_type(typ)
			}

			// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 17.a, 17.b, 17.d and 17.e
			start, end := substring_range(value.octet_length(), substring_position('SUBSTRING',
				'start position', from_value)!, e_ref.@for != none, substring_position('SUBSTRING',
				'string length', for_value)!)!

			return new_binary_string_value(typ.typ, value.octets(start, end)!).with_type(typ)
		}
		typ:          typ
		contains_agg: compiled_value.contains_agg || compiled_from.contains_agg
			|| compiled_for.contains_agg
	}
}

// binary_value_function_type is the declared type of a <binary substring
// function> or <binary trim function>, which is a BINARY VARYING with the
// (maximum) length of the source, or a BINARY LARGE OBJECT of the same maximum
// length if the source is one.
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 21 and 22.b
fn binary_value_function_type(source Type) Type {
	if source.typ == .is_blob {
		return Type{.is_blob, source.size, 0, false, false}
	}

	return Type{.is_varbinary, source.size, 0, false, false}
}

// flag_binary_value_function flags a <binary value function> (T022), and one
// whose source is a BINARY LARGE OBJECT (T047).
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, Conformance Rules, 5 and 18
fn (mut c Compiler) flag_binary_value_function(typ Type) {
	if c.conn.flagging {
		c.conn.flag('T022')
		if typ.typ == .is_blob {
			c.conn.flag('T047')
		}
	}
}

// check_substring_argument returns an error if the start position or string
// length of a SUBSTRING (or OVERLAY, which is made of SUBSTRINGs) isn't an exact
// numeric with scale 0. A dynamic parameter ("?") is NUMERIC(1000, 0) (see
// position_parameter_type), unless its type isn't known when the statement is
// prepared (see describe_parameters). Then it may be any number that's a whole
// number (see substring_position).
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 3
fn check_substring_argument(function_name string, name string, e NumericValueExpression, typ Type) ! {
	if typ.typ in [.is_smallint, .is_integer, .is_bigint]
		|| (typ.typ in [.is_numeric, .is_decimal] && typ.scale == 0) {
		return
	}

	if is_numeric_dynamic_parameter(e) && typ.typ.is_number() {
		return
	}

	return sqlstate_42601('${function_name} ${name} must be an exact numeric with scale 0, got ${typ}')
}

// is_numeric_dynamic_parameter is true if the expression is only a dynamic
// parameter ("?").
fn is_numeric_dynamic_parameter(e NumericValueExpression) bool {
	if e.n != none || e.term.term != none {
		return false
	}

	f := e.term.factor
	if f is ValueExpressionPrimary {
		if f is NonparenthesizedValueExpressionPrimary {
			if f is ValueSpecification {
				if f is GeneralValueSpecification {
					return f is DynamicParameterSpecification
				}
			}
		}
	}

	return false
}

// substring_position returns the start position or string length of a
// SUBSTRING (or OVERLAY). A dynamic parameter must be a whole number.
fn substring_position(function_name string, name string, v Value) !i64 {
	if !v.typ.uses_int() && v.as_f64()! != math.trunc(v.as_f64()!) {
		return sqlstate_42601('${function_name} ${name} must be a whole number, got ${v.str()}')
	}

	return v.as_int()
}

// substring_range returns the zero-based start (inclusive) and end (exclusive)
// of a SUBSTRING for a string of length characters or octets. from is the
// one-based start position, which may be before the start or past the end of
// the string. Positions before the start of the string are skipped, so
// SUBSTRING('hello' FROM 0 FOR 3) is 'he'.
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 3.c, 3.e and 3.f
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

// OverlayFunction is OVERLAY(value PLACING placing FROM from [ FOR for ]
// [ USING using ]). It replaces the part of value that starts at from and is
// for characters (or octets) long with placing.
//
// The expressions are references because a CharacterValueExpression can contain
// an OverlayFunction, and V stores a sum type's value inline.
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 17
struct OverlayFunction {
	value   &CharacterValueExpression
	placing &CharacterValueExpression
	from    &NumericValueExpression
	@for    ?&NumericValueExpression
	using   string // CHARACTERS, OCTETS or '' (see CharacterSubstringFunction)
}

fn new_overlay_function(value CharacterValueExpression, placing CharacterValueExpression, from NumericValueExpression, @for ?NumericValueExpression, using string) OverlayFunction {
	mut for_ref := ?&NumericValueExpression(none)
	if f := @for {
		for_ref = ref_numeric_value_expression(f)
	}
	return OverlayFunction{heap_copy(&value), heap_copy(&placing), heap_copy(&from), for_ref, using}
}

fn (e OverlayFunction) pstr(params map[string]Value) string {
	mut s := 'OVERLAY(${e.value.pstr(params)} PLACING ${e.placing.pstr(params)} FROM ${e.from.pstr(params)}'
	if @for := e.@for {
		s += ' FOR ${@for.pstr(params)}'
	}

	if e.using != '' {
		s += ' USING ${e.using}'
	}

	return s + ')'
}

fn (e OverlayFunction) compile(mut c Compiler) !CompileResult {
	// A pointer to a copy is captured instead of the value to work around
	// https://github.com/vlang/v/issues/32934 (-autofree).
	e_ref := &OverlayFunction{
		...e
	}
	// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.viii
	compiled_value, compiled_placing := c.with_pair_types(e.value.compile(mut c)!, e.placing.compile(mut c)!,
		character_type)
	compiled_from := c.with_type(e.from.compile(mut c)!, position_parameter_type)
	check_substring_argument('OVERLAY', 'start position', e.from, compiled_from.typ)!
	compiled_for := if f := opt_copy(e.@for) {
		check_substring_argument('OVERLAY', 'string length', f, c.with_type(f.compile(mut c)!,
			position_parameter_type).typ)!
		f.compile(mut c)!
	} else {
		CompileResult{
			run:          unsafe { nil }
			typ:          Type{}
			contains_agg: false
		}
	}

	if compiled_value.typ.typ.is_binary_string() && compiled_placing.typ.typ.is_binary_string() {
		return e.compile_binary(mut c, compiled_value, compiled_placing, compiled_from, compiled_for)
	}

	if !compiled_value.typ.typ.is_string() || !compiled_placing.typ.typ.is_string() {
		return sqlstate_42883('function does not exist: OVERLAY(${compiled_value.typ} PLACING ${compiled_placing.typ})')
	}

	// OVERLAY is equivalent to:
	//
	//   SUBSTRING(CV FROM 1 FOR SP - 1) || RS || SUBSTRING(CV FROM SP + SL)
	//
	// so its type is the concatenation of the SUBSTRINGs (each a CHARACTER
	// VARYING as long as CV) and RS.
	//
	// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 17.c
	substring_type := varying_string_type('OVERLAY', compiled_value.typ)!
	typ := concatenation_type(concatenation_type(substring_type, compiled_placing.typ)!,
		substring_type)!

	return CompileResult{
		run:          fn [e_ref, compiled_value, compiled_placing, compiled_from, compiled_for, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled_value.run(mut conn, data, params)!
			placing := compiled_placing.run(mut conn, data, params)!
			from_value := compiled_from.run(mut conn, data, params)!
			for_value := if e_ref.@for != none {
				compiled_for.run(mut conn, data, params)!
			} else {
				new_integer_value(0)
			}

			// ISO/IEC 9075-2:2023, 6.32, <string value expression>, General Rules, 2.a
			// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 3.d
			if value.is_null || placing.is_null || from_value.is_null || for_value.is_null {
				return new_null_value(.is_varchar).with_type(typ)
			}

			from := substring_position('OVERLAY', 'start position', from_value)!
			if e_ref.using != 'OCTETS' {
				characters := value.string_value().runes()
				placing_characters := placing.string_value().runes()
				// Without FOR, the string length is CHAR_LENGTH(RS).
				//
				// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 17.b
				length := if e_ref.@for != none {
					substring_position('OVERLAY', 'string length', for_value)!
				} else {
					i64(placing_characters.len)
				}
				before_start, before_end := substring_range(characters.len, 1, true,
					overlay_before_length(from))!
				after_start, after_end := substring_range(characters.len, overlay_after(from,
					length), false, 0)!

				return new_varchar_value(limit_concatenation(characters[before_start..before_end].string() +
					placing.string_value() + characters[after_start..after_end].string(), typ)!).with_type(typ)
			}

			str := value.string_value()
			length := if e_ref.@for != none {
				substring_position('OVERLAY', 'string length', for_value)!
			} else {
				i64(placing.string_value().len)
			}
			before_start, before_end := substring_range(str.len, 1, true, overlay_before_length(from))!
			after_start, after_end := substring_range(str.len, overlay_after(from, length),
				false, 0)!

			return new_varchar_value(limit_concatenation(str.substr(before_start, before_end) +
				placing.string_value() + str.substr(after_start, after_end), typ)!).with_type(typ)
		}
		typ:          typ
		contains_agg: compiled_value.contains_agg || compiled_placing.contains_agg
			|| compiled_from.contains_agg || compiled_for.contains_agg
	}
}

// compile_binary is a <binary overlay function>, which is a <binary value
// function> (Feature T022). It's the same as the concatenation of SUBSTRINGs of
// the value and the replacement, counted in octets, so its type is the
// <binary concatenation> of their types.
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 23
// ISO/IEC 9075-2:2023, 6.33, <string value function>, Conformance Rules, 5
fn (e OverlayFunction) compile_binary(mut c Compiler, compiled_value CompileResult, compiled_placing CompileResult, compiled_from CompileResult, compiled_for CompileResult) !CompileResult {
	// A pointer to a copy is captured instead of the value to work around
	// https://github.com/vlang/v/issues/32934 (-autofree).
	compiled_for_ref := &CompileResult{
		...compiled_for
	}
	compiled_from_ref := &CompileResult{
		...compiled_from
	}
	compiled_placing_ref := &CompileResult{
		...compiled_placing
	}
	compiled_value_ref := &CompileResult{
		...compiled_value
	}
	e_ref := &OverlayFunction{
		...e
	}
	if e.using != '' {
		return sqlstate_42601('OVERLAY of ${compiled_value.typ} cannot have USING ${e.using}')
	}

	// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 23.c
	substring_type := binary_value_function_type(compiled_value.typ)
	typ := binary_concatenation_type(binary_concatenation_type(substring_type, compiled_placing.typ)!,
		substring_type)!
	c.flag_binary_value_function(typ)

	return CompileResult{
		run:          fn [e_ref, compiled_value_ref, compiled_placing_ref, compiled_from_ref, compiled_for_ref, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled_value_ref.run(mut conn, data, params)!
			placing := compiled_placing_ref.run(mut conn, data, params)!
			from_value := compiled_from_ref.run(mut conn, data, params)!
			for_value := if e_ref.@for != none {
				compiled_for_ref.run(mut conn, data, params)!
			} else {
				new_integer_value(0)
			}

			// ISO/IEC 9075-2:2023, 6.32, <string value expression>, General Rules, 1
			// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 17.c
			if value.is_null || placing.is_null || from_value.is_null || for_value.is_null {
				return new_null_value(typ.typ).with_type(typ)
			}

			// Without FOR, the string length is OCTET_LENGTH(RS).
			//
			// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 23.b
			from := substring_position('OVERLAY', 'start position', from_value)!
			length := if e_ref.@for != none {
				substring_position('OVERLAY', 'string length', for_value)!
			} else {
				i64(placing.octet_length())
			}
			str := value.string_value()
			before_start, before_end := substring_range(str.len, 1, true, overlay_before_length(from))!
			after_start, after_end := substring_range(str.len, overlay_after(from, length),
				false, 0)!

			return new_binary_string_value(typ.typ, limit_binary_concatenation(str[before_start..before_end] +
				placing.string_value() + str[after_start..after_end], typ)!).with_type(typ)
		}
		typ:          typ
		contains_agg: compiled_value.contains_agg || compiled_placing.contains_agg
			|| compiled_from.contains_agg || compiled_for.contains_agg
	}
}

// overlay_before_length is SP - 1, the length of the part of an OVERLAY before
// the replacement. A start position before 1 makes it negative, which is a
// substring error. The smallest start position can't be subtracted from, but
// it's negative anyway.
fn overlay_before_length(from i64) i64 {
	return if from == min_i64 { -1 } else { from - 1 }
}

// overlay_after is SP + SL, the start of the part of an OVERLAY after the
// replacement. SP is at least 1 (see overlay_before_length), so the sum can only
// overflow when SL is large, and then it's past the end of any string.
fn overlay_after(from i64, length i64) i64 {
	sum := from + length
	if sum < from && length > 0 {
		return max_i64
	}

	return sum
}

// character and source are references because a CharacterValueExpression can
// contain a TrimFunction, and V stores a sum type's value inline.
// RegularExpressionSubstringFunction is
// "SUBSTRING(value SIMILAR pattern ESCAPE escape)". The pattern is split into
// three SIMILAR TO patterns by the escape character followed by a double quote,
// and the result is the part of value that matches the middle one. The fields
// are references for the same reason as CharacterSubstringFunction.
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, Format
// ISO/IEC 9075-2:2023, 4.3.3.2, Operators that operate on character strings and return character strings
struct RegularExpressionSubstringFunction {
	value   &CharacterValueExpression
	pattern &CharacterValueExpression
	escape  &CharacterValueExpression
}

fn new_regular_expression_substring_function(value CharacterValueExpression, pattern CharacterValueExpression, escape CharacterValueExpression) RegularExpressionSubstringFunction {
	return RegularExpressionSubstringFunction{heap_copy(&value), heap_copy(&pattern), heap_copy(&escape)}
}

fn (e RegularExpressionSubstringFunction) pstr(params map[string]Value) string {
	return 'SUBSTRING(${e.value.pstr(params)} SIMILAR ${e.pattern.pstr(params)} ESCAPE ${e.escape.pstr(params)})'
}

// The value, the pattern and the escape character must be character strings,
// and the result has the type of the value as a CHARACTER VARYING.
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 7
fn (e RegularExpressionSubstringFunction) compile(mut c Compiler) !CompileResult {
	compiled_value, compiled_pattern, compiled_escape := c.with_similar_substring_types(e.value.compile(mut c)!,
		e.pattern.compile(mut c)!, e.escape.compile(mut c)!)

	if !compiled_value.typ.typ.is_string() || !compiled_pattern.typ.typ.is_string()
		|| !compiled_escape.typ.typ.is_string() {
		return sqlstate_42883('function does not exist: SUBSTRING(${compiled_value.typ} SIMILAR ${compiled_pattern.typ} ESCAPE ${compiled_escape.typ})')
	}
	typ := varying_string_type('SUBSTRING', compiled_value.typ)!

	return CompileResult{
		run:          fn [compiled_value, compiled_pattern, compiled_escape, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled_value.run(mut conn, data, params)!
			pattern := compiled_pattern.run(mut conn, data, params)!
			escape := compiled_escape.run(mut conn, data, params)!

			// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 6.a.i
			if value.is_null || pattern.is_null || escape.is_null {
				return new_null_value(.is_varchar).with_type(typ)
			}

			// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 6.a.ii
			result, found := similar_substring(value.string_value(), pattern.string_value(),
				escape_character(escape)!)!
			if !found {
				return new_null_value(.is_varchar).with_type(typ)
			}

			return new_varchar_value(result).with_type(typ)
		}
		typ:          typ
		contains_agg: compiled_value.contains_agg || compiled_pattern.contains_agg
			|| compiled_escape.contains_agg
	}
}

// similar_substring returns the part of value that matches the middle of the
// three parts of pattern. found is false if value doesn't match the whole
// pattern.
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 6.a.iii, 6.a.iv and 6.a.iv.1-3
fn similar_substring(value string, pattern string, escape rune) !(string, bool) {
	// The pattern must have exactly two of the escape character followed by a
	// double quote.
	//
	// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 6.a.iii
	// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 6.a.iv
	chars := pattern.runes()
	mut parts := [][]rune{len: 1}
	mut i := 0
	for i < chars.len {
		if chars[i] == escape && i + 1 < chars.len && chars[i + 1] == `"` {
			parts << []rune{}
			i += 2
			continue
		}
		parts[parts.len - 1] << chars[i]
		i++
	}
	if parts.len != 3 {
		return sqlstate_2200c()
	}
	r1, r2, r3 := parts[0].string(), parts[1].string(), parts[2].string()

	// Each part is a <regular expression>, or empty.
	//
	// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 6.a.iv.1
	p1 := parse_similar_pattern(r1, escape)!
	p2 := parse_similar_pattern(r2, escape)!
	p3 := parse_similar_pattern(r3, escape)!

	// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 6.a.iv.2
	if !parse_similar_pattern(r1 + r2 + r3, escape)!.matches(value) {
		return '', false
	}

	// The "(R2R3)" only groups the two parts, so it's the same as R2 || R3,
	// which is also a zero-length pattern when both are empty (a "()" is not a
	// valid <regular expression>).
	p23 := parse_similar_pattern(r2 + r3, escape)!

	// S1 is the shortest start of value that matches R1 where the rest matches
	// R2 || R3, and S3 is the shortest end of the rest that matches R3 where
	// what's before it matches R2. If the parts only match when they are
	// together (such as R1 being "a|b"), nothing is found and it's the same as
	// not matching.
	//
	// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 6.a.iv.3
	s := value.runes()
	for start in 0 .. s.len + 1 {
		if !p1.matches(s[..start].string()) || !p23.matches(s[start..].string()) {
			continue
		}
		s23 := s[start..]
		for end := s23.len; end >= 0; end-- {
			if p3.matches(s23[end..].string()) && p2.matches(s23[..end].string()) {
				return s23[..end].string(), true
			}
		}
	}

	return '', false
}

struct TrimFunction {
	// LEADING, TRAILING or BOTH
	specification string
	// Without a trim character it's a space, or X'00' for a binary string.
	//
	// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 14.a.i.3 and 22.a.i.3
	character ?&CharacterValueExpression
	source    &CharacterValueExpression
}

fn new_trim_function(specification string, character ?CharacterValueExpression, source CharacterValueExpression) TrimFunction {
	mut character_ref := ?&CharacterValueExpression(none)
	if ch := opt_copy(character) {
		character_ref = ref_character_value_expression(ch)
	}

	return TrimFunction{specification, character_ref, heap_copy(&source)}
}

fn (e TrimFunction) pstr(params map[string]Value) string {
	if character := opt_copy(e.character) {
		return 'TRIM(${e.specification} ${character.pstr(params)} FROM ${e.source.pstr(params)})'
	}

	return 'TRIM(${e.specification} FROM ${e.source.pstr(params)})'
}

fn (e TrimFunction) compile(mut c Compiler) !CompileResult {
	// A pointer to a copy is captured instead of the value to work around
	// https://github.com/vlang/v/issues/32934 (-autofree).
	e_ref := &TrimFunction{
		...e
	}
	compiled_source := e.source.compile(mut c)!
	is_binary := compiled_source.typ.typ.is_binary_string()
	compiled_character := if character := opt_copy(e.character) {
		character.compile(mut c)!
	} else if is_binary {
		ValueSpecification(new_binary_value([u8(0)])).compile(mut c)!
	} else {
		ValueSpecification(new_varchar_value(' ')).compile(mut c)!
	}

	if is_binary {
		return e.compile_binary(mut c, compiled_source, compiled_character)
	}

	// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 14
	typ := varying_string_type('TRIM', compiled_source.typ)!
	c.flag_clob_function(typ)

	// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 14.c
	if !compiled_character.typ.typ.is_string() {
		return sqlstate_42883('function does not exist: TRIM(${compiled_character.typ} FROM ${compiled_source.typ})')
	}

	return CompileResult{
		run:          fn [e_ref, compiled_source, compiled_character, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			source := compiled_source.run(mut conn, data, params)!
			character := compiled_character.run(mut conn, data, params)!

			// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 12.c
			if source.is_null || character.is_null {
				return new_null_value(.is_varchar).with_type(typ)
			}

			// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 12.d
			trim_character := character.string_value().runes()
			if trim_character.len != 1 {
				return sqlstate_22027()
			}

			// Compare whole characters rather than using V's trim functions
			// which work on bytes and could split a multibyte character.
			chars := source.string_value().runes()
			mut start := 0
			mut end := chars.len
			if e_ref.specification != 'TRAILING' {
				for start < end && chars[start] == trim_character[0] {
					start++
				}
			}
			if e_ref.specification != 'LEADING' {
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

// compile_binary is a <binary trim function>, which is a <binary value
// function> (Feature T022). The trim octet must be a binary string. It needs
// Feature T047 for a BINARY LARGE OBJECT.
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, Conformance Rules, 5 and 18
fn (e TrimFunction) compile_binary(mut c Compiler, compiled_source CompileResult, compiled_octet CompileResult) !CompileResult {
	// A pointer to a copy is captured instead of the value to work around
	// https://github.com/vlang/v/issues/32934 (-autofree).
	compiled_octet_ref := &CompileResult{
		...compiled_octet
	}
	compiled_source_ref := &CompileResult{
		...compiled_source
	}
	e_ref := &TrimFunction{
		...e
	}
	// The <trim octet> is a <binary value expression>.
	//
	// ISO/IEC 9075-2:2023, 6.33, <string value function>, Format
	if !compiled_octet.typ.typ.is_binary_string() {
		return sqlstate_42883('function does not exist: TRIM(${compiled_octet.typ} FROM ${compiled_source.typ})')
	}

	// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 22.b
	typ := binary_value_function_type(compiled_source.typ)
	c.flag_binary_value_function(typ)

	return CompileResult{
		run:          fn [e_ref, compiled_source_ref, compiled_octet_ref, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			source := compiled_source_ref.run(mut conn, data, params)!
			octet := compiled_octet_ref.run(mut conn, data, params)!

			// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 18.c
			if source.is_null || octet.is_null {
				return new_null_value(typ.typ).with_type(typ)
			}

			// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 18.d
			trim_octet := octet.string_value()
			if trim_octet.len != 1 {
				return sqlstate_22027()
			}

			// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 18.e
			s := source.string_value()
			mut start := 0
			mut end := s.len
			if e_ref.specification != 'TRAILING' {
				for start < end && s[start] == trim_octet[0] {
					start++
				}
			}
			if e_ref.specification != 'LEADING' {
				for end > start && s[end - 1] == trim_octet[0] {
					end--
				}
			}

			return new_binary_string_value(typ.typ, s[start..end]).with_type(typ)
		}
		typ:          typ
		contains_agg: compiled_source.contains_agg || compiled_octet.contains_agg
	}
}

// varying_string_type is the declared type of SUBSTRING and TRIM, which is a
// CHARACTER VARYING with the (maximum) length of the source string, or a
// CHARACTER LARGE OBJECT of the same maximum length if the source is one.
//
// ISO/IEC 9075-2:2023, 4.3.3.4, Operations involving large object character strings
// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 4.a, 7.b and 14.b
fn varying_string_type(function_name string, source Type) !Type {
	if !source.typ.is_string() {
		return sqlstate_42883('function does not exist: ${function_name}(${source})')
	}

	if source.typ == .is_clob {
		return Type{.is_clob, source.size, 0, false, false}
	}

	return new_type('CHARACTER VARYING', source.size, 0)
}

// MultiCharacterTrimFunction is BTRIM, LTRIM or RTRIM. Unlike TRIM, the trim
// character is a set of characters, any of which are removed. Without one, it's
// a space.
struct MultiCharacterTrimFunction {
	// BTRIM, LTRIM or RTRIM
	name      string
	source    &CharacterValueExpression
	character ?&CharacterValueExpression
}

fn new_multi_character_trim_function(name string, source CharacterValueExpression, character ?CharacterValueExpression) MultiCharacterTrimFunction {
	return MultiCharacterTrimFunction{name.to_upper(), heap_copy(&source), if c := opt_copy(character) {
		heap_copy(&c)
	} else {
		none
	}}
}

fn (e MultiCharacterTrimFunction) pstr(params map[string]Value) string {
	if character := opt_copy(e.character) {
		return '${e.name}(${e.source.pstr(params)}, ${character.pstr(params)})'
	}

	return '${e.name}(${e.source.pstr(params)})'
}

// compile gives the result a CHARACTER VARYING with the (maximum) length of
// the source. BTRIM(s, c) is RTRIM(LTRIM(s, c), c), but the trim character is
// only evaluated once.
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 15
// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 13
fn (e MultiCharacterTrimFunction) compile(mut c Compiler) !CompileResult {
	compiled_source := e.source.compile(mut c)!
	typ := varying_string_type(e.name, compiled_source.typ)!
	mut compiled_character := ?CompileResult(none)
	if character := opt_copy(e.character) {
		compiled := character.compile(mut c)!
		// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 15.b.i.1
		if !compiled.typ.typ.is_string() {
			return sqlstate_42883('function does not exist: ${e.name}(${compiled_source.typ}, ${compiled.typ})')
		}
		compiled_character = compiled
	}
	contains_agg := compiled_source.contains_agg || if compiled := opt_copy(compiled_character) {
		compiled.contains_agg
	} else {
		false
	}

	// The copy works around https://github.com/vlang/v/issues/32934 (-autofree):
	// the closure below frees it.
	name := own_string(e.name)
	return CompileResult{
		run:          fn [name, compiled_source, compiled_character, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			source := compiled_source.run(mut conn, data, params)!
			mut set := [` `]
			if compiled := opt_copy(compiled_character) {
				character := compiled.run(mut conn, data, params)!
				// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 13.c
				if character.is_null {
					return new_null_value(.is_varchar).with_type(typ)
				}
				set = character.string_value().runes()
			}
			if source.is_null {
				return new_null_value(.is_varchar).with_type(typ)
			}

			// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 13.d
			chars := source.string_value().runes()
			if chars.len == 0 || set.len == 0 {
				return source.with_type(typ)
			}

			// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 13.e
			mut start := 0
			mut end := chars.len
			if name != 'RTRIM' {
				for start < end && chars[start] in set {
					start++
				}
			}
			if name != 'LTRIM' {
				for end > start && chars[end - 1] in set {
					end--
				}
			}

			return new_varchar_value(chars[start..end].string()).with_type(typ)
		}
		typ:          typ
		contains_agg: contains_agg
	}
}

// PadFunction is LPAD or RPAD, which pads (or truncates) a string to a number
// of characters. Without a padding string, it's a space.
struct PadFunction {
	// LPAD or RPAD
	name    string
	source  &CharacterValueExpression
	length  &NumericValueExpression
	padding ?&CharacterValueExpression
}

fn new_pad_function(name string, source CharacterValueExpression, length NumericValueExpression, padding ?CharacterValueExpression) PadFunction {
	return PadFunction{name.to_upper(), heap_copy(&source), heap_copy(&length), if p := opt_copy(padding) {
		heap_copy(&p)
	} else {
		none
	}}
}

fn (e PadFunction) pstr(params map[string]Value) string {
	if padding := opt_copy(e.padding) {
		return '${e.name}(${e.source.pstr(params)}, ${e.length.pstr(params)}, ${padding.pstr(params)})'
	}

	return '${e.name}(${e.source.pstr(params)}, ${e.length.pstr(params)})'
}

// compile gives the result a CHARACTER VARYING of the maximum length (LR is
// implementation-defined), which is also the longest result. The length must
// be an exact number with a scale of 0. A longer string is cut to the length,
// from the end for both LPAD and RPAD, and a length less than 1 is the empty
// string. The padding string is repeated, and the last one is cut short to fit.
// An empty padding string pads nothing.
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 16
// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 14
fn (e PadFunction) compile(mut c Compiler) !CompileResult {
	compiled_source := e.source.compile(mut c)!
	compiled_length := e.length.compile(mut c)!
	mut compiled_padding := ?CompileResult(none)
	if padding := opt_copy(e.padding) {
		compiled_padding = padding.compile(mut c)!
	}

	mut signature := '${compiled_source.typ}, ${compiled_length.typ}'
	if compiled := opt_copy(compiled_padding) {
		signature += ', ${compiled.typ}'
	}
	if !compiled_source.typ.typ.is_string()
		|| compiled_length.typ.typ !in [.is_smallint, .is_integer, .is_bigint, .is_decimal,
			.is_numeric]
		|| compiled_length.typ.scale != 0 || if compiled := opt_copy(compiled_padding) {
		!compiled.typ.typ.is_string()
	} else {
		false
	} {
		return sqlstate_42883('function does not exist: ${e.name}(${signature})')
	}

	typ := new_type('CHARACTER VARYING', max_character_length, 0)
	contains_agg := compiled_source.contains_agg || compiled_length.contains_agg || if compiled := opt_copy(compiled_padding) {
		compiled.contains_agg
	} else {
		false
	}

	left := e.name == 'LPAD'
	return CompileResult{
		run:          fn [left, compiled_source, compiled_length, compiled_padding, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			source := compiled_source.run(mut conn, data, params)!
			length := compiled_length.run(mut conn, data, params)!
			mut padding := [` `]
			mut padding_is_null := false
			if compiled := opt_copy(compiled_padding) {
				value := compiled.run(mut conn, data, params)!
				padding_is_null = value.is_null
				padding = value.string_value().runes()
			}

			// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 14.a to 14.d
			if source.is_null || length.is_null {
				return new_null_value(.is_varchar).with_type(typ)
			}
			total := if length.typ.typ in [.is_decimal, .is_numeric]
				&& length.numeric_value().f64() > max_character_length {
				i64(max_character_length)
			} else {
				length.as_int()
			}
			if total < 1 {
				return new_varchar_value('').with_type(typ)
			}
			if padding_is_null {
				return new_null_value(.is_varchar).with_type(typ)
			}

			// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 14.e to 14.j
			chars := source.string_value().runes()
			result_length := int(math.min(total, i64(max_character_length)))
			if result_length <= chars.len {
				return new_varchar_value(chars[..result_length].string()).with_type(typ)
			}
			if padding.len == 0 {
				return source.with_type(typ)
			}

			// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 14.k to 14.o
			mut pad := []rune{cap: result_length - chars.len}
			for pad.len < result_length - chars.len {
				pad << padding[pad.len % padding.len]
			}
			result := if left {
				pad.string() + chars.string()
			} else {
				chars.string() + pad.string()
			}

			return new_varchar_value(result).with_type(typ)
		}
		typ:          typ
		contains_agg: contains_agg
	}
}

// flag_clob_function flags a <character substring function> or <trim source>
// of a CHARACTER LARGE OBJECT (T050).
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, Conformance Rules, 17
fn (mut c Compiler) flag_clob_function(typ Type) {
	if c.conn.flagging && typ.typ == .is_clob {
		c.conn.flag('T050')
	}
}

// register_string_value_funcs registers LOWER and UPPER. Of a CHARACTER LARGE
// OBJECT they're Feature T050.
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, Conformance Rules, 17
fn register_string_value_funcs(mut conn Connection) ! {
	varchar := Type{SQLType.is_varchar, 0, 0, false, false}
	clob := Type{SQLType.is_clob, 0, 0, false, false}

	conn.register_func(Func{'LOWER', [clob], false, func_lower, clob, false, true, ['T050'], [], false})!
	conn.register_func(Func{'UPPER', [clob], false, func_upper, clob, false, true, ['T050'], [], false})!
	conn.register_func(Func{'LOWER', [varchar], false, func_lower, varchar, false, true, [], [], false})!
	conn.register_func(Func{'UPPER', [varchar], false, func_upper, varchar, false, true, [], [], false})!
}
