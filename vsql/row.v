// row.v defines a row object which is used both internally and as an external
// representation.

module vsql

import time

// Represents a single row which may contain one or more columns.
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

fn new_row(data map[string]Value) Row {
	return Row{
		data: data
	}
}

// get_null will return true if the column name is NULL. An error will be
// returned if the column does not exist.
pub fn (r Row) get_null(name string) !bool {
	value := r.get(name)!

	return value.is_null
}

// get_f64 will only work for columns that are numerical (DOUBLE PRECISION,
// FLOAT, REAL, etc). If the value is NULL, 0 will be returned. See get_null().
pub fn (r Row) get_f64(name string) !f64 {
	value := r.get(name)!
	if value.typ.uses_f64() {
		return value.f64_value()
	}

	return error("cannot use get_f64('${name}') when type is ${value.typ}")
}

// get_int will only work for columns that are integers (SMALLINT, INTEGER or
// BIGINT). If the value is NULL, 0 will be returned. See get_null().
pub fn (r Row) get_int(name string) !int {
	value := r.get(name)!
	if value.typ.uses_int() {
		return int(value.int_value())
	}

	return error("cannot use get_int('${name}') when type is ${value.typ}")
}

// get_string is the most flexible getter and will try to coerce the value
// (including non-strings like numbers, booleans, NULL, etc) into some kind of
// string.
//
// An error is only returned if the column does not exist.
pub fn (r Row) get_string(name string) !string {
	return (r.get(name)!).str()
}

// get_bool only works on a BOOLEAN value. If the column permits NULL values it
// will be represented as UNKNOWN.
//
// An error is returned if the type is not a BOOLEAN or the column name does not
// exist.
pub fn (r Row) get_bool(name string) !Boolean {
	value := r.get(name)!

	match value.typ.typ {
		.is_boolean {
			return value.bool_value()
		}
		else {
			return error("cannot use get_bool('${name}') when type is ${value.typ}")
		}
	}
}

// get returns the underlying Value. It will return an error if the column does
// not exist.
pub fn (r Row) get(name string) !Value {
	return r.data[name] or {
		// Be helpful and look for silly mistakes.
		for n, _ in r.data {
			if n.to_upper() == name.to_upper() {
				return error('no such column ${name}, did you mean ${n}?')
			}
		}

		return error('no such column ${name}')
	}
}

fn (r Row) for_storage() Row {
	mut new_data := map[string]Value{}
	for k, v in r.data {
		parts := k.split('.')
		new_data[parts[parts.len - 1]] = v
	}

	return Row{r.id, r.tid, new_data}
}

// new_empty_row is used internally to generate a row with zero values for all
// the types in a Row. This is used for testing expressions without needing the
// actual row.
fn new_empty_row(columns Columns, table_name string) Row {
	mut r := Row{}
	for col in columns {
		v := new_empty_value(col.typ)

		if table_name == '' {
			r.data[col.name.sub_entity_name] = v
		} else {
			r.data[col.name.id()] = v
		}
	}

	return r
}

fn new_empty_value(typ Type) Value {
	mut value := match typ.typ {
		.is_date, .is_time_with_time_zone, .is_time_without_time_zone,
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
			new_null_value(typ.typ)
		}
		.is_bigint {
			new_bigint_value(0)
		}
		.is_double_precision {
			new_double_precision_value(0)
		}
		.is_integer {
			new_integer_value(0)
		}
		.is_real {
			new_real_value(0)
		}
		.is_smallint {
			new_smallint_value(0)
		}
		.is_boolean {
			new_boolean_value(false)
		}
		.is_character {
			new_character_value('')
		}
		.is_varchar {
			new_varchar_value('')
		}
		.is_numeric, .is_decimal {
			new_numeric_value('0')
		}
	}

	value.typ.not_null = typ.not_null

	return value
}

fn new_empty_table_row(tables map[string]Table) Row {
	mut r := Row{}
	for _, table in tables {
		for col in table.columns {
			r.data[col.name.id()] = new_empty_value(col.typ)
		}
	}

	return r
}

fn (r Row) bytes(t Table) []u8 {
	mut buf := new_empty_bytes()

	buf.write_u8(u8(r.id.len))
	buf.write_u8s(r.id)

	for col in t.columns {
		v := r.data[col.name.sub_entity_name]

		// If the column is allows for NULL we need to prepend a NULL indicator.
		// However, there are certain types that we do not need to add a
		// separate NULL indicator because it's built into the value itself.
		if !col.not_null {
			match col.typ.typ {
				.is_varchar, .is_character, .is_date, .is_time_with_time_zone,
				.is_time_without_time_zone, .is_timestamp_with_time_zone,
				.is_timestamp_without_time_zone, .is_bigint, .is_double_precision, .is_integer,
				.is_real, .is_smallint, .is_numeric, .is_decimal {
					buf.write_bool(v.is_null)
				}
				.is_boolean {
					// BOOLEAN: NULL is encoded as one of the values.
				}
			}
		}

		// If v is null, there's not need to write any more information.
		if !v.is_null || col.typ.typ == .is_boolean {
			match col.typ.typ {
				.is_boolean {
					buf.write_u8(u8(v.bool_value()))
				}
				.is_bigint {
					buf.write_i64(v.int_value())
				}
				.is_double_precision {
					buf.write_f64(v.f64_value())
				}
				.is_integer {
					buf.write_i32(int(v.int_value()))
				}
				.is_real {
					buf.write_f32(f32(v.f64_value()))
				}
				.is_smallint {
					buf.write_i16(i16(v.int_value()))
				}
				.is_varchar, .is_character {
					buf.write_string4(v.string_value())
				}
				.is_date, .is_time_with_time_zone, .is_time_without_time_zone,
				.is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
					buf.write_u8s(v.time_value().bytes())
				}
				.is_numeric, .is_decimal {
					bytes := v.numeric_value().bytes()
					buf.write_i16(i16(bytes.len))
					buf.write_u8s(bytes)
				}
			}
		}
	}

	return buf.bytes()
}

