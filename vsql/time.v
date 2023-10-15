// time.v contains functions for dealing with dates and times.

module vsql

import regex
import time

const (
	second_period = i64(1000000)
	minute_period = 60 * second_period
	hour_period   = 60 * minute_period
	day_period    = 24 * hour_period
	month_period  = 31 * day_period
	year_period   = 12 * month_period
)

// When a precision is not specified by TIME or TIMESTAMP types we should use
// these defaults. These are layed out specifically in the SQL standard.
const (
	default_time_precision      = 0
	default_timestamp_precision = 6
)

// The SQL standard is pretty strict about the format for date and time
// literals. They express this through the grammar itself, but for simplicity
// and performance the lexer treats all strings the same.
//
// We need to emulate the grammar with a regex which is expressed as:
//
//   <unquoted timestamp string> ::=
//     <unquoted date string> <space> <unquoted time string>
//
//   <unquoted date string> ::= <date value>
//
//   <unquoted time string> ::= <time value> [ <time zone interval> ]
//
//   <date value> ::=
//     <years value> <minus sign> <months value> <minus sign> <days value>
//
//   <time value> ::=
//     <hours value> <colon> <minutes value> <colon> <seconds value>
//
//   <time zone interval> ::=
//     <sign> <hours value> <colon> <minutes value>
//
const (
	unquoted_date_string                        = r'\d+\-\d+\-\d+'
	unquoted_time_string_with_time_zone         = r'\d+:\d+:\d+(\.\d{1,6})?[-+]\d+:\d+'
	unquoted_time_string_without_time_zone      = r'\d+:\d+:\d+(\.\d{1,6})?'
	unquoted_timestamp_with_time_zone_string    = '^' + unquoted_date_string + r'\s' +
		unquoted_time_string_with_time_zone + '$'
	unquoted_timestamp_without_time_zone_string = '^' + unquoted_date_string + r'\s' +
		unquoted_time_string_without_time_zone + '$'
)

// Time is the internal way that time is represented and provides other
// conversions such as to/from storage and to/from V's native time.Time.
pub struct Time {
pub mut:
	// typ.size is the precision (0 to 6)
	typ Type
	// Number of minutes from 00:00 (positive or negative)
	time_zone i16
	// Internal V time represenation.
	t time.Time
}

// This is an internal constructor, you will want to use new_timestamp_value
// (or similar others) to return the Value instead.
fn new_timestamp_from_string(s string) !Time {
	expects_time_zone := s.len > 6 && (s[s.len - 6] == `+` || s[s.len - 6] == `-`)

	mut re := regex.regex_opt(match expects_time_zone {
		true { vsql.unquoted_timestamp_with_time_zone_string }
		false { vsql.unquoted_timestamp_without_time_zone_string }
	}) or { return error('cannot compile regex for timestamp: ${err}') }
	if !re.matches_string(s) {
		return sqlstate_42601('TIMESTAMP \'${s}\' is not valid')
	}

	mut time_zone := i16(0)
	mut to_parse := s
	if expects_time_zone {
		hours := i16(s[s.len - 6..s.len - 3].int())
		minutes := i16(s[s.len - 2..s.len].int())
		if hours < 0 {
			time_zone = hours * 60 - minutes
		} else {
			time_zone = hours * 60 + minutes
		}

		if time_zone <= -720 || time_zone >= 720 {
			return sqlstate_42601('TIMESTAMP \'${s}\' is not valid')
		}

		// If we don't trim off the time zone, V will try and interpret it but
		// we don't want that because we handle the time zone separately.
		to_parse = s.substr(0, s.len - 6)
	}

	mut typ := Type{
		typ: if expects_time_zone {
			.is_timestamp_with_time_zone
		} else {
			.is_timestamp_without_time_zone
		}
		size: if to_parse.contains('.') { u8(to_parse.len - to_parse.index_u8(`.`)) - 1 } else { 0 }
	}

	return Time{typ, time_zone, time.parse_iso8601(to_parse) or {
		return sqlstate_42601('TIMESTAMP \'${s}\' is not valid')
	}}
}

