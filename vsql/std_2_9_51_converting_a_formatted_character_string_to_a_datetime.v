module vsql

import time

// ISO/IEC 9075-2:2023, 9.51, Converting a formatted character string to a datetime
//
// CAST(character string AS datetime FORMAT template).

// check_parse_source checks that a character string of type from can be cast
// to the datetime type to with the template.
//
// ISO/IEC 9075-2:2023, 9.51, Converting a formatted character string to a datetime, Syntax Rules, 2 and 3
fn (t DatetimeTemplate) check_parse_source(from Type, to Type) ! {
	t.check_type(to)!
	if from.size < t.min_template_length() {
		return template_error(t.text, '${from} is shorter than the template (${t.min_template_length()})')
	}
}

// is_deterministic is true if a string is always cast to the same datetime of
// type to, which isn't true if it uses the current year or month: when the
// type has a date and the template doesn't have a year of 4 digits and a month
// and day (or a day of year).
//
// ISO/IEC 9075-2:2023, 9.51, Converting a formatted character string to a datetime, General Rules, 5
fn (t DatetimeTemplate) is_deterministic(to Type) bool {
	if to.typ in [.is_time_with_time_zone, .is_time_without_time_zone] {
		return true
	}

	mut full_year := false
	for i, part in t.parts {
		if part.kind in [.year, .rounded_year] && part.text.len == 4 && !t.is_delimited(i) {
			full_year = true
		}
	}

	return full_year && (t.has(.day_of_year) || (t.has(.month) && t.has(.day_of_month)))
}

// match_string returns the string of each part of the template in s, or none if
// s doesn't match the regular expression of the template. A delimited field
// can have from 1 digit up to its maximum field length (a time zone hour is a
// sign and up to 2 digits), and the longest that matches is used. A digit is
// 0 to 9.
//
// ISO/IEC 9075-2:2023, 9.51, Converting a formatted character string to a datetime, Syntax Rules, 4 and 5
// ISO/IEC 9075-2:2023, 9.51, Converting a formatted character string to a datetime, General Rules, 4
fn (t DatetimeTemplate) match_string(s string) ?[]string {
	mut matched := []string{len: t.parts.len}
	if t.match_part(s, 0, 0, mut matched) {
		return matched
	}

	return none
}

fn (t DatetimeTemplate) match_part(s string, i int, pos int, mut matched []string) bool {
	if i == t.parts.len {
		return pos == s.len
	}

	part := t.parts[i]
	match part.kind {
		.delimiter {
			if pos < s.len && s[pos..pos + 1] == part.text {
				matched[i] = part.text
				return t.match_part(s, i + 1, pos + 1, mut matched)
			}
			return false
		}
		.am_pm {
			if pos + 4 <= s.len && s[pos..pos + 4] in ['A.M.', 'P.M.'] {
				matched[i] = s[pos..pos + 4]
				return t.match_part(s, i + 1, pos + 4, mut matched)
			}
			return false
		}
		else {}
	}

	mut start := pos
	if part.kind == .time_zone_hour {
		if pos >= s.len || s[pos] !in [`+`, `-`, ` `] {
			return false
		}
		start++
	}

	max := if part.kind == .time_zone_hour { 2 } else { t.max_field_length(i) }
	min := if t.is_delimited(i) { 1 } else { max }
	mut digits := 0
	for start + digits < s.len && digits < max && s[start + digits].is_digit() {
		digits++
	}
	for digits >= min {
		matched[i] = s[pos..start + digits]
		if t.match_part(s, i + 1, start + digits, mut matched) {
			return true
		}
		digits--
	}

	return false
}

