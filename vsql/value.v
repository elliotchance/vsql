// value.v allows values of differnet types to be stored and dealt with at
// runtime and for storage. The Value object is used extensively internally, but
// also is the exposed type when sending results back.

module vsql

// Possible values for a BOOLEAN. These must not be negative values because they
// are encoded as u8 on disk.
pub enum Boolean {
	is_unknown = 0 // same as NULL
	is_false = 1
	is_true = 2
}

fn (b Boolean) str() string {
	return match b {
		.is_false { 'FALSE' }
		.is_true { 'TRUE' }
		.is_unknown { 'UNKNOWN' }
	}
}

pub struct Value {
pub mut:
	// TODO(elliotchance): Make these non-mutable.
	typ Type
	// Used by all types (including those that have NULL built in like BOOLEAN).
	is_null bool
	// BOOLEAN
	bool_value Boolean
	// DOUBLE PRECISION and REAL
	f64_value f64
	// BIGINT, INTEGER and SMALLINT
	int_value i64
	// CHARACTER VARYING(n) and CHARACTER(n)
	string_value string
	// DATE
	// TIME(n) WITH TIME ZONE and TIME(n) WITHOUT TIME ZONE
	// TIMESTAMP(n) WITH TIME ZONE and TIMESTAMP(n) WITHOUT TIME ZONE
	time_value Time
	// If is_coercible is true the value comes from an ambigious type (like a
	// numerical constant) that can be corerced to another type if needed in an
	// expression.
	is_coercible bool
}

pub fn new_null_value(typ SQLType) Value {
	return Value{
		typ: Type{typ, 0, 0, false}
		is_null: true
	}
}

pub fn new_boolean_value(b bool) Value {
	return Value{
		typ: Type{.is_boolean, 0, 0, false}
		bool_value: if b { .is_true } else { .is_false }
	}
}

pub fn new_unknown_value() Value {
	return Value{
		typ: Type{.is_boolean, 0, 0, false}
		bool_value: .is_unknown
	}
}

pub fn new_double_precision_value(x f64) Value {
	return Value{
		typ: Type{.is_double_precision, 0, 0, false}
		f64_value: x
	}
}

pub fn new_integer_value(x int) Value {
	return Value{
		typ: Type{.is_integer, 0, 0, false}
		int_value: x
	}
}

pub fn new_bigint_value(x i64) Value {
	return Value{
		typ: Type{.is_bigint, 0, 0, false}
		int_value: x
	}
}

pub fn new_real_value(x f32) Value {
	return Value{
		typ: Type{.is_real, 0, 0, false}
		f64_value: x
	}
}

pub fn new_smallint_value(x i16) Value {
	return Value{
		typ: Type{.is_smallint, 0, 0, false}
		int_value: x
	}
}

pub fn new_varchar_value(x string, size int) Value {
	return Value{
		typ: Type{.is_varchar, size, 0, false}
		string_value: x
	}
}

pub fn new_character_value(x string, size int) Value {
	return Value{
		typ: Type{.is_character, size, 0, false}
		string_value: x
	}
}

pub fn new_timestamp_value(ts string) ?Value {
	t := new_timestamp_from_string(ts)?

	return Value{
		typ: t.typ
		time_value: t
	}
}

pub fn new_time_value(ts string) ?Value {
	t := new_time_from_string(ts)?

	return Value{
		typ: t.typ
		time_value: t
	}
}

pub fn new_date_value(ts string) ?Value {
	t := new_date_from_string(ts)?

	return Value{
		typ: t.typ
		time_value: t
	}
}

fn f64_string(x f64) string {
	s := '${x:.6}'.trim('.').split('.')
	if s.len == 1 {
		return s[0]
	}

	return '${s[0]}.${s[1].trim_right('0')}'
}

// as_f64() is not safe to use if the value is not numeric.
fn (v Value) as_f64() f64 {
	if v.typ.uses_f64() {
		return v.f64_value
	}

	return v.int_value
}

// as_int() is not safe to use if the value is not numeric.
fn (v Value) as_int() i64 {
	if v.typ.uses_int() {
		return v.int_value
	}

	return i64(v.f64_value)
}

fn (v Value) str() string {
	if v.is_null && v.typ.typ != .is_boolean {
		return 'NULL'
	}

	return match v.typ.typ {
		.is_boolean {
			v.bool_value.str()
		}
		.is_double_precision, .is_real {
			f64_string(v.f64_value)
		}
		.is_bigint, .is_integer, .is_smallint {
			v.int_value.str()
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
	if v.is_null && v2.is_null {
		return 0, true
	}

	if v.is_null {
		return -1, true
	}

	if v2.is_null {
		return 1, true
	}

	// TODO(elliotchance): BOOLEAN shouldn't be compared this way.
	if v.typ.uses_int() {
		if v2.typ.uses_int() {
			return cmp_value(v.int_value, v2.int_value)
		}

		if v2.typ.uses_f64() {
			return cmp_value(v.int_value, v2.f64_value)
		}
	}

	if v.typ.uses_f64() {
		if v2.typ.uses_int() {
			return cmp_value(v.f64_value, v2.int_value)
		}

		if v2.typ.uses_f64() {
			return cmp_value(v.f64_value, v2.f64_value)
		}
	}

	if v.typ.uses_string() && v2.typ.uses_string() {
		return cmp_value(v.string_value, v2.string_value)
	}

	return error('cannot compare $v.typ and $v2.typ')
}

fn cmp_value<A, B>(lhs A, rhs B) (int, bool) {
	if lhs < rhs {
		return -1, false
	}

	if lhs > rhs {
		return 1, false
	}

	return 0, false
}