// This is an internal constructor, you will want to use new_time_value
// (or similar others) to return the Value instead.
fn new_time_from_string(s string) !Time {
	// The easiest way to parse it is as a normal timestamp with a dummy date
	// part. We use 1970-01-01 because internally we still need to rely on the
	// unix timestamp in V's Time object. This data part will be ignored in
	// actual calculations.
	mut t := new_timestamp_from_string('1970-01-01 ${s}') or {
		return sqlstate_42601('TIME \'${s}\' is not valid')
	}

	if t.typ.typ == .is_timestamp_with_time_zone {
		t.typ.typ = .is_time_with_time_zone
	} else {
		t.typ.typ = .is_time_without_time_zone
	}

	return Time{t.typ, t.time_zone, t.t}
}

// This is an internal constructor, you will want to use new_date_value
// (or similar others) to return the Value instead.
fn new_date_from_string(s string) !Time {
	// The easiest way to parse it is as a normal timestamp with a dummy time
	// part.
	mut t := new_timestamp_from_string('${s} 00:00:00') or {
		return sqlstate_42601('DATE \'${s}\' is not valid')
	}

	t.typ.typ = .is_date

	return Time{t.typ, t.time_zone, t.t}
}

fn new_time_from_components(typ Type, year int, month int, day int, hour int, minute int, second int, microsecond int, time_zone i16) Time {
	return Time{typ, time_zone, time.new_time(time.Time{
		year: year
		month: month
		day: day
		hour: hour
		minute: minute
		second: second
		nanosecond: microsecond * 1000
	})}
}

fn new_time_from_bytes(typ Type, bytes []u8) Time {
	mut buf := new_bytes(bytes)
	mut ts_i64 := buf.read_i64()

	year := int(ts_i64 / vsql.year_period)
	ts_i64 -= year * vsql.year_period

	month := int(ts_i64 / vsql.month_period)
	ts_i64 -= month * vsql.month_period

	day := int(ts_i64 / vsql.day_period)
	ts_i64 -= day * vsql.day_period

	hour := int(ts_i64 / vsql.hour_period)
	ts_i64 -= hour * vsql.hour_period

	minute := int(ts_i64 / vsql.minute_period)
	ts_i64 -= minute * vsql.minute_period

	second := int(ts_i64 / vsql.second_period)
	ts_i64 -= second * vsql.second_period

	mut time_zone := i16(0)
	if typ.typ == .is_time_with_time_zone || typ.typ == .is_timestamp_with_time_zone {
		time_zone = buf.read_i16()
	}

	return new_time_from_components(typ, year, month, day, hour, minute, second, int(ts_i64),
		time_zone)
}

// bytes returns the storage representation of the Time. The number of bytes
// used depends on the type, where combinations produce the sum of:
//
//   date = 4 bytes
//   time = 4 bytes
//   time zone = 2 bytes
//
// A Time is stored as a modulo of the respective parts (rather than in
// continuous form such as epoch seconds). This makes it faster to store an
// retrieve but cannot be used in calculations directly.
//
// It's also worth nothing that the SQL standard does not permit for fractional
// minute time zones. These are not used anymore, but for historical reason
// (even as recent as 1972) some time zones had a seconds component. Trying to
// use seconds in the time zone will result in a syntax error since the standard
// treats a timestamp as grammar. It will be up to you how to decide to round
// the time zone to whole minutes in these cases.
fn (t Time) bytes() []u8 {
	mut buf := new_empty_bytes()
	buf.write_i64(t.i64())

	if t.typ.typ == .is_time_with_time_zone || t.typ.typ == .is_timestamp_with_time_zone {
		buf.write_i16(t.time_zone)
	}

	return buf.bytes()
}

// i64 returns the canonical integer representation of a specific millisecond
// in time.
//
// Considering that the highest precision for seconds the SQL standard permits
// is 6 (that's microseconds) we can store any timestamp in an i64 with plenty
// of room to spare:
//
//   2^63 / (1e6 * 60 * 60 * 24 * 31 * 12) ~= 286967 years
//
// Unfortunatly, even with this ridiculous range of years we do not have enough
// spare digits to also encode the time zone (without reducing the years to
// around 400, even ultilizing the full 64 bits). So we store the timezone
// separate.
fn (t Time) i64() i64 {
	return t.date_i64() + t.time_i64()
}

// See i64() for details.
fn (t Time) time_i64() i64 {
	return t.t.hour * vsql.hour_period + t.t.minute * vsql.minute_period +
		t.t.second * vsql.second_period + int(t.t.nanosecond / 1000)
}

