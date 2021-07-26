// row.v defines a row object which is used both internally and as an external
// representation.

module vsql

struct Row {
mut:
	offset u32
	data   map[string]Value
}

pub fn (r Row) get_f64(name string) f64 {
	return r.data[name].f64_value
}

pub fn (r Row) get_string(name string) string {
	return match r.data[name].typ.typ {
		.is_null { 'NULL' }
		.is_boolean { bool_str(r.data[name].f64_value) }
		.is_float, .is_real, .is_bigint, .is_integer, .is_smallint { r.data[name].f64_value.str().trim('.') }
		.is_varchar, .is_character { r.data[name].string_value }
	}
}
