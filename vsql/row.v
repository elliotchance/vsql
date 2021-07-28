// row.v defines a row object which is used both internally and as an external
// representation.

module vsql

struct Row {
mut:
	offset u32
	data   map[string]Value
}

// get_null will return true if the column name is NULL. An error will be
// returned if the column does not exist.
pub fn (r Row) get_null(name string) ?bool {
	value := r.get(name) ?
	return value.typ.typ == .is_null
}

// get_f64 will only work for columns that are numerical (FLOAT, REAL, etc). If
// the value is NULL, 0 will be returned. See get_null().
pub fn (r Row) get_f64(name string) ?f64 {
	value := r.get(name) ?
	if value.typ.uses_f64() {
		return value.f64_value
	}

	return error("cannot use get_f64('$name') when type is $value.typ")
}

// get_string is the most flexible getter and will try to coerce the value
// (including non-strings like numbers, booleans, NULL, etc) into some kind of
// string.
//
// An error is only returned if the column does not exist.
pub fn (r Row) get_string(name string) ?string {
	value := r.get(name) ?
	return match value.typ.typ {
		.is_null { 'NULL' }
		.is_boolean { bool_str(r.data[name].f64_value) }
		.is_float, .is_real, .is_bigint, .is_integer, .is_smallint { r.data[name].f64_value.str().trim('.') }
		.is_varchar, .is_character { r.data[name].string_value }
	}
}

// get_bool only works on a BOOLEAN value. If the value is NULL or UNKNOWN,
// false will be returned. See get_null() and get_unknown() repsectively.
//
// An error is returned if the type is not a BOOLEAN or the column name does not
// exist.
pub fn (r Row) get_bool(name string) ?bool {
	value := r.get(name) ?
	return match value.typ.typ {
		.is_boolean { value.f64_value == 1 }
		else { false }
	}
}

// get_unknown returns true only is a value is a BOOLEAN and in the UNKNOWN
// state. The UNKNOWN state is a third state beyond TRUE and FALSE defined in
// the SQL standard. A NULL BOOLEAN will return false.
//
// An error is returned if the type is not a BOOLEAN or the column name does not
// exist.
pub fn (r Row) get_unknown(name string) ?bool {
	value := r.get(name) ?
	return match value.typ.typ {
		.is_boolean { value.f64_value == 2 }
		else { false }
	}
}

fn (r Row) get(name string) ?Value {
	return r.data[name] or {
		// Be helpful and look for silly mistakes.
		for n, _ in r.data {
			if n.to_upper() == name.to_upper() {
				return error('no such column $name, did you mean $n?')
			}
		}

		return error('no such column $name')
	}
}