// parse_datetime is the datetime of type to that s is, with the template.
//
// ISO/IEC 9075-2:2023, 9.51, Converting a formatted character string to a datetime, General Rules
fn (t DatetimeTemplate) parse_datetime(mut conn Connection, s string, to Type) !Value {
	matched := t.match_string(s) or { return sqlstate_22007() }

	// The current year and month are in the time zone of the session, like
	// CURRENT_DATE.
	now := local_now(conn)
	current_year := '${now.year:04}'

	mut year := now.year
	mut month := now.month
	mut day := 1
	mut day_of_year := 0
	mut hour := 0
	mut minute := 0
	mut second := 0
	mut fraction := ''
	mut time_zone := 0
	mut time_zone_sign := 1
	mut hour_12 := 0
	mut pm := false
	for i, part in t.parts {
		value := matched[i]
		match part.kind {
			.delimiter {}
			.year {
				year = (current_year[..4 - value.len] + value).int()
			}
			.rounded_year {
				year = rounded_year(now.year, value)
			}
			.month {
				month = value.int()
			}
			.day_of_month {
				day = value.int()
			}
			.day_of_year {
				day_of_year = value.int()
			}
			.hour_12 {
				hour_12 = value.int()
			}
			.hour_24 {
				hour = value.int()
			}
			.minute {
				minute = value.int()
			}
			.second_of_minute {
				second = value.int()
			}
			.second_of_day {
				seconds := value.int()
				hour = seconds / 3600
				minute = seconds / 60 % 60
				second = seconds % 60
				if seconds >= 86400 {
					return sqlstate_22007()
				}
			}
			.fraction {
				fraction = value
			}
			.am_pm {
				pm = value[0] == `P`
			}
			.time_zone_hour {
				if value[0] == `-` {
					time_zone_sign = -1
				}
				time_zone += value[1..].int() * 60
			}
			.time_zone_minute {
				time_zone += value.int()
			}
		}
	}

	if t.has(.hour_12) {
		hour = (if hour_12 == 12 { 0 } else { hour_12 }) + if pm { 12 } else { 0 }
	}
	time_zone *= time_zone_sign

	if year < 1 || year > 9999 {
		return sqlstate_22007()
	}

	// The day of year is in the year of the template (or the current year), so
	// that "YYYY DDD" can be any year.
	if t.has(.day_of_year) {
		month = 1
		day = day_of_year
		for month < 12 && day > days_in_month(month, year) {
			day -= days_in_month(month, year)
			month++
		}
	}

	if month < 1 || month > 12 || day < 1 || day > days_in_month(month, year) || hour > 23
		|| minute > 59 || second > 59 || time_zone < min_time_zone_displacement
		|| time_zone > max_time_zone_displacement {
		return sqlstate_22007()
	}

	// The fraction is microseconds, so the digits after the 6th are dropped.
	fraction_str := if fraction == '' { '' } else { '.' + fraction.limit(6) }
	time_str := '${hour:02}:${minute:02}:${second:02}${fraction_str}'
	time_zone_str := '${if time_zone < 0 { '-' } else { '+' }}${int_abs(time_zone) / 60:02}:${int_abs(time_zone) % 60:02}'
	date_str := '${year:04}-${month:02}-${day:02}'
	value := match to.typ {
		.is_date {
			new_date_value(date_str)!
		}
		.is_time_without_time_zone {
			new_time_value(time_str)!
		}
		.is_time_with_time_zone {
			new_time_value(time_str + time_zone_str)!
		}
		.is_timestamp_without_time_zone {
			new_timestamp_value('${date_str} ${time_str}')!
		}
		else {
			new_timestamp_value('${date_str} ${time_str}${time_zone_str}')!
		}
	}

	return cast(mut conn, 'for CAST', value, to)!
}

// days_in_month is the number of days in a month (1 to 12) of a year in the
// Gregorian calendar.
fn days_in_month(month int, year int) int {
	if month == 2 {
		return if time.is_leap_year(year) { 29 } else { 28 }
	}

	return if month in [4, 6, 9, 11] { 30 } else { 31 }
}

// rounded_year is the year of an RR (or RRRR with fewer than 4 digits), using
// the current year for the digits that are missing (IV096). With 1 or 2 digits,
// it's the nearest year that ends with them (up to 50 years before the current
// year, or 49 after it). With 3 digits, the first digit is from the current
// year, like YYY.
//
// ISO/IEC 9075-2:2023, 9.51, Converting a formatted character string to a datetime, General Rules, 6.b
fn rounded_year(current_year int, digits string) int {
	if digits.len >= 3 {
		return ('${current_year:04}'[..4 - digits.len] + digits).int()
	}

	modulus := if digits.len == 1 { 10 } else { 100 }
	low := current_year - modulus / 2
	mut year := low - low % modulus + digits.int()
	if year < low {
		year += modulus
	}

	return year
}