// See i64() for details.
fn (t Time) date_i64() i64 {
	return t.t.year * vsql.year_period + t.t.month * vsql.month_period + t.t.day * vsql.day_period
}

// Returns the Time formatted based on its type.
fn (t Time) str() string {
	return match t.typ.typ {
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
			t.str_full_timestamp(t.typ.size, true, false)
		}
		.is_time_with_time_zone, .is_time_without_time_zone {
			t.str_full_time(t.typ.size, true, false)
		}
		.is_date {
			t.str_date()
		}
		else {
			// Not possible.
			''
		}
	}
}

// str_date returns the date portion, such as '2022-06-30'.
fn (t Time) str_date() string {
	return t.t.strftime('%Y-%m-%d')
}

// str_time returns the time portion, such as '12:34:56'. This does not include
// fractional seconds or time zone information.
fn (t Time) str_time() string {
	return t.t.strftime('%H:%M:%S')
}

// str_full_time returns the time, fractional seconds (rounded to prec) and time
// zone information (if included).
//
// If allow_time_zone is false, the time zone information will never be included
// in the output. Otherwise the time zone will be optionally included depending
// on the type.
//
// See str_time_zone for details about sql_formatting.
fn (t Time) str_full_time(prec int, allow_time_zone bool, sql_formatting bool) string {
	return t.str_time() + t.str_fractional_seconds(prec) +
		t.str_time_zone(allow_time_zone, sql_formatting)
}

// str_full_timestamp works the same way as str_full_time but also includes the
// date portion.
//
// See str_time_zone for details about sql_formatting.
fn (t Time) str_full_timestamp(prec int, allow_time_zone bool, sql_formatting bool) string {
	return t.str_date() + if sql_formatting {
		' '
	} else {
		'T'
	} + t.str_full_time(prec, allow_time_zone, sql_formatting)
}

// str_fractional_seconds returns the fractional seconds which can either be
// empty for zero size or include the proceeding decimal and be zero padded to
// the size, such as '.123000'.
//
// This function takes a prec to allow for external rounding. For normal
// formatting you should pass in the current type precision.
fn (t Time) str_fractional_seconds(prec int) string {
	if prec == 0 {
		return ''
	}

	// Round down first, if needed.
	mut s := int(t.t.nanosecond / 1000).str()
	if prec < s.len {
		s = s[..prec]
	}

	return '.' + (s + '000000')[..prec]
}

// str_time_zone returns an empty string when not part of the type (ie. WITHOUT
// TIME ZONE) or the encoded time zone, such as '+0500'.
//
// If allow_time_zone is false, the time zone information will never be included
// in the output. Otherwise the time zone will be optionally included depending
// on the type.
//
// If sql_formatting is true, a ':' will be placed between the hours and
// minutes. This is rather annoying thing (as I best understand it, I may be
// wrong) that *receiving* a time zone need to be like '+05:00' but *formatting*
// a time zone must be in '+0500'. Because this function is used to format a
// time zone that will do back into another value we need it to do both
// depending on the situation.
fn (t Time) str_time_zone(allow_time_zone bool, sql_formatting bool) string {
	if !allow_time_zone {
		return ''
	}

	if t.typ.typ != .is_time_with_time_zone && t.typ.typ != .is_timestamp_with_time_zone {
		return ''
	}

	mut s := ''
	negative := t.time_zone < 0
	mut time_zone := t.time_zone
	if negative {
		time_zone *= -1
	}

	if t.time_zone >= 0 {
		s += '+'
	} else {
		s += '-'
	}

	hours := time_zone / 60
	minutes := time_zone % 60

	if hours < 10 {
		s += '0${hours}'
	} else {
		s += '${hours}'
	}

	if sql_formatting {
		s += ':'
	}

	if minutes < 10 {
		s += '0${minutes}'
	} else {
		s += '${minutes}'
	}

	return s
}

fn time_zone_value(conn &Connection) string {
	_, mut offset := conn.now()
	mut s := ''

	if offset < 0 {
		s += '-'
		offset *= -1
	} else {
		s += '+'
	}

	s += left_pad(int(offset / 60).str(), '0', 2) + ':' + left_pad(int(offset % 60).str(), '0', 2)

	return s
}

fn default_now() (time.Time, i16) {
	return time.utc(), i16(time.offset() / 60)
}
