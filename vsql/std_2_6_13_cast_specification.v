module vsql

import strings

// ISO/IEC 9075-2:2023, 6.13, <cast specification>
//
// Specify a data conversion.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2023, 4.13, Data conversions

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
	// template is the <cast template> (FORMAT) of a cast between a datetime and
	// a character string (T839).
	template ?DatetimeTemplate
}

fn new_cast_specification(expr CastOperand, target Type) CastSpecification {
	return CastSpecification{
		expr:   &expr
		target: target
	}
}

fn (e CastSpecification) pstr(params map[string]Value) string {
	if template := e.template {
		return 'CAST(${e.expr.pstr(params)} AS ${e.target} FORMAT ${template})'
	}

	return 'CAST(${e.expr.pstr(params)} AS ${e.target})'
}

fn (e CastSpecification) compile(mut c Compiler) !CompileResult {
	check_data_type(e.target)!

	if template := e.template {
		return e.compile_template(mut c, template)
	}

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

	// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.xv
	compiled_expr := c.with_type(e.expr.compile(mut c)!, e.target)

	// Whether the types can be cast is a Syntax Rule, so it's checked here
	// rather than when a value is cast, even if every value is the null value.
	// A dynamic parameter that's the null value has no declared type of its own.
	if !compiled_expr.null_parameter {
		check_cast(compiled_expr.typ, e.target)!
	}

	// ISO/IEC 9075-2:2023, 6.13, <cast specification>, Conformance Rules, 1 and 3
	if c.conn.flagging && compiled_expr.typ.typ.is_lob() {
		c.conn.flag('T042')
	}

	// A datetime without a time zone gets the time zone of the session, and a
	// TIME becomes a TIMESTAMP on the CURRENT_DATE (General Rules 18 and 19).
	//
	// ISO/IEC 9075-2:2023, 9.16, Potential sources of non-determinism, Syntax Rules, 1.d
	from := compiled_expr.typ
	if (e.target.has_time_zone() && !from.has_time_zone())
		|| (from.typ in [.is_time_with_time_zone, .is_time_without_time_zone]
			&& e.target.typ in [.is_timestamp_with_time_zone, .is_timestamp_without_time_zone]) {
		c.check_deterministic('CAST from ${from} to ${e.target}')!
	}

	return CompileResult{
		run:          fn [e, compiled_expr] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled_expr.run(mut conn, data, params)!

			return cast_specification(mut conn, value, e.target)
		}
		typ:          e.target
		contains_agg: compiled_expr.contains_agg
		// A string target isn't constant, see fold.
		constant:     compiled_expr.constant && !e.target.typ.is_string()
	}.fold()
}

// compile_template compiles a CAST with a <cast template> (FORMAT), which can
// only cast a datetime to a character string, or a character string to a
// datetime. A dynamic parameter that's cast to a datetime is the longest
// character string, so that a value that's too long doesn't match the template
// (rather than being truncated to fit it).
//
// ISO/IEC 9075-2:2023, 6.13, <cast specification>, Syntax Rules, 4
// ISO/IEC 9075-2:2023, 6.13, <cast specification>, General Rules, 11.e.i.1, 12.e.i.1, 14.a.i, 16.a.i, 17.a.i, 18.a.i and 19.a.i
fn (e CastSpecification) compile_template(mut c Compiler, template DatetimeTemplate) !CompileResult {
	if e.expr is NullSpecification {
		return sqlstate_42601('NULL cannot be cast with a FORMAT')
	}

	mut compiled_expr := e.expr.compile(mut c)!
	if e.target.uses_time() {
		compiled_expr = c.with_type(compiled_expr, Type{
			typ:  .is_varchar
			size: max_character_length
		})
	}

	from := compiled_expr.typ
	to := e.target
	if from.uses_time() && to.typ.is_string() {
		template.check_format_target(from, to)!
	} else if from.typ.is_string() && to.uses_time() {
		template.check_parse_source(from, to)!
		if !template.is_deterministic(to) {
			c.check_deterministic('CAST with a FORMAT that uses the current date')!
		}
	} else {
		return sqlstate_42601('CAST from ${from} to ${to} cannot have a FORMAT')
	}

	return CompileResult{
		run:          fn [e, compiled_expr, template] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled_expr.run(mut conn, data, params)!
			if value.is_null {
				return Value{
					typ:     e.target
					is_null: true
				}
			}

			if e.target.uses_time() {
				return template.parse_datetime(mut conn, value.string_value(), e.target)!
			}

			return formatted_character_value(template.format_datetime(value.time_value()),
				e.target)!
		}
		typ:          e.target
		contains_agg: compiled_expr.contains_agg
	}
}

