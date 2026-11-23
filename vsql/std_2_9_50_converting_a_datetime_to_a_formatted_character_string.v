module vsql

import strings

// ISO/IEC 9075-2:2023, 9.50, Converting a datetime to a formatted character string
//
// CAST(datetime AS character string FORMAT template).

// check_format_target checks that a datetime of type from can be formatted as
// the character string type to. Every field is formatted with its maximum field
// length, so a value that's longer than a VARCHAR is still an error (22001)
// when it's cast.
//
// ISO/IEC 9075-2:2023, 9.50, Converting a datetime to a formatted character string, Syntax Rules, 2 and 3
fn (t DatetimeTemplate) check_format_target(from Type, to Type) ! {
	t.check_type(from)!
	if to.size < t.min_template_length() {
		return template_error(t.text, '${to} is shorter than the template (${t.min_template_length()})')
	}
}

// format_datetime is the datetime v formatted with the template. The second
// is truncated to the fractional precision of the template (IA074).
//
// ISO/IEC 9075-2:2023, 9.50, Converting a datetime to a formatted character string, General Rules
fn (t DatetimeTemplate) format_datetime(v Time) string {
	dt := v.t
	fp := t.fractional_precision()
	// The nanoseconds as 9 digits, so the first fp digits are the fraction of
	// RSEC.
	nanos := left_pad(dt.nanosecond.str(), '0', 9)

	mut sb := strings.new_builder(t.max_template_length())
	for part in t.parts {
		match part.kind {
			.delimiter {
				sb.write_string(part.text)
			}
			.year, .rounded_year {
				year := '${dt.year:04}'
				sb.write_string(year[year.len - part.text.len..])
			}
			.month {
				sb.write_string('${dt.month:02}')
			}
			.day_of_month {
				sb.write_string('${dt.day:02}')
			}
			.day_of_year {
				sb.write_string('${dt.year_day():03}')
			}
			.hour_12 {
				hour := if dt.hour == 0 {
					12
				} else if dt.hour > 12 {
					dt.hour - 12
				} else {
					dt.hour
				}
				sb.write_string('${hour:02}')
			}
			.hour_24 {
				sb.write_string('${dt.hour:02}')
			}
			.minute {
				sb.write_string('${dt.minute:02}')
			}
			.second_of_minute {
				sb.write_string('${dt.second:02}')
			}
			.second_of_day {
				sb.write_string('${dt.hour * 3600 + dt.minute * 60 + dt.second:05}')
			}
			.fraction {
				sb.write_string(nanos[..fp])
			}
			.am_pm {
				sb.write_string(if dt.hour < 12 { 'A.M.' } else { 'P.M.' })
			}
			.time_zone_hour {
				sign := if v.time_zone < 0 { '-' } else { '+' }
				sb.write_string('${sign}${int_abs(v.time_zone) / 60:02}')
			}
			.time_zone_minute {
				sb.write_string('${int_abs(v.time_zone) % 60:02}')
			}
		}
	}

	return sb.str()
}

fn int_abs(n int) int {
	return if n < 0 { -n } else { n }
}