fn new_row_from_bytes(t Table, data []u8, tid int) Row {
	mut buf := new_bytes(data)
	mut row := map[string]Value{}

	row_id := buf.read_u8s(buf.read_u8())

	for col in t.columns {
		// Some types do not need a NULL flag because it's built into the value.
		mut v := Value{
			typ: col.typ
		}

		// If the column is allows for NULL we need to read the prepended a NULL
		// indicator. However, there are certain types that we do not need to
		// add a separate NULL indicator because it's built into the value
		// itself.
		if !col.not_null {
			match col.typ.typ {
				.is_varchar, .is_character, .is_date, .is_time_with_time_zone,
				.is_time_without_time_zone, .is_timestamp_with_time_zone,
				.is_timestamp_without_time_zone, .is_bigint, .is_double_precision, .is_integer,
				.is_real, .is_smallint, .is_numeric, .is_decimal {
					v.is_null = buf.read_bool()
				}
				.is_boolean {
					// BOOLEAN: NULL is encoded as one of the values.
				}
			}
		}

		// The value is only written if it's not null (or NULL is encoded into
		// the value).
		if !v.is_null || v.typ.typ == .is_boolean {
			match col.typ.typ {
				.is_boolean {
					unsafe {
						b := buf.read_u8()
						if b == 0 {
							v.is_null = true
						} else {
							v.v.bool_value = Boolean(b)
						}
					}
				}
				.is_bigint {
					v.v.int_value = buf.read_i64()
				}
				.is_double_precision {
					v.v.f64_value = buf.read_f64()
				}
				.is_integer {
					v.v.int_value = buf.read_i32()
				}
				.is_real {
					v.v.f64_value = buf.read_f32()
				}
				.is_smallint {
					v.v.int_value = buf.read_i16()
				}
				.is_varchar, .is_character {
					v.v.string_value = buf.read_string4()
				}
				.is_date {
					typ := Type{.is_date, col.typ.size, col.typ.scale, col.not_null}
					v.v.time_value = new_time_from_bytes(typ, buf.read_u8s(8))
				}
				.is_time_with_time_zone {
					typ := Type{.is_time_with_time_zone, col.typ.size, col.typ.scale, col.not_null}
					v.v.time_value = new_time_from_bytes(typ, buf.read_u8s(10))
				}
				.is_time_without_time_zone {
					typ := Type{.is_time_without_time_zone, col.typ.size, col.typ.scale, col.not_null}
					v.v.time_value = new_time_from_bytes(typ, buf.read_u8s(8))
				}
				.is_timestamp_with_time_zone {
					typ := Type{.is_timestamp_with_time_zone, col.typ.size, col.typ.scale, col.not_null}
					v.v.time_value = new_time_from_bytes(typ, buf.read_u8s(10))
				}
				.is_timestamp_without_time_zone {
					typ := Type{.is_timestamp_without_time_zone, col.typ.size, col.typ.scale, col.not_null}
					v.v.time_value = new_time_from_bytes(typ, buf.read_u8s(8))
				}
				.is_numeric, .is_decimal {
					typ := Type{col.typ.typ, col.typ.size, col.typ.scale, col.not_null}
					len := buf.read_i16()
					v.v.numeric_value = new_numeric_from_bytes(typ, buf.read_u8s(len))
				}
			}
		}

		row[col.name.id()] = v
	}

	return Row{row_id, tid, row}
}

fn (mut r Row) object_key(t Table) ![]u8 {
	// If there is a PRIMARY KEY, generate the row key.
	if t.primary_key.len > 0 {
		mut pk := new_empty_bytes()

		for col_name in t.primary_key {
			col := t.column(col_name)!
			match col.typ.typ {
				.is_bigint {
					pk.write_i64(r.data[col_name].int_value())
				}
				.is_integer {
					pk.write_i32(int(r.data[col_name].int_value()))
				}
				.is_smallint {
					pk.write_i16(i16(r.data[col_name].int_value()))
				}
				else {
					return error('cannot use ${col.typ.str()} in PRIMARY KEY')
				}
			}
		}

		r.id = pk.bytes()
	} else {
		if r.id.len == 0 {
			// TODO(elliotchance): This is a terrible hack to make sure we have
			//  a globally unique but also ordered id for the row.
			unique_id := u64(time.now().unix_time_milli())
			time.sleep(time.millisecond)

			mut buf := new_empty_bytes()
			buf.write_u64(unique_id)
			r.id = buf.bytes()
		}
	}

	mut key := new_empty_bytes()
	key.write_u8(`R`)
	key.write_u8s(t.name.storage_id().bytes())

	// TODO(elliotchance): This is actually not a safe separator to use since
	//  deliminated table names can contain ':'
	key.write_u8(`:`)
	key.write_u8s(r.id)

	return key.bytes()
}