// formatted_character_value is the formatted string s as the character string
// type to: a CHAR is padded with spaces, and a string that's too long is an
// error (rather than being truncated with a warning).
//
// ISO/IEC 9075-2:2023, 6.13, <cast specification>, General Rules, 11.e.ii and 12.e.ii
fn formatted_character_value(s string, to Type) !Value {
	if s.len > to.size {
		return sqlstate_22001(to)
	}

	return Value{
		...new_character_value(if to.typ == .is_character {
			s + ' '.repeat(to.size - s.len)
		} else {
			s
		})
		typ: to
	}
}

// cast is CAST ( v AS target ), see the General Rules of 6.13, <cast
// specification>. Unlike store_assignment, a string can be cast to a number or
// datetime, and a string that's too long is truncated with a warning.
pub fn (mut conn Connection) cast(value Value, target Type) !Value {
	check_data_type(target)!
	// This isn't part of a statement, so it has its own statement timestamp
	// (for the date of a TIME that's cast to a TIMESTAMP).
	conn.set_statement_timestamp()

	return cast_specification(mut conn, value, target)
}

// cast_specification is CAST ( value AS target ) for a target that has already
// been checked.
fn cast_specification(mut conn Connection, value Value, target Type) !Value {
	if value.is_null {
		return Value{
			typ:     target
			is_null: true
		}
	}

	if value.typ.typ.is_string() && target.uses_time() {
		return cast_string_to_datetime(mut conn, value, target)!
	}

	if value.typ.typ.is_string() && target.typ.is_string() {
		return cast_character_to_character(mut conn, value, target)
	}

	if value.typ.typ.is_binary_string() && target.typ.is_binary_string() {
		return cast_binary_to_binary(mut conn, value, target)!
	}

	if value.typ.typ.is_string() && target.typ == .is_decfloat {
		return cast_character_to_decfloat(value, target)!
	}

	if value.typ.typ.is_string() && target.typ == .is_boolean {
		return cast_character_to_boolean(value)!
	}

	if value.typ.typ == .is_boolean && target.typ.is_string() {
		return cast_boolean_to_character(mut conn, value, target)!
	}

	if value.typ.typ.is_string() && target.typ.is_interval() {
		return cast_character_to_interval(value, target)!
	}

	if value.typ.typ in exact_numeric_types && target.typ.is_interval() {
		return cast_exact_numeric_to_interval(value, target)!
	}

	if value.typ.typ.is_interval() && target.typ in exact_numeric_types {
		return cast(mut conn, 'for CAST', cast_interval_to_exact_numeric(value), target)!
	}

	result := cast(mut conn, 'for CAST', value, target)!

	// The declared type of a CAST is the target type (Syntax Rule 2), even if
	// the value is shorter.
	if target.typ.is_string() {
		return Value{
			...result
			typ: target
		}
	}

	return result
}

// CastKind is the kind of a type in the table of the types that can be cast
// to each other.
enum CastKind {
	number
	character
	date
	time
	timestamp
	boolean
	binary
	interval_year_month
	interval_day_time
}

fn cast_kind(t SQLType) CastKind {
	return match t {
		.is_character, .is_varchar, .is_clob { .character }
		.is_binary, .is_varbinary, .is_blob { .binary }
		.is_interval_year_month { .interval_year_month }
		.is_interval_day_time { .interval_day_time }
		.is_date { .date }
		.is_time_with_time_zone, .is_time_without_time_zone { .time }
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone { .timestamp }
		.is_boolean { .boolean }
		else { .number }
	}
}

