// interval.v contains the implementation of the INTERVAL types.

module vsql

import math.big
import strconv

// The concepts are described by:
//
// ISO/IEC 9075-1:2023, 4.6.3.6, Interval types
// ISO/IEC 9075-2:2023, 4.7.3, Intervals
// ISO/IEC 9075-2:2023, 10.1, <interval qualifier>

// IntervalField is a field of an interval, in order of significance. The values
// are part of the Type.size of an interval (see new_interval_type), so they
// must not change.
enum IntervalField {
	year   = 1
	month  = 2
	day    = 3
	hour   = 4
	minute = 5
	second = 6
}

fn (f IntervalField) str() string {
	return match f {
		.year { 'YEAR' }
		.month { 'MONTH' }
		.day { 'DAY' }
		.hour { 'HOUR' }
		.minute { 'MINUTE' }
		.second { 'SECOND' }
	}
}

// micros is the number of microseconds in one of a day-time field.
fn (f IntervalField) micros() i64 {
	return match f {
		.day { 86_400_000_000 }
		.hour { 3_600_000_000 }
		.minute { 60_000_000 }
		.second { 1_000_000 }
		// A year-month field doesn't have a number of microseconds.
		.year, .month { 0 }
	}
}

// default_interval_leading_precision is the <interval leading field precision>
// when it isn't specified.
//
// ISO/IEC 9075-2:2023, 10.1, <interval qualifier>, Syntax Rules, 5
const default_interval_leading_precision = 2

// max_interval_leading_precision is the implementation-defined maximum
// <interval leading field precision>. A day-time interval is a number of
// microseconds in an i64, so 99999999 days (and every smaller field) always
// fits.
//
// ISO/IEC 9075-2:2023, 10.1, <interval qualifier>, Syntax Rules, 3
const max_interval_leading_precision = 8

// default_interval_fractional_precision is the <interval fractional seconds
// precision> when it isn't specified.
//
// ISO/IEC 9075-2:2023, 10.1, <interval qualifier>, Syntax Rules, 6
const default_interval_fractional_precision = 6

// hour_to_minute_type is INTERVAL HOUR TO MINUTE, which is the type of a time
// zone displacement.
const hour_to_minute_type = new_interval_type(IntervalQualifier{.hour, .minute, default_interval_leading_precision, 0})

// IntervalQualifier is the fields and precisions of an interval type.
struct IntervalQualifier {
	start IntervalField
	end   IntervalField
	// leading_precision is the number of digits of the start field.
	leading_precision int
	// fractional_precision is the number of digits after the period of the
	// seconds, if the end field is SECOND.
	fractional_precision int
}

// new_interval_type is the INTERVAL with the qualifier. The size has the start
// field, the end field and the leading precision, and the scale is the
// fractional seconds precision. It's a year-month interval if its fields are
// YEAR or MONTH, otherwise it's a day-time interval, and each value has a
// value for each of its fields.
//
// ISO/IEC 9075-2:2023, 6.1, <data type>, Syntax Rules, 42 and 43
fn new_interval_type(q IntervalQualifier) Type {
	typ := if q.start in [.year, .month] {
		SQLType.is_interval_year_month
	} else {
		SQLType.is_interval_day_time
	}

	return Type{typ, int(q.start) * 1000 + int(q.end) * 100 + q.leading_precision, i16(q.fractional_precision), false, false}
}

// interval_qualifier is the qualifier of an interval type, see
// new_interval_type.
fn (t Type) interval_qualifier() IntervalQualifier {
	return IntervalQualifier{
		start:                unsafe { IntervalField(t.size / 1000) }
		end:                  unsafe { IntervalField(t.size / 100 % 10) }
		leading_precision:    t.size % 100
		fractional_precision: t.scale
	}
}

// str is the <interval qualifier>, such as "DAY(2) TO SECOND(6)".
fn (q IntervalQualifier) str() string {
	if q.start == q.end {
		if q.start == .second {
			return 'SECOND(${q.leading_precision}, ${q.fractional_precision})'
		}

		return '${q.start}(${q.leading_precision})'
	}

	if q.end == .second {
		return '${q.start}(${q.leading_precision}) TO SECOND(${q.fractional_precision})'
	}

	return '${q.start}(${q.leading_precision}) TO ${q.end}'
}

// parse_interval_range is an <interval qualifier> with a <start field> and an
// <end field>. The start field must be more significant than the end field,
// and can't be MONTH. If it's YEAR, the end field must be MONTH.
//
// ISO/IEC 9075-2:2023, 10.1, <interval qualifier>, Syntax Rules, 2
fn parse_interval_range(start IntervalFieldPrecision, end IntervalFieldPrecision) !IntervalQualifier {
	if int(end.field) <= int(start.field) || start.field == .month
		|| (start.field == .year && end.field != .month) {
		return sqlstate_42601('invalid interval qualifier: ${start.field} TO ${end.field}')
	}

	return parse_interval_qualifier(start.field, end.field, start.precision, end.precision)
}

