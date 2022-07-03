// value.v allows values of differnet types to be stored and dealt with at
// runtime and for storage. The Value object is used extensively internally, but
// also is the exposed type when sending results back.

module vsql

pub struct Value {
pub mut:
	// TODO(elliotchance): Make these non-mutable.
	typ          Type
	f64_value    f64    // boolean and numeric
	string_value string // char and varchar
	time_value   Time   // date, time and timestamp
}

fn new_null_value() Value {
	return Value{
		typ: Type{.is_null, 0}
	}
}

fn new_boolean_value(b bool) Value {
	return Value{
		typ: Type{.is_boolean, 0}
		f64_value: if b { 1 } else { 0 }
	}
}

pub fn new_unknown_value() Value {
	return Value{
		typ: Type{.is_boolean, 0}
		f64_value: 2
	}
}

pub fn new_double_precision_value(x f64) Value {
	return Value{
		typ: Type{.is_double_precision, 0}
		f64_value: x
	}
}

pub fn new_integer_value(x int) Value {
	return Value{
		typ: Type{.is_integer, 0}
		f64_value: x
	}
}

pub fn new_bigint_value(x i64) Value {
	return Value{
		typ: Type{.is_bigint, 0}
		f64_value: x
	}
}

pub fn new_real_value(x f32) Value {
	return Value{
		typ: Type{.is_real, 0}
		f64_value: x
	}
}

pub fn new_smallint_value(x i16) Value {
	return Value{
		typ: Type{.is_smallint, 0}
		f64_value: x
	}
}

pub fn new_varchar_value(x string, size int) Value {
	return Value{
		typ: Type{.is_varchar, size}
		string_value: x
	}
}

pub fn new_character_value(x string, size int) Value {
	return Value{
		typ: Type{.is_character, size}
		string_value: x
	}
}

pub fn new_timestamp_value(ts string) ?Value {
	t := new_timestamp_from_string(ts)?

	return Value{
		typ: t.sql_type()
		time_value: t
	}
}

pub fn new_time_value(ts string) ?Value {
	t := new_time_from_string(ts)?

	return Value{
		typ: t.sql_type()
		time_value: t
	}
}

pub fn new_date_value(ts string) ?Value {
	t := new_date_from_string(ts)?

	return Value{
		typ: t.sql_type()
		time_value: t
	}
}

fn bool_str(x f64) string {
	return match x {
		0 { 'FALSE' }
		1 { 'TRUE' }
		2 { 'UNKNOWN' }
		else { 'NULL' }
	}
}

fn f64_string(x f64) string {
	s := '${x:.6}'.trim('.').split('.')
	if s.len == 1 {
		return s[0]
	}

	return '${s[0]}.${s[1].trim_right('0')}'
}

fn (v Value) str() string {
	return match v.typ.typ {
		.is_null {
			'NULL'
		}
		.is_boolean {
			bool_str(v.f64_value)
		}
		.is_double_precision, .is_real, .is_bigint, .is_integer, .is_smallint {
			f64_string(v.f64_value)
		}
		.is_varchar, .is_character {
			v.string_value
		}
		.is_date, .is_time_with_time_zone, .is_time_without_time_zone,
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
			v.time_value.str()
		}
	}
}

fn (v Value) is_null() bool {
	return v.typ.typ == .is_null
}

// cmp returns for the first argument:
//
//   -1 if v < v2
//    0 if v == v2
//    1 if v > v2
//
// The SQL standard doesn't define if NULLs should be always ordered first or
// last. In vsql, NULLs are always considered to be less than any other non-null
// value. The second return value will be true if either value is NULL.
//
// Or an error if the values are different types (cannot be compared).
fn (v Value) cmp(v2 Value) ?(int, bool) {
	if v.is_null() && v2.is_null() {
		return 0, true
	}

	if v.is_null() {
		return -1, true
	}

	if v2.is_null() {
		return 1, true
	}

	// TODO(elliotchance): BOOLEAN shouldn't be compared this way.
	if v.typ.uses_f64() && v2.typ.uses_f64() {
		if v.f64_value < v2.f64_value {
			return -1, false
		}

		if v.f64_value > v2.f64_value {
			return 1, false
		}

		return 0, false
	}

	if v.typ.uses_string() && v2.typ.uses_string() {
		if v.string_value < v2.string_value {
			return -1, false
		}

		if v.string_value > v2.string_value {
			return 1, false
		}

		return 0, false
	}

	return error('cannot compare $v.typ and $v2.typ')
}
