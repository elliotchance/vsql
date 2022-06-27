// row.v defines a row object which is used both internally and as an external
// representation.

module vsql

import time

struct Row {
mut:
	// id is the unique row identifier within the table. If the table has a
	// PRIMARY KEY this will be a binary representation of that. Otherwise, a
	// random but time sequential value will be generated for it.
	id []u8
	// tid is the transaction ID that created this row.
	tid  int
	data map[string]Value
}

pub fn new_row(data map[string]Value) Row {
	return Row{
		data: data
	}
}

// get_null will return true if the column name is NULL. An error will be
// returned if the column does not exist.
pub fn (r Row) get_null(name string) ?bool {
	value := r.get(name)?
	return value.typ.typ == .is_null
}

// get_f64 will only work for columns that are numerical (DOUBLE PRECISION,
// FLOAT, REAL, etc). If the value is NULL, 0 will be returned. See get_null().
pub fn (r Row) get_f64(name string) ?f64 {
	value := r.get(name)?
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
	return (r.get(name)?).str()
}

// get_bool only works on a BOOLEAN value. If the value is NULL or UNKNOWN,
// false will be returned. See get_null() and get_unknown() repsectively.
//
// An error is returned if the type is not a BOOLEAN or the column name does not
// exist.
pub fn (r Row) get_bool(name string) ?bool {
	value := r.get(name)?
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
	value := r.get(name)?
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

// new_empty_row is used internally to generate a row with zero values for all
// the types in a Row. This is used for testing expressions without needing the
// actual row.
fn new_empty_row(columns Columns, table_name string) Row {
	mut r := Row{}
	for col in columns {
		mut v := Value{}
		match col.typ.typ {
			.is_null {
				v = new_null_value()
			}
			.is_bigint {
				v = new_bigint_value(0)
			}
			.is_double_precision {
				v = new_double_precision_value(0)
			}
			.is_integer {
				v = new_integer_value(0)
			}
			.is_real {
				v = new_real_value(0)
			}
			.is_smallint {
				v = new_smallint_value(0)
			}
			.is_boolean {
				v = new_boolean_value(false)
			}
			.is_character {
				v = new_character_value('', col.typ.size)
			}
			.is_varchar {
				v = new_varchar_value('', col.typ.size)
			}
		}

		if table_name == '' {
			r.data[col.name] = v
		} else {
			r.data['${table_name}.$col.name'] = v
		}
	}

	return r
}

fn (r Row) bytes(t Table) []u8 {
	mut buf := new_bytes([]u8{})

	buf.write_bytes1(r.id)

	for col in t.columns {
		v := r.data[col.name]

		// Some types do not need a NULL flag because it's built into the value.
		if !col.not_null && col.typ.typ != .is_boolean && col.typ.typ != .is_varchar
			&& col.typ.typ != .is_character {
			buf.write_bool(v.is_null())
		}

		match col.typ.typ {
			.is_null {
				panic('should not be possible')
			}
			.is_boolean {
				buf.write_byte(u8(v.f64_value))
			}
			.is_bigint {
				buf.write_i64(i64(v.f64_value))
			}
			.is_double_precision {
				buf.write_f64(v.f64_value)
			}
			.is_integer {
				buf.write_int(int(v.f64_value))
			}
			.is_real {
				buf.write_f32(f32(v.f64_value))
			}
			.is_smallint {
				buf.write_i16(i16(v.f64_value))
			}
			.is_varchar, .is_character {
				if v.is_null() {
					buf.write_int(-1)
				} else {
					buf.write_string4(v.string_value)
				}
			}
		}
	}

	return buf.bytes()
}

fn new_row_from_bytes(t Table, data []u8, tid int, table_name string) Row {
	mut buf := new_bytes(data)
	mut row := map[string]Value{}

	row_id := buf.read_bytes1()

	for col in t.columns {
		// Some types do not need a NULL flag because it's built into the value.
		mut v := Value{
			typ: col.typ
		}
		if col.typ.typ != .is_boolean && col.typ.typ != .is_varchar && col.typ.typ != .is_character {
			if !col.not_null && buf.read_bool() {
				v.typ.typ = .is_null
			}
		}

		match col.typ.typ {
			.is_null {
				panic('should not be possible')
			}
			.is_boolean {
				v.f64_value = buf.read_byte()
			}
			.is_bigint {
				v.f64_value = buf.read_i64()
			}
			.is_double_precision {
				v.f64_value = buf.read_f64()
			}
			.is_integer {
				v.f64_value = buf.read_int()
			}
			.is_real {
				v.f64_value = buf.read_f32()
			}
			.is_smallint {
				v.f64_value = buf.read_i16()
			}
			.is_varchar, .is_character {
				len := buf.read_int()
				if len == -1 {
					v.typ.typ = .is_null
				} else {
					v.string_value = buf.read_bytes(len).bytestr()
				}
			}
		}

		if table_name == '' {
			row[col.name] = v
		} else {
			row['${table_name}.$col.name'] = v
		}
	}

	return Row{row_id, tid, row}
}

fn (mut r Row) object_key(t Table) ?[]u8 {
	// If there is a PRIMARY KEY, generate the row key.
	if t.primary_key.len > 0 {
		mut pk := new_bytes([]u8{})

		for col_name in t.primary_key {
			col := t.column(col_name)?
			match col.typ.typ {
				.is_null {
					return error('cannot use NULL in PRIMARY KEY')
				}
				.is_bigint {
					pk.write_i64(i64(r.data[col_name].f64_value))
				}
				.is_boolean {
					return error('cannot use BOOLEAN in PRIMARY KEY')
				}
				.is_character {
					return error('cannot use character types in PRIMARY KEY')
				}
				.is_double_precision {
					return error('cannot use non-integer types in PRIMARY KEY')
				}
				.is_integer {
					pk.write_int(int(r.data[col_name].f64_value))
				}
				.is_real {
					return error('cannot use non-integer types in PRIMARY KEY')
				}
				.is_smallint {
					pk.write_i16(i16(r.data[col_name].f64_value))
				}
				.is_varchar {
					return error('cannot use character types in PRIMARY KEY')
				}
			}
		}

		r.id = pk.bytes()
	} else {
		if r.id.len == 0 {
			// TODO(elliotchance): This is a terrible hack to make sure we have
			//  a globally unique but also ordered id for the row.
			unique_id := time.now().unix_time_milli()
			time.sleep(time.millisecond)

			r.id = i64_to_bytes(unique_id)
		}
	}

	mut key := new_bytes([]u8{})
	key.write_byte(`R`)
	key.write_bytes(t.name.bytes())

	// TODO(elliotchance): This is actually not a safe separator to use since
	//  deliminated table names can contain ':'
	key.write_byte(`:`)
	key.write_bytes(r.id)

	return key.bytes()
}