// parse_interval_qualifier checks the precisions of an <interval qualifier>,
// whose fields are already known to be valid. A precision is -1 if it wasn't
// specified.
//
// ISO/IEC 9075-2:2023, 10.1, <interval qualifier>, Syntax Rules, 3-6
fn parse_interval_qualifier(start IntervalField, end IntervalField, leading_precision int, fractional_precision int) !IntervalQualifier {
	// - SR 3 and 5. The leading precision is between 1 and the
	// implementation-defined maximum.
	leading := if leading_precision < 0 {
		default_interval_leading_precision
	} else {
		leading_precision
	}
	if leading < 1 || leading > max_interval_leading_precision {
		return sqlstate_42601('INTERVAL leading field precision must be between 1 and ${max_interval_leading_precision}')
	}

	// - SR 4 and 6. The fractional seconds precision is between 0 and the
	// implementation-defined maximum (the same maximum as a TIME, see
	// check_fractional_seconds_precision).
	fractional := if fractional_precision < 0 {
		default_interval_fractional_precision
	} else {
		fractional_precision
	}
	if fractional > 6 {
		return sqlstate_42601('INTERVAL fractional seconds precision must not be greater than 6')
	}

	return IntervalQualifier{start, end, leading, if end == .second { fractional } else { 0 }}
}

// interval_field_from_string is the IntervalField of a keyword, such as "DAY".
fn interval_field_from_string(s string) IntervalField {
	return match s {
		'YEAR' { .year }
		'MONTH' { .month }
		'DAY' { .day }
		'HOUR' { .hour }
		'MINUTE' { .minute }
		else { .second }
	}
}

// new_interval_value is an interval of the type: a number of months for a
// year-month interval, or a number of microseconds for a day-time interval.
fn new_interval_value(typ Type, x i64) Value {
	return Value{
		typ: typ
		v:   InternalValue{
			int_value: x
		}
	}
}

// new_interval_value_from_string is the value of an <interval literal>. sign is
// the <sign> before the <interval string> ("-" or "+"), if there is one. Two
// signs are multiplied (General Rule 9).
//
// ISO/IEC 9075-2:2023, 5.3, <literal>, Syntax Rules, 38, 41 and 42
// ISO/IEC 9075-2:2023, 5.3, <literal>, General Rules, 9 and 10.b
//
// An <interval literal> or an <interval qualifier> is flagged with F052 (see
// interval_literal and interval_type in the grammar).
//
// ISO/IEC 9075-2:2023, 5.3, <literal>, Conformance Rules, 5
// ISO/IEC 9075-2:2023, 10.1, <interval qualifier>, Conformance Rules, 1
fn new_interval_value_from_string(sign string, s string, q IntervalQualifier) !Value {
	mut str := s.trim_space()
	mut negative := sign == '-'
	if str.starts_with('-') || str.starts_with('+') {
		if str[0] == `-` {
			negative = !negative
		}
		str = str[1..]
	}

	// The separator before each field after the first one, such as "-" before
	// the MONTH of a YEAR TO MONTH.
	mut fields := []IntervalField{}
	for f := int(q.start); f <= int(q.end); f++ {
		fields << unsafe { IntervalField(f) }
	}

	mut values := []i64{}
	mut fraction := ''
	// The copies work around https://github.com/vlang/v/issues/32944
	// (-autofree): reassigning a copy of a string frees the original.
	mut rest := own_string(str)
	for i, f in fields {
		separator := if i + 1 == fields.len {
			''
		} else if f == .year {
			'-'
		} else if f == .day {
			' '
		} else {
			':'
		}

		mut part := own_string(rest)
		if separator != '' {
			if !rest.contains(separator) {
				return invalid_interval_literal(s, q)
			}
			part = rest.all_before(separator)
			rest = rest.all_after_first(separator)
		}

		if f == .second && part.contains('.') {
			fraction = part.all_after('.')
			part = part.all_before('.')
			if !fraction.bytes().all(it.is_digit()) {
				return invalid_interval_literal(s, q)
			}
		}

		if part == '' || !part.bytes().all(it.is_digit()) {
			return invalid_interval_literal(s, q)
		}

		// The leading field can have up to the leading precision digits, and
		// every other field has 2 digits and must be less than the next field
		// up.
		//
		// ISO/IEC 9075-2:2023, 10.1, <interval qualifier>, Syntax Rules, 7
		// ISO/IEC 9075-2:2023, 10.1, <interval qualifier>, General Rules, 2
		if i == 0 {
			if part.trim_left('0').len > q.leading_precision {
				return invalid_interval_literal(s, q)
			}
		} else {
			limit := match f {
				.month { 12 }
				.hour { 24 }
				else { 60 }
			}
			if part.len > 2 || part.int() >= limit {
				return invalid_interval_literal(s, q)
			}
		}

		values << strconv.parse_int(part, 10, 64) or { return invalid_interval_literal(s, q) }
	}

	// Digits of the fraction after the fractional seconds precision are
	// truncated (5.3 General Rule 10.b).
	if fraction.len > q.fractional_precision {
		fraction = fraction[..q.fractional_precision]
	}

	mut x := i64(0)
	if q.start == .year || q.start == .month {
		for i, f in fields {
			x += if f == .year { values[i] * 12 } else { values[i] }
		}
	} else {
		for i, f in fields {
			x += values[i] * f.micros()
		}
		if fraction != '' {
			x += (fraction + '0'.repeat(6 - fraction.len)).i64()
		}
	}

	return new_interval_value(new_interval_type(q), if negative { -x } else { x })
}

