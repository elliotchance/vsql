// row.v defines a row object which is used both internally and as an external
// representation.

module vdb

struct Row {
mut:
	offset u32
	data   map[string]Value
}

pub fn (r Row) get_f64(name string) f64 {
	return r.data[name].f64_value
}

pub fn (r Row) get_string(name string) string {
	if r.data[name].typ == ValueType.is_f64 {
		return r.data[name].f64_value.str().trim('.')
	}

	return r.data[name].string_value
}
