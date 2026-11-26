module vsql

// ISO/IEC 9075-2:2023, 9.52, Datetime templates
//
// A <datetime template> is the FORMAT of a CAST between a datetime and a
// character string (see 9.50 and 9.51), such as 'YYYY-MM-DD HH24:MI'.

enum TemplatePartKind {
	delimiter
	year
	rounded_year
	month
	day_of_month
	day_of_year
	hour_12
	hour_24
	minute
	second_of_minute
	second_of_day
	fraction
	am_pm
	time_zone_hour
	time_zone_minute
}

// A DatetimeTemplatePart is a <datetime template part>: a <datetime template
// field> or a <datetime template delimiter>, as it's written (such as "YYYY" or
// "-").
struct DatetimeTemplatePart {
	kind TemplatePartKind
	text string
}

struct DatetimeTemplate {
	text  string
	parts []DatetimeTemplatePart
}

// datetime_template_fields are the <datetime template field>s, longest first so
// that "YYYY" isn't read as "YY" followed by "YY", and "HH24" isn't read as
// "HH" followed by "24".
//
// ISO/IEC 9075-2:2023, 9.52, Datetime templates, Format
const datetime_template_fields = [
	DatetimeTemplatePart{.second_of_day, 'SSSSS'},
	DatetimeTemplatePart{.year, 'YYYY'},
	DatetimeTemplatePart{.rounded_year, 'RRRR'},
	DatetimeTemplatePart{.hour_24, 'HH24'},
	DatetimeTemplatePart{.hour_12, 'HH12'},
	DatetimeTemplatePart{.am_pm, 'A.M.'},
	DatetimeTemplatePart{.am_pm, 'P.M.'},
	DatetimeTemplatePart{.year, 'YYY'},
	DatetimeTemplatePart{.day_of_year, 'DDD'},
	DatetimeTemplatePart{.fraction, 'FF1'},
	DatetimeTemplatePart{.fraction, 'FF2'},
	DatetimeTemplatePart{.fraction, 'FF3'},
	DatetimeTemplatePart{.fraction, 'FF4'},
	DatetimeTemplatePart{.fraction, 'FF5'},
	DatetimeTemplatePart{.fraction, 'FF6'},
	DatetimeTemplatePart{.fraction, 'FF7'},
	DatetimeTemplatePart{.fraction, 'FF8'},
	DatetimeTemplatePart{.fraction, 'FF9'},
	DatetimeTemplatePart{.time_zone_hour, 'TZH'},
	DatetimeTemplatePart{.time_zone_minute, 'TZM'},
	DatetimeTemplatePart{.year, 'YY'},
	DatetimeTemplatePart{.rounded_year, 'RR'},
	DatetimeTemplatePart{.month, 'MM'},
	DatetimeTemplatePart{.day_of_month, 'DD'},
	DatetimeTemplatePart{.hour_12, 'HH'},
	DatetimeTemplatePart{.minute, 'MI'},
	DatetimeTemplatePart{.second_of_minute, 'SS'},
	DatetimeTemplatePart{.year, 'Y'},
]

// datetime_template_delimiters are the <datetime template delimiter>s.
const datetime_template_delimiters = "-./,';: "

// datetime_template_names are the names of the fields in the errors.
const datetime_template_names = {
	TemplatePartKind.year: 'year'
	.rounded_year:         'rounded year'
	.month:                'month'
	.day_of_month:         'day of month'
	.day_of_year:          'day of year'
	.hour_12:              '12-hour'
	.hour_24:              '24-hour'
	.minute:               'minute'
	.second_of_minute:     'second of minute'
	.second_of_day:        'second of day'
	.fraction:             'fraction'
	.am_pm:                'am/pm'
	.time_zone_hour:       'time zone hour'
	.time_zone_minute:     'time zone minute'
}

