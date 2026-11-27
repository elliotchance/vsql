module vsql

// DATE_TRUNC(field, source) (V402-20) rounds a datetime down to the start of a
// unit, like PostgreSQL's date_trunc, and resets every smaller field to its
// lowest value. The field is a character string (in any case) that must be
// constant, so it's checked when the statement is compiled (see
// date_trunc_type). Unlike PostgreSQL, the result has the type of the source
// (a DATE stays a DATE), and a value WITH TIME ZONE is truncated in its own
// time zone, which it keeps.

// date_trunc_fields are the fields of DATE_TRUNC, from the smallest. A DATE
// has DAY and larger, a TIME has HOUR and smaller, and a TIMESTAMP has all of
// them.
const date_trunc_fields = ['MICROSECONDS', 'MILLISECONDS', 'SECOND', 'MINUTE', 'HOUR', 'DAY', 'WEEK',
	'MONTH', 'QUARTER', 'YEAR', 'DECADE', 'CENTURY', 'MILLENNIUM']

// date_trunc_hour is the index of HOUR in date_trunc_fields, the largest field
// of a TIME. The fields after it are the fields of a DATE.
const date_trunc_hour = 4

fn register_date_trunc_funcs(mut conn Connection) ! {
	varchar := Type{SQLType.is_varchar, 0, 0, false, false}
	for typ in [SQLType.is_date, .is_time_without_time_zone, .is_time_with_time_zone,
		.is_timestamp_without_time_zone, .is_timestamp_with_time_zone] {
		size := if typ == .is_date { 0 } else { 6 }
		source := Type{typ, size, 0, false, false}
		conn.register_func(Func{'DATE_TRUNC', [varchar, source], false, func_date_trunc, source, false, true, [
			vsql_date_trunc,
		], [], false})!
	}
}

// date_trunc_type is the type of DATE_TRUNC, which is the type of the source.
// The field must be a constant that's one of the fields of the source.
fn date_trunc_type(mut c Compiler, field CompileResult, source Type) !Type {
	// A NULL is a constant, but it isn't a field.
	value := if field.constant {
		field.run(mut c.conn, Row{}, c.params)!
	} else {
		Value{
			is_null: true
		}
	}
	if value.is_null {
		return sqlstate_42601("the field of DATE_TRUNC must be a constant that isn't NULL")
	}

	name := value.string_value().to_upper()
	index := date_trunc_fields.index(name)
	if index < 0 {
		return sqlstate_42601('DATE_TRUNC has no field ${value.string_value()}')
	}

	if source.typ == .is_date && index < date_trunc_hour + 1 {
		return sqlstate_42804("in DATE_TRUNC('${name}', ...)", 'TIME or TIMESTAMP', source.str())
	}
	if source.typ in [.is_time_without_time_zone, .is_time_with_time_zone]
		&& index > date_trunc_hour {
		return sqlstate_42804("in DATE_TRUNC('${name}', ...)", 'DATE or TIMESTAMP', source.str())
	}

	return source
}

fn func_date_trunc(_ FunctionContext, args []Value) !Value {
	index := date_trunc_fields.index(args[0].string_value().to_upper())
	t := args[1].time_value()
	mut year, mut month, mut day := t.t.year, t.t.month, t.t.day
	mut hour, mut minute, mut second, mut nanosecond := t.t.hour, t.t.minute, t.t.second, t.t.nanosecond

	// Each field resets the fields smaller than it.
	nanosecond = if index == 0 { nanosecond / 1000 * 1000 } else { nanosecond / 1000000 * 1000000 }
	if index >= 2 {
		nanosecond = 0
	}
	if index >= 3 {
		second = 0
	}
	if index >= 4 {
		minute = 0
	}
	if index >= 5 {
		hour = 0
	}

	match date_trunc_fields[index] {
		'WEEK' {
			// An ISO 8601 week starts on a Monday. The day can be before the
			// first of the month (see new_lenient_time).
			day -= iso_day_of_week(days_from_civil(year, month, day)) - 1
		}
		'MONTH' {
			day = 1
		}
		'QUARTER' {
			day, month = 1, (month - 1) / 3 * 3 + 1
		}
		'YEAR' {
			day, month = 1, 1
		}
		'DECADE' {
			// There's no year 0, so the first decade (years 1 to 9) has no
			// start.
			day, month, year = 1, 1, year / 10 * 10
			if year == 0 {
				return sqlstate_22008()
			}
		}
		'CENTURY' {
			day, month, year = 1, 1, (year - 1) / 100 * 100 + 1
		}
		'MILLENNIUM' {
			day, month, year = 1, 1, (year - 1) / 1000 * 1000 + 1
		}
		else {}
	}

	return Value{
		typ: args[1].typ
		v:   InternalValue{
			time_value: box_time(Time{t.typ, t.time_zone, new_lenient_time(year, month,
				day, hour, minute, second, nanosecond)})
		}
	}
}

// date_trunc_arg_names are the names of the parameters of the functions in this
// file (see builtin_arg_names).
const date_trunc_arg_names = {
	'DATE_TRUNC': ['FIELD', 'SOURCE']
}