// check_cast returns 42846 if a value of type from can never be cast to type
// to. Any type can be cast to and from a character string, or to its own kind
// of type. Otherwise only a DATE and a TIME can be cast to a TIMESTAMP, and a
// TIMESTAMP to a DATE or a TIME.
//
// ISO/IEC 9075-2:2023, 6.13, <cast specification>, Syntax Rules, 7
fn check_cast(from Type, to Type) ! {
	from_kind := cast_kind(from.typ)
	to_kind := cast_kind(to.typ)

	// An interval can be cast to and from a character string, and to and from an
	// exact numeric when it has only one field (Syntax Rules 8 and 9).
	intervals := [CastKind.interval_year_month, .interval_day_time]
	if (from_kind in intervals && to.typ in exact_numeric_types
		&& from.interval_qualifier().start == from.interval_qualifier().end)
		|| (to_kind in intervals && from.typ in exact_numeric_types
			&& to.interval_qualifier().start == to.interval_qualifier().end)
		|| (from_kind in intervals && to_kind == .character)
		|| (to_kind in intervals && from_kind == .character) {
		return
	}

	// A binary string or an interval can only be cast to its own kind of type,
	// and a DECFLOAT can only be cast to or from a number or a character string,
	// until the other casts are supported.
	if from_kind in [.binary, .interval_year_month, .interval_day_time]
		|| to_kind in [.binary, .interval_year_month, .interval_day_time] {
		if from_kind == to_kind {
			return
		}

		return sqlstate_42846(from, to)
	}

	if from_kind == to_kind || from_kind == .character || to_kind == .character
		|| (from_kind in [.date, .time] && to_kind == .timestamp)
		|| (from_kind == .timestamp && to_kind in [.date, .time]) {
		return
	}

	return sqlstate_42846(from, to)
}