// parse_datetime_template checks the Syntax Rules that don't depend on the
// datetime type (see check_type for the rest). The fields are upper case, as
// they are in the Format.
//
// ISO/IEC 9075-2:2023, 9.52, Datetime templates, Syntax Rules, 2 to 11
fn parse_datetime_template(text string) !DatetimeTemplate {
	mut parts := []DatetimeTemplatePart{}
	mut i := 0
	outer: for i < text.len {
		if datetime_template_delimiters.contains_u8(text[i]) {
			if parts.len > 0 && parts.last().kind == .delimiter {
				return template_error(text, 'two delimiters cannot be next to each other')
			}
			parts << DatetimeTemplatePart{.delimiter, text[i..i + 1]}
			i++
			continue
		}
		for field in datetime_template_fields {
			if text[i..].starts_with(field.text) {
				parts << field
				i += field.text.len
				continue outer
			}
		}

		return template_error(text, 'unknown field at "${text[i..]}"')
	}

	if parts.len == 0 {
		return template_error(text, 'it is empty')
	}

	t := DatetimeTemplate{text, parts}
	for kind, name in datetime_template_names {
		if parts.filter(it.kind == kind).len > 1 {
			return template_error(text, 'the ${name} field can only be used once')
		}
	}
	if t.has(.year) && t.has(.rounded_year) {
		return template_error(text, 'cannot have both a year and a rounded year')
	}
	if t.has(.day_of_year) && (t.has(.month) || t.has(.day_of_month)) {
		return template_error(text, 'cannot have both a day of year and a month or day of month')
	}
	if t.has(.hour_24) && (t.has(.hour_12) || t.has(.am_pm)) {
		return template_error(text, 'cannot have both a 24-hour and a 12-hour or am/pm')
	}
	if t.has(.hour_12) != t.has(.am_pm) {
		return template_error(text, 'a 12-hour must be used with an am/pm')
	}
	if t.has(.second_of_day)
		&& (t.has(.hour_12) || t.has(.hour_24) || t.has(.minute) || t.has(.second_of_minute)) {
		return template_error(text, 'cannot have both a second of day and an hour, minute or second of minute')
	}
	if t.has(.time_zone_minute) && !t.has(.time_zone_hour) {
		return template_error(text, 'a time zone minute must be used with a time zone hour')
	}

	return t
}

fn template_error(text string, message string) IError {
	return sqlstate_42601("invalid datetime template '${text}': ${message}")
}

fn (t DatetimeTemplate) str() string {
	return "'${t.text.replace("'", "''")}'"
}

fn (t DatetimeTemplate) has(kind TemplatePartKind) bool {
	return t.parts.any(it.kind == kind)
}

// features are the features that the template uses: F555 for more than 6
// digits of a fraction, and F411 for a time zone.
//
// ISO/IEC 9075-2:2023, 9.52, Datetime templates, Conformance Rules, 1 and 2
fn (t DatetimeTemplate) features() []string {
	mut features := []string{}
	if t.parts.any(it.text in ['FF7', 'FF8', 'FF9']) {
		features << 'F555'
	}
	if t.has(.time_zone_hour) {
		features << 'F411'
	}

	return features
}

// check_type checks the fields that can be used with a datetime type.
//
// ISO/IEC 9075-2:2023, 9.52, Datetime templates, Syntax Rules, 12
fn (t DatetimeTemplate) check_type(typ Type) ! {
	date_fields := [TemplatePartKind.year, .rounded_year, .month, .day_of_month, .day_of_year]
	time_fields := [TemplatePartKind.hour_12, .hour_24, .minute, .second_of_minute, .second_of_day,
		.fraction, .am_pm]
	time_zone_fields := [TemplatePartKind.time_zone_hour, .time_zone_minute]
	not_allowed := match typ.typ {
		.is_date { arrays_concat(time_fields, time_zone_fields) }
		.is_time_without_time_zone { arrays_concat(date_fields, time_zone_fields) }
		.is_time_with_time_zone { date_fields }
		.is_timestamp_without_time_zone { time_zone_fields }
		else { []TemplatePartKind{} }
	}
	for part in t.parts {
		if part.kind in not_allowed {
			return template_error(t.text, '${part.text} cannot be used with ${typ}')
		}
	}
}

