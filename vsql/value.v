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

pub fn new_varchar_value(x string, size int) Value {
	return Value{
		typ: Type{.is_varchar, size}
		string_value: x
	}
}

pub fn (v Value) == (v2 Value) bool {
	match v.typ.typ {
		.is_null {
			return false
		}
		// TODO(elliotchance): BOOLEAN shouldn't be compared this way.
		.is_boolean, .is_bigint, .is_integer, .is_smallint, .is_double_precision, .is_real {
			return match v2.typ.typ {
				.is_boolean, .is_bigint, .is_integer, .is_smallint, .is_double_precision, .is_real {
					v.f64_value == v2.f64_value
				}
				else {
					false
				}
			}
		}
		.is_varchar, .is_character {
			return match v2.typ.typ {
				.is_varchar, .is_character {
					v.string_value == v2.string_value
				}
				else {
					false
				}
			}
		}
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
		.is_null { 'NULL' }
		.is_boolean { bool_str(v.f64_value) }
		.is_double_precision, .is_real, .is_bigint, .is_integer, .is_smallint { f64_string(v.f64_value) }
		.is_varchar, .is_character { v.string_value }
	}
}