// cast_character_to_character casts a character string to CHAR(n) or
// VARCHAR(n). Unlike a store assignment, a string that's too long is truncated
// with a warning (01004) rather than an error, if the characters removed aren't
// all <truncating whitespace>.
//
// ISO/IEC 9075-2:2023, 6.13, <cast specification>, General Rules, 11 and 12
fn cast_character_to_character(mut conn Connection, v Value, to Type) Value {
	mut s := v.string_value()
	if to.octets {
		return cast_character_to_octets(mut conn, s, to)
	}
	chars := s.runes()
	if to.size > 0 && chars.len > to.size {
		if !chars[to.size..].all(is_truncating_whitespace(it)) {
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

// cast_character_to_octets casts a character string to CHAR(n OCTETS) or
// VARCHAR(n OCTETS), which is the same as for a length in characters, except
// that the length is in octets (UTF-8 bytes). A string that's too long is cut
// to the last whole character that fits, and a CHARACTER is padded with spaces
// to n octets (so a cut character becomes spaces).
//
// ISO/IEC 9075-2:2023, 6.1, <data type>, Syntax Rules, 16.b.i and 16.b.ii
// ISO/IEC 9075-2:2023, 6.13, <cast specification>, General Rules, 11 and 12
fn cast_character_to_octets(mut conn Connection, s string, to Type) Value {
	mut result := s
	if s.len > to.size {
		mut end := to.size
		for end > 0 && (s[end] & 0xC0) == 0x80 {
			end--
		}
		if !s[end..].bytes().all(it == ` `) {
			conn.add_warning(sqlstate_01004())
		}
		result = s[..end]
	}
	if to.typ == .is_character && result.len < to.size {
		result += strings.repeat(` `, to.size - result.len)
	}

	return Value{
		typ: to
		v:   InternalValue{
			string_value: result
		}
	}
}

// cast_binary_to_binary casts a binary string to BINARY(n), BINARY VARYING(n)
// or BINARY LARGE OBJECT(n). Unlike a store assignment, a value that's too long
// is truncated with a warning (01004), even if the octets removed are X'00'. A
// BINARY is padded with X'00'. A large value that fits is kept as it is, so it
// isn't read.
//
// ISO/IEC 9075-2:2023, 6.13, <cast specification>, General Rules, 13
fn cast_binary_to_binary(mut conn Connection, v Value, to Type) !Value {
	length := binary_length(to)
	octets := v.octet_length()
	if v.is_large && to.typ == .is_blob && octets <= length {
		return v.with_type(to)
	}

	mut s := v.string_value()

	// ISO/IEC 9075-2:2023, 6.13, <cast specification>, General Rules, 13.a.ii and 13.b.ii
	if octets > length {
		conn.add_warning(sqlstate_01004())
		s = s[..length]
	}

	// ISO/IEC 9075-2:2023, 6.13, <cast specification>, General Rules, 13.a.iii
	if to.typ == .is_binary && s.len < length {
		s += strings.repeat(0, length - s.len)
	}

	return new_binary_string_value(to.typ, s).with_type(to)
}

// cast_character_to_decfloat casts a character string to a DECFLOAT. Leading
// and trailing <truncating whitespace> is removed, and what's left must be a
// <signed numeric literal>, which is rounded to the precision of the DECFLOAT.
// Unlike other numbers, an approximate numeric literal keeps all of its digits.
//
// ISO/IEC 9075-2:2023, 6.13, <cast specification>, General Rules, 10.b
fn cast_character_to_decfloat(v Value, to Type) !Value {
	s := trim_truncating_whitespace(v.string_value())
	if numeric_literal_kind(s) == .invalid {
		return sqlstate_22018()
	}

	return new_decfloat_value(to, new_decfloat_from_string(s.trim_left('+'), to.size)!)
}

// cast_character_to_boolean casts a character string to a BOOLEAN. Leading and
// trailing spaces are ignored, then the string must be a <boolean literal>
// (TRUE, FALSE or UNKNOWN, in any case). UNKNOWN is the null value.
//
// ISO/IEC 9075-2:2023, 6.13, <cast specification>, General Rules, 21.a
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
// ISO/IEC 9075-2:2023, 6.13, <cast specification>, General Rules, 11.f and 12.f
fn cast_boolean_to_character(mut conn Connection, v Value, to Type) !Value {
	s := if v.bool_value() == .is_true { 'TRUE' } else { 'FALSE' }
	if to.size > 0 && s.len > to.size {
		return sqlstate_22018()
	}

	return cast_character_to_character(mut conn, new_varchar_value(s), to)
}

// cast_string_to_datetime converts a character string to a DATE, TIME or
// TIMESTAMP. Leading and trailing spaces are ignored, then the string must be a
// valid unquoted datetime string (such as "2022-06-30") or a datetime literal
// (such as "DATE '2022-06-30'") for the target type. A time zone is added or
// removed in the same way as casting between the datetime types. A time zone
// that's out of range is an invalid time zone displacement value (22009) rather
// than an invalid datetime format (22007).
//
// ISO/IEC 9075-2:2023, 6.1, <data type>, General Rules, 8
// ISO/IEC 9075-2:2023, 6.13, <cast specification>, General Rules, 14.a, 16.a,
// 17.a, 18.a and 19.a
fn cast_string_to_datetime(mut conn Connection, v Value, to Type) !Value {
	s := v.string_value().trim(' ')
	if to.typ != .is_date {
		keyword := if to.typ in [.is_time_with_time_zone, .is_time_without_time_zone] {
			'TIME'
		} else {
			'TIMESTAMP'
		}
		unquoted := unquote_datetime_literal(s, keyword)
		if has_time_zone(unquoted) {
			time_zone_displacement(unquoted)!
		}
	}
	value := match to.typ {
		.is_date {
			new_date_value(unquote_datetime_literal(s, 'DATE')) or { return sqlstate_22007() }
		}
		.is_time_with_time_zone, .is_time_without_time_zone {
			new_time_value(unquote_datetime_literal(s, 'TIME')) or { return sqlstate_22007() }
		}
		else {
			new_timestamp_value(unquote_datetime_literal(s, 'TIMESTAMP')) or {
				return sqlstate_22007()
			}
		}
	}

	return cast(mut conn, 'for CAST', value, to)!
}

// unquote_datetime_literal returns the datetime string of a datetime literal
// (such as "2022-06-30" from "DATE '2022-06-30'") if s is a literal that starts
// with keyword. Otherwise s is returned unchanged, to be checked as an unquoted
// datetime string. The keyword must be the one for the target type, so a DATE
// literal can't be cast to a TIMESTAMP.
//
// ISO/IEC 9075-2:2023, 5.3, <literal>, Format
fn unquote_datetime_literal(s string, keyword string) string {
	if s.len < keyword.len || s[..keyword.len].to_upper() != keyword {
		return s
	}

	// Any white space can separate the keyword and the string, but a comment
	// can't, since it's a string rather than SQL.
	rest := s[keyword.len..].runes()
	mut start := 0
	for start < rest.len && is_white_space(rest[start]) {
		start++
	}
	quoted := rest[start..].string()
	if quoted.len < 2 || quoted[0] != `'` || quoted[quoted.len - 1] != `'` {
		return s
	}

	// A datetime string never contains a quote, so leaving one in (from a
	// doubled quote) makes it invalid.
	return quoted[1..quoted.len - 1]
}
