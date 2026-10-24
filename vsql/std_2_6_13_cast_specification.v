module vsql

import strings

// ISO/IEC 9075-2:2016(E), 6.13, <cast specification>
//
// Specify a data conversion.

type CastOperand = NullSpecification | ValueExpression

fn (e CastOperand) pstr(params map[string]Value) string {
	return match e {
		ValueExpression, NullSpecification {
			e.pstr(params)
		}
	}
}

fn (e CastOperand) compile(mut c Compiler) !CompileResult {
	match e {
		ValueExpression, NullSpecification {
			return e.compile(mut c)!
		}
	}
}

// expr is a reference because a CastOperand can contain a CastSpecification,
// and V stores a sum type's value inline.
struct CastSpecification {
	expr   &CastOperand
	target Type
}

fn new_cast_specification(expr CastOperand, target Type) CastSpecification {
	return CastSpecification{&expr, target}
}

fn (e CastSpecification) pstr(params map[string]Value) string {
	return 'CAST(${e.expr.pstr(params)} AS ${e.target})'
}

fn (e CastSpecification) compile(mut c Compiler) !CompileResult {
	check_data_type(e.target)!

	// CAST(NULL AS T) is the null value of type T (General Rule 2). The NULL has
	// no type of its own to cast from.
	if e.expr is NullSpecification {
		return CompileResult{
			run:          fn [e] (mut conn Connection, data Row, params map[string]Value) !Value {
				return Value{
					typ:     e.target
					is_null: true
				}
			}
			typ:          e.target
			contains_agg: false
		}
	}

	compiled_expr := e.expr.compile(mut c)!

	// A datetime without a time zone gets the time zone of the session, and a
	// TIME becomes a TIMESTAMP on the CURRENT_DATE (General Rules 18 and 19).
	//
	// ISO/IEC 9075-2:2016(E), 6.28, <value expression>, Syntax Rule 7c
	from := compiled_expr.typ
	if (e.target.has_time_zone() && !from.has_time_zone())
		|| (from.typ in [.is_time_with_time_zone, .is_time_without_time_zone]
			&& e.target.typ in [.is_timestamp_with_time_zone, .is_timestamp_without_time_zone]) {
		c.check_deterministic('CAST from ${from} to ${e.target}')!
	}

	return CompileResult{
		run:          fn [e, compiled_expr] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled_expr.run(mut conn, data, params)!

			if !value.is_null && value.typ.uses_string() && e.target.uses_time() {
				return cast_string_to_datetime(mut conn, value, e.target)!
			}

			if !value.is_null && value.typ.typ.is_string() && e.target.typ.is_string() {
				return cast_character_to_character(mut conn, value, e.target)
			}

			if !value.is_null && value.typ.typ.is_string() && e.target.typ == .is_boolean {
				return cast_character_to_boolean(value)!
			}

			if !value.is_null && value.typ.typ == .is_boolean && e.target.typ.is_string() {
				return cast_boolean_to_character(mut conn, value, e.target)!
			}

			mut result := cast(mut conn, 'for CAST', value, e.target)!

			// The declared type of a CAST is the target type (Syntax Rule 2), even
			// if the value is shorter.
			if e.target.typ.is_string() {
				result.typ = e.target
			}

			return result
		}
		typ:          e.target
		contains_agg: compiled_expr.contains_agg
	}
}

// cast_character_to_character casts a character string to CHAR(n) or
// VARCHAR(n). Unlike a store assignment, a string that's too long is truncated
// with a warning (01004) rather than an error, if the characters removed aren't
// all spaces.
//
// ISO/IEC 9075-2:2016(E), 6.13, <cast specification>, General Rules 11 and 12
fn cast_character_to_character(mut conn Connection, v Value, to Type) Value {
	mut s := v.string_value()
	chars := s.runes()
	if chars.len > to.size {
		if !chars[to.size..].all(it == ` `) {
			conn.add_warning(sqlstate_01004())
		}
		s = chars[..to.size].string()
	}

	if to.typ == .is_character && chars.len < to.size {
		s += strings.repeat(` `, to.size - chars.len)
	}

	return Value{
		typ: to
		v:   InternalValue{
			string_value: s
		}
	}
}

// cast_character_to_boolean casts a character string to a BOOLEAN. Leading and
// trailing spaces are ignored, then the string must be a <boolean literal>
// (TRUE, FALSE or UNKNOWN, in any case). UNKNOWN is the null value.
//
// ISO/IEC 9075-2:2016(E), 6.13, <cast specification>, General Rule 21a
fn cast_character_to_boolean(v Value) !Value {
	return match v.string_value().trim(' ').to_upper_ascii() {
		'TRUE' { new_boolean_value(true) }
		'FALSE' { new_boolean_value(false) }
		'UNKNOWN' { new_unknown_value() }
		else { return sqlstate_22018() }
	}
}

// cast_boolean_to_character casts a BOOLEAN to 'TRUE' or 'FALSE'. Unlike other
// strings, it's an error (22018) if the target is too short, rather than being
// truncated.
//
// ISO/IEC 9075-2:2016(E), 6.13, <cast specification>, General Rules 11f and 12f
fn cast_boolean_to_character(mut conn Connection, v Value, to Type) !Value {
	s := if v.bool_value() == .is_true { 'TRUE' } else { 'FALSE' }
	if s.len > to.size {
		return sqlstate_22018()
	}

	return cast_character_to_character(mut conn, new_varchar_value(s), to)
}

// cast_string_to_datetime converts a character string to a DATE, TIME or
// TIMESTAMP. Leading and trailing spaces are ignored, then the string must be a
// valid unquoted datetime string (such as "2022-06-30") for the target type. A
// time zone is added or removed in the same way as casting between the datetime
// types.
//
// ISO/IEC 9075-2:2016(E), 6.13, <cast specification>, General Rules, 14a, 16a,
// 17a, 18a and 19a
fn cast_string_to_datetime(mut conn Connection, v Value, to Type) !Value {
	s := v.string_value().trim(' ')
	value := match to.typ {
		.is_date {
			new_date_value(s) or { return sqlstate_22007() }
		}
		.is_time_with_time_zone, .is_time_without_time_zone {
			new_time_value(s) or { return sqlstate_22007() }
		}
		else {
			new_timestamp_value(s) or { return sqlstate_22007() }
		}
	}

	return cast(mut conn, 'for CAST', value, to)!
}