// invalid_interval_literal is the error for an <interval string> that doesn't
// match its <interval qualifier>, or has a field that's too big. It's a syntax
// error, like an invalid datetime literal.
//
// ISO/IEC 9075-2:2023, 5.3, <literal>, Syntax Rules, 38 and 41
fn invalid_interval_literal(s string, q IntervalQualifier) IError {
	return sqlstate_42601("INTERVAL '${s}' ${q} is not valid")
}

// interval_string is the <unquoted interval string> of an interval value, such
// as "1-02" for a YEAR TO MONTH or "-3 04:05:06.500000" for a DAY TO SECOND.
fn interval_string(typ Type, x i64) string {
	q := typ.interval_qualifier()
	sign := if x < 0 { '-' } else { '' }
	mut rest := if x < 0 { -x } else { x }

	if typ.typ == .is_interval_year_month {
		if q.start == .month {
			return '${sign}${rest}'
		}
		if q.end == .year {
			return '${sign}${rest / 12}'
		}

		return '${sign}${rest / 12}-${rest % 12:02}'
	}

	// The copy works around https://github.com/vlang/v/issues/32944 (-autofree).
	mut s := own_string(sign)
	for f := int(q.start); f <= int(q.end); f++ {
		field := unsafe { IntervalField(f) }
		n := rest / field.micros()
		rest = rest % field.micros()
		if field == q.start {
			s += '${n}'
		} else {
			s += if field == .hour { ' ' } else { ':' }
			s += '${n:02}'
		}
	}

	if q.end == .second && q.fractional_precision > 0 {
		s += '.' + '${rest:06}'[..q.fractional_precision]
	}

	return s
}

// cast_interval converts an interval to another interval type of the same
// class. The fields after the end field of the target (and the fractional
// seconds after its precision) are truncated, and the leading field must have
// no more digits than the leading precision of the target, otherwise it's 22015
// (interval field overflow).
//
// ISO/IEC 9075-2:2023, 9.2, Store assignment, General Rules, 3.b.xvii
fn cast_interval(v Value, t Type) !Value {
	if v.typ.typ != t.typ {
		return sqlstate_42846(v.typ, t)
	}

	q := t.interval_qualifier()
	x := q.truncate(v.int_value())
	q.check_leading(x)!

	return new_interval_value(t, x)
}

// unit is the value of 1 in the least significant field of the qualifier: a
// number of months for a year-month interval, otherwise a number of
// microseconds. The unit of SECOND is the last digit of its fractional seconds
// precision.
fn (q IntervalQualifier) unit() i64 {
	return match q.end {
		.year {
			12
		}
		.month {
			1
		}
		.second {
			mut u := i64(1)
			for _ in q.fractional_precision .. 6 {
				u *= 10
			}
			u
		}
		else {
			q.end.micros()
		}
	}
}

// truncate removes the fields of x after the end field (and the fractional
// seconds after the fractional seconds precision), towards zero.
fn (q IntervalQualifier) truncate(x i64) i64 {
	unit := q.unit()
	return x / unit * unit
}

// check_leading returns 22015 (interval field overflow) if the start field of x
// has more digits than the leading precision.
fn (q IntervalQualifier) check_leading(x i64) ! {
	leading := match q.start {
		.year { x / 12 }
		.month { x }
		else { x / q.start.micros() }
	}
	if '${if leading < 0 { -leading } else { leading }}'.len > q.leading_precision {
		return sqlstate_22015()
	}
}

// IntervalFieldPrecision is a field of an <interval qualifier> and its
// precision, or -1 if it doesn't have one.
struct IntervalFieldPrecision {
	field     IntervalField
	precision int
}

