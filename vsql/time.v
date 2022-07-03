// time.v contains functions for dealing with dates and times.

module vsql

import strings
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

// TimeType changes the behavior of calculations of Time objects. The time zone
// is not included here as that is kept separate.
enum TimeType {
	date
	time
	timestamp
}

// Time is the internal way that time is represented and provides other
// conversions such as to/from storage and to/from V's native time.Time.
struct Time {
	typ            TimeType
	with_time_zone bool
	time_zone      i16 // number of minutes from 00:00 (positive or negative)
	t              time.Time
	prec           u8 // 0 to 6
}

// This is an internal constructor, you will want to use new_timestamp_value
// (or similar others) to return the Value instead.
fn new_timestamp_from_string(s string) ?Time {
	expects_time_zone := s.len > 6 && (s[s.len - 6] == `+` || s[s.len - 6] == `-`)

	mut re := regex.regex_opt(match expects_time_zone {
		true { vsql.unquoted_timestamp_with_time_zone_string }
		false { vsql.unquoted_timestamp_without_time_zone_string }
	})?
	if !re.matches_string(s) {
		return sqlstate_42601('TIMESTAMP \'$s\' is not valid')
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
			return sqlstate_42601('TIMESTAMP \'$s\' is not valid')
		}

		// If we don't trim off the time zone, V will try and interpret it but
		// we don't want that because we handle the time zone separately.
		to_parse = s.substr(0, s.len - 6)
	}

	mut prec := u8(0)
	if to_parse.contains('.') {
		prec = u8(to_parse.len - to_parse.index_u8(`.`)) - 1
	}

	return Time{.timestamp, expects_time_zone, time_zone, time.parse_iso8601(to_parse) or {
		return sqlstate_42601('TIMESTAMP \'$s\' is not valid')
	}, prec}
}

// This is an internal constructor, you will want to use new_time_value
// (or similar others) to return the Value instead.
fn new_time_from_string(s string) ?Time {
	// The easiest way to parse it is as a normal timestamp with a dummy date
	// part. We use 1970-01-01 because internally we still need to rely on the
	// unix timestamp in V's Time object. This data part will be ignored in
	// actual calculations.
	t := new_timestamp_from_string('1970-01-01 $s') or {
		return sqlstate_42601('TIME \'$s\' is not valid')
	}

	return Time{.time, t.with_time_zone, t.time_zone, t.t, t.prec}
}

// This is an internal constructor, you will want to use new_date_value
// (or similar others) to return the Value instead.
fn new_date_from_string(s string) ?Time {
	// The easiest way to parse it is as a normal timestamp with a dummy time
	// part.
	t := new_timestamp_from_string('$s 00:00:00') or {
		return sqlstate_42601('DATE \'$s\' is not valid')
	}

	return Time{.date, t.with_time_zone, t.time_zone, t.t, t.prec}
}

fn new_time_from_components(typ TimeType, with_time_zone bool, year int, month int, day int, hour int, minute int, second int, microsecond int, time_zone i16, prec u8) Time {
	return Time{typ, with_time_zone, time_zone, time.new_time(time.Time{
		year: year
		month: month
		day: day
		hour: hour
		minute: minute
		second: second
		microsecond: microsecond
	}), prec}
}

fn new_time_from_bytes(typ TimeType, with_time_zone bool, bytes []u8, prec u8) Time {
	mut ts_i64 := bytes_to_i64(bytes)

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
	if with_time_zone {
		time_zone = bytes_to_i16(bytes[bytes.len - 2..])
	}

	return new_time_from_components(typ, with_time_zone, year, month, day, hour, minute,
		second, int(ts_i64), time_zone, prec)
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
	if t.with_time_zone {
		mut buf := new_bytes(i64_to_bytes(t.i64()))
		buf.write_i16(t.time_zone)

		return buf.bytes()
	}

	return i64_to_bytes(t.i64())
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
		t.t.second * vsql.second_period + t.t.microsecond
}

// See i64() for details.
fn (t Time) date_i64() i64 {
	return t.t.year * vsql.year_period + t.t.month * vsql.month_period + t.t.day * vsql.day_period
}

fn (t Time) str() string {
	return match t.typ {
		.timestamp {
			t.str_timestamp()
		}
		.time {
			t.str_time()
		}
		.date {
			t.str_date()
		}
	}
}

fn (t Time) str_timestamp() string {
	return t.str_date() + 'T' + t.str_time()
}

fn (t Time) str_date() string {
	return t.t.strftime('%Y-%m-%d')
}

fn (t Time) str_time() string {
	mut s := t.t.strftime('%H:%M:%S')

	if t.prec > 0 {
		s += '.' + t.t.microsecond.str()
		s += strings.repeat(`0`, t.prec - t.t.microsecond.str().len)
	}

	if t.with_time_zone {
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
			s += '0$hours'
		} else {
			s += '$hours'
		}

		if minutes < 10 {
			s += '0$minutes'
		} else {
			s += '$minutes'
		}
	}

	return s
}

fn (t Time) sql_type() Type {
	match t.typ {
		.date {
			return Type{.is_date, t.prec}
		}
		.time {
			if t.with_time_zone {
				return Type{.is_time_with_time_zone, t.prec}
			}

			return Type{.is_time_without_time_zone, t.prec}
		}
		.timestamp {
			if t.with_time_zone {
				return Type{.is_timestamp_with_time_zone, t.prec}
			}

			return Type{.is_timestamp_without_time_zone, t.prec}
		}
	}
}
