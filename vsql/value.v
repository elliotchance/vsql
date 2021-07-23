// value.v allows values of differnet types to be stored and dealt with at
// runtime and for storage. The Value object is used extensively internally, but
// also is the exposed type when sending results back.

module vsql

enum ValueType {
	is_f64
	is_string
}

struct Value {
pub:
	typ          ValueType
	f64_value    f64
	string_value string
}

fn new_f64_value(x f64) Value {
	return Value{
		typ: ValueType.is_f64
		f64_value: x
	}
}

fn new_string_value(x string) Value {
	return Value{
		typ: ValueType.is_string
		string_value: x
	}
}

fn (v Value) == (v2 Value) bool {
	return match v.typ {
		.is_f64 { v2.typ == .is_f64 && v.f64_value == v2.f64_value }
		.is_string { v2.typ == .is_string && v.string_value == v2.string_value }
	}
}