// cast_character_to_interval is CAST(v AS t) for a character string v. Leading
// and trailing spaces are removed, and the rest must be an <unquoted interval
// string> for the qualifier of t, or an <interval literal> whose value can be
// cast to t (see cast_interval). Otherwise, it's 22006 (invalid interval
// format).
//
// ISO/IEC 9075-2:2023, 6.13, <cast specification>, General Rules, 20.b, 20.b.i and 20.b.ii
fn cast_character_to_interval(v Value, t Type) !Value {
	s := v.string_value().trim(' ')
	if s.to_upper().starts_with('INTERVAL') {
		mut rest := s[8..].trim_left(' ')
		mut sign := ''
		if rest.starts_with('-') || rest.starts_with('+') {
			sign = rest[..1]
			rest = rest[1..].trim_left(' ')
		}
		end := rest.index_after("'", 1) or { -1 }
		if !rest.starts_with("'") || end < 0 {
			return sqlstate_22006()
		}
		q := parse_interval_qualifier_string(rest[end + 1..]) or { return sqlstate_22006() }
		literal := new_interval_value_from_string(sign, rest[1..end], q) or {
			return sqlstate_22006()
		}
		if literal.typ.typ != t.typ {
			return sqlstate_22006()
		}

		return cast_interval(literal, t)!
	}

	return new_interval_value_from_string('', s, t.interval_qualifier()) or {
		return sqlstate_22006()
	}
}

// parse_interval_qualifier_string is the <interval qualifier> s, such as
// "YEAR(3) TO MONTH" or "SECOND(2, 3)", in any case and with any spaces.
fn parse_interval_qualifier_string(s string) ?IntervalQualifier {
	parts := s.to_upper().replace(' ', '').split('TO')
	if parts.len > 2 {
		return none
	}

	start := parse_interval_field_precisions(parts[0])?
	if parts.len == 1 {
		if start.len == 2 && start[0].field != .second {
			return none
		}

		return parse_interval_qualifier(start[0].field, start[0].field, start[0].precision,
			if start.len == 2 { start[1].precision } else { -1 }) or { return none }
	}

	end := parse_interval_field_precisions(parts[1])?
	if start.len != 1 || end.len != 1 || (end[0].precision >= 0 && end[0].field != .second) {
		return none
	}

	return parse_interval_range(start[0], end[0]) or { return none }
}

// parse_interval_field_precisions is a field and its precisions, such as
// "SECOND(2,3)", which is SECOND with each precision (only the first one has the
// field).
fn parse_interval_field_precisions(s string) ?[]IntervalFieldPrecision {
	name := s.all_before('(')
	if name !in ['YEAR', 'MONTH', 'DAY', 'HOUR', 'MINUTE', 'SECOND'] {
		return none
	}
	field := interval_field_from_string(name)
	if !s.contains('(') {
		return [IntervalFieldPrecision{field, -1}]
	}
	if !s.ends_with(')') {
		return none
	}

	precisions := s.all_after('(').trim_right(')').split(',')
	if precisions.len > 2 || precisions.any(it == '' || !it.bytes().all(it.is_digit())) {
		return none
	}

	return precisions.map(IntervalFieldPrecision{field, it.int()})
}

// cast_exact_numeric_to_interval is CAST(v AS t) for an exact numeric v and an
// interval t with one field, which v is a number of. The digits after the
// fractional seconds precision (or any fraction of another field) are
// truncated, and it's 22015 (interval field overflow) if it has more digits
// than the leading field precision.
//
// ISO/IEC 9075-2:2023, 6.13, <cast specification>, General Rules, 20.a, 20.a.i, 20.a.ii and 20.a.iii
fn cast_exact_numeric_to_interval(v Value, t Type) !Value {
	q := t.interval_qualifier()
	n := v.as_numeric()!
	base := match q.start {
		.year { i64(12) }
		.month { i64(1) }
		else { q.start.micros() }
	}
	x := interval_from_big(n.numerator * big.integer_from_i64(base) / n.denominator, q)!
	q.check_leading(x)!

	return new_interval_value(t, x)
}

// cast_interval_to_exact_numeric is the interval v, which has one field, as a
// number of that field. A number of seconds has the fractional seconds
// precision as its scale. It's then cast to the exact numeric type (which
// raises 22003 if it doesn't fit).
//
// ISO/IEC 9075-2:2023, 6.13, <cast specification>, General Rules, 8.c, 8.c.i and 8.c.ii
fn cast_interval_to_exact_numeric(v Value) Value {
	q := v.typ.interval_qualifier()
	x := v.int_value()
	if q.start == .second {
		sign := if x < 0 { '-' } else { '' }
		abs := if x < 0 { -x } else { x }
		mut s := '${sign}${abs / 1_000_000}'
		if q.fractional_precision > 0 {
			s += '.' + '${abs % 1_000_000:06}'[..q.fractional_precision]
		}

		return new_numeric_value(s)
	}

	return new_bigint_value(match q.start {
		.year { x / 12 }
		.month { x }
		else { x / q.start.micros() }
	})
}