fn arrays_concat(a []TemplatePartKind, b []TemplatePartKind) []TemplatePartKind {
	mut result := a.clone()
	result << b

	return result
}

// is_left_delimited is true if part i is first, an am/pm or time zone hour, or
// follows a delimiter or am/pm.
//
// ISO/IEC 9075-2:2023, 9.52, Datetime templates, Syntax Rules, 13
fn (t DatetimeTemplate) is_left_delimited(i int) bool {
	return i == 0 || t.parts[i].kind in [.am_pm, .time_zone_hour]
		|| t.parts[i - 1].kind in [.delimiter, .am_pm]
}

// is_right_delimited is true if part i is the last field, an am/pm, or is
// followed by a delimiter, am/pm or time zone hour.
//
// ISO/IEC 9075-2:2023, 9.52, Datetime templates, Syntax Rules, 14
fn (t DatetimeTemplate) is_right_delimited(i int) bool {
	mut last_field := t.parts.len - 1
	for last_field > 0 && t.parts[last_field].kind == .delimiter {
		last_field--
	}

	return i == last_field || t.parts[i].kind == .am_pm
		|| (i + 1 < t.parts.len && t.parts[i + 1].kind in [.delimiter, .am_pm, .time_zone_hour])
}

// is_delimited is true if part i is both left- and right-delimited, so it can
// be shorter than its maximum field length in a string that's cast to a
// datetime.
//
// ISO/IEC 9075-2:2023, 9.52, Datetime templates, Syntax Rules, 15
fn (t DatetimeTemplate) is_delimited(i int) bool {
	return t.is_left_delimited(i) && t.is_right_delimited(i)
}

// max_field_length is the most characters that part i can be.
//
// ISO/IEC 9075-2:2023, 9.52, Datetime templates, Syntax Rules, 16
fn (t DatetimeTemplate) max_field_length(i int) int {
	part := own_elem(t.parts, i)
	return match part.kind {
		.hour_12, .hour_24, .time_zone_minute { 2 }
		.fraction { part.text[2..].int() }
		else { part.text.len }
	}
}

// max_template_length is the length of every value that's formatted with the
// template.
//
// ISO/IEC 9075-2:2023, 9.52, Datetime templates, Syntax Rules, 17
fn (t DatetimeTemplate) max_template_length() int {
	mut length := 0
	for i in 0 .. t.parts.len {
		length += t.max_field_length(i)
	}

	return length
}

// min_field_length is the fewest characters that part i can be.
//
// ISO/IEC 9075-2:2023, 9.52, Datetime templates, Syntax Rules, 18
fn (t DatetimeTemplate) min_field_length(i int) int {
	if !t.is_delimited(i) {
		return t.max_field_length(i)
	}
	if t.parts[i].kind == .time_zone_hour {
		return 2
	}

	return 1
}

// min_template_length is the shortest string that can be cast to a datetime
// with the template, which is also the shortest character string type that a
// datetime can be cast to with it.
//
// ISO/IEC 9075-2:2023, 9.52, Datetime templates, Syntax Rules, 19
fn (t DatetimeTemplate) min_template_length() int {
	mut length := 0
	for i in 0 .. t.parts.len {
		length += t.min_field_length(i)
	}

	return length
}

// fractional_precision is the number of digits of the fraction of a second
// (FF1 to FF9), or 0 without one.
//
// ISO/IEC 9075-2:2023, 9.52, Datetime templates, Syntax Rules, 20
fn (t DatetimeTemplate) fractional_precision() int {
	for part in t.parts {
		if part.kind == .fraction {
			return part.text[2..].int()
		}
	}

	return 0
}
