// row.v defines a row object which is used both internally and as an external
// representation.

module vsql

import math
import math.big

// Represents a single row which may contain one or more columns.
struct Row {
mut:
	// id is the unique row identifier within the table. If the table has a
	// PRIMARY KEY this will be a binary representation of that. Otherwise, it's
	// a sequential value allocated by Storage.next_row_id.
	id []u8
	// tid is the transaction ID that created this row.
	tid  u64
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
// get_column returns the value of a column in a Result. Unlike get, this works
// when the result has more than one column with the same name.
pub fn (r Row) get_column(column Column) !Value {
	if column.name.custom_id != '' && column.name.sub_entity_name != '' {
		return r.get(column.name.custom_id)
	}

	return r.get(column.name.sub_entity_name)
}

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

fn (r Row) bytes(t Table) []u8 {
	mut buf := new_empty_bytes()

	buf.write_u16(u16(r.id.len))
	buf.write_u8s(r.id)

	// The number of columns lets a row written before a column was added to the
	// table still be read.
	buf.write_u16(u16(t.columns.len))

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

fn new_row_from_bytes(t Table, data []u8, tid u64) Row {
	mut buf := new_bytes(data)
	mut row := map[string]Value{}

	row_id := buf.read_u8s(buf.read_u16())
	column_count := int(buf.read_u16())

	for i, col in t.columns {
		// Columns that didn't exist when the row was written are NULL. Any
		// values after the last column are ignored.
		if i >= column_count {
			row[col.name.id()] = Value{
				typ:     col.typ
				is_null: true
			}
			continue
		}

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
					typ :=
						Type{.is_time_without_time_zone, col.typ.size, col.typ.scale, col.not_null}
					v.v.time_value = new_time_from_bytes(typ, buf.read_u8s(8))
				}
				.is_timestamp_with_time_zone {
					typ :=
						Type{.is_timestamp_with_time_zone, col.typ.size, col.typ.scale, col.not_null}
					v.v.time_value = new_time_from_bytes(typ, buf.read_u8s(10))
				}
				.is_timestamp_without_time_zone {
					typ :=
						Type{.is_timestamp_without_time_zone, col.typ.size, col.typ.scale, col.not_null}
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

// write_key_integer writes an integer in a PRIMARY KEY as size bytes, so that
// the keys sort in the same order as the values: big-endian with the sign bit
// flipped. See "Primary Key" in the file format docs.
fn write_key_integer(mut buf Bytes, value i64, size int) {
	flipped := u64(value) ^ (u64(1) << (size * 8 - 1))
	for i := size - 1; i >= 0; i-- {
		buf.write_u8(u8(flipped >> (i * 8)))
	}
}

// write_key_float writes a REAL (size 4) or DOUBLE PRECISION (size 8) in a
// PRIMARY KEY. A positive number has the sign bit flipped, and a negative number
// has every bit flipped, so that the keys sort in the same order as the values.
// -0 is the same key as 0 because they're equal.
fn write_key_float(mut buf Bytes, value f64, size int) {
	x := if value == 0 { f64(0) } else { value }
	bits := if size == 4 { u64(math.f32_bits(f32(x))) } else { math.f64_bits(x) }
	sign := u64(1) << (size * 8 - 1)
	flipped := if bits & sign != 0 { ~bits } else { bits | sign }
	for i := size - 1; i >= 0; i-- {
		buf.write_u8(u8(flipped >> (i * 8)))
	}
}

// write_key_numeric writes a NUMERIC or DECIMAL in a PRIMARY KEY. Values that
// are equal (such as 1.5 and 1.50) have the same key. It's a byte for the sign
// (0 negative, 1 zero, 2 positive), followed by (for a non-zero) the position
// of the first significant digit as an i16 (like write_key_integer) and each
// significant digit plus 1, ending with a 0. Every byte after the sign is
// flipped for a negative number, so a larger magnitude sorts first.
fn write_key_numeric(mut buf Bytes, value Numeric) {
	if value.is_zero() {
		buf.write_u8(1)
		return
	}

	// A DECIMAL used to be able to hold more digits than its scale (#223), such
	// as 123/500 in a DECIMAL(3, 2), which is shown as 0.24 but isn't equal to
	// 0.24. Files written before then can still have those keys. Their
	// denominator was always less than 10^(scale + 1), so two values that aren't
	// equal differ by more than 10^-(2 * scale + 2). The digits are truncated to
	// one more place than that, which keeps those values apart, and keeps equal
	// values (such as 1/2 and 5/10) the same. A value with exactly the digits of
	// its scale (all values now, see normalize_denominator) is written the same
	// as it would be with "places" equal to the scale.
	places := 2 * int(value.typ.scale) + 3
	magnitude := value.numerator.abs() * big.integer_from_int(10).pow(u32(places)) / value.denominator
	mut s := magnitude.str()
	if s.len <= places {
		s = '0'.repeat(places + 1 - s.len) + s
	}
	is_negative := value.is_negative()
	integer_digits := s[..s.len - places].trim_left('0')
	fraction_digits := s[s.len - places..]
	digits := (integer_digits + fraction_digits).trim_left('0').trim_right('0')

	// The leading zeros of a number less than 1 make the exponent zero or
	// negative, such as 0 for 0.5 and -1 for 0.05.
	exponent := if integer_digits != '' {
		integer_digits.len
	} else {
		fraction_digits.trim_left('0').len - fraction_digits.len
	}

	mut key := new_empty_bytes()
	write_key_integer(mut key, exponent, 2)
	for digit in digits {
		key.write_u8(digit - `0` + 1)
	}
	key.write_u8(0)

	buf.write_u8(if is_negative { 0 } else { 2 })
	for b in key.bytes() {
		buf.write_u8(if is_negative { ~b } else { b })
	}
}

// write_key_string writes a CHARACTER or CHARACTER VARYING in a PRIMARY KEY.
// Strings are compared as if the shorter one is padded with spaces (the PAD
// SPACE characteristic of the default collation, 10.5 Syntax Rule 2), so the
// keys must sort that way too. For example, 'a' is equal to 'a ' and greater
// than 'a' followed by a tab, but less than 'a b'.
//
// Trailing spaces are removed. Each other space is written as a space and then
// a byte for whether the next character that isn't a space sorts after a space
// (2) or before it (0). The string ends with a space and 1, which is like spaces
// that go on forever. That can't appear anywhere else, so it's also where the
// string ends when there are more columns in the key.
fn write_key_string(mut buf Bytes, value string) {
	bytes := value.trim_right(' ').bytes()
	for i, b in bytes {
		buf.write_u8(b)
		if b == ` ` {
			mut next := i + 1
			for bytes[next] == ` ` {
				next++
			}
			buf.write_u8(if bytes[next] > ` ` { 2 } else { 0 })
		}
	}
	buf.write_u8(` `)
	buf.write_u8(1)
}

// write_key_value writes one value of a PRIMARY KEY column of type typ. See
// "Primary Key" in the file format docs.
fn write_key_value(mut buf Bytes, value Value, typ SQLType) {
	match typ {
		.is_boolean {
			buf.write_u8(u8(value.bool_value()))
		}
		.is_smallint {
			write_key_integer(mut buf, value.int_value(), 2)
		}
		.is_integer {
			write_key_integer(mut buf, value.int_value(), 4)
		}
		.is_bigint {
			write_key_integer(mut buf, value.int_value(), 8)
		}
		.is_real {
			write_key_float(mut buf, value.f64_value(), 4)
		}
		.is_double_precision {
			write_key_float(mut buf, value.f64_value(), 8)
		}
		.is_numeric, .is_decimal {
			write_key_numeric(mut buf, value.numeric_value())
		}
		.is_character, .is_varchar {
			write_key_string(mut buf, value.string_value())
		}
		// Datetimes with a time zone are compared in UTC, so 12:00:00+05:00 is
		// the same key as 07:00:00+00:00.
		.is_time_with_time_zone, .is_timestamp_with_time_zone {
			t := value.time_value()
			write_key_integer(mut buf, t.utc_micros(t.time_zone), 8)
		}
		.is_date, .is_time_without_time_zone, .is_timestamp_without_time_zone {
			write_key_integer(mut buf, value.time_value().i64(), 8)
		}
	}
}

fn (mut r Row) object_key(t Table) ![]u8 {
	// If there is a PRIMARY KEY, generate the row key.
	if t.primary_key.len > 0 {
		mut pk := new_empty_bytes()

		for col_name in t.primary_key {
			write_key_value(mut pk, r.data[col_name], t.column(col_name)!.typ.typ)
		}

		r.id = pk.bytes()
	} else {
		if r.id.len == 0 {
			return sqlstate_xx000('row in ${t.name} has no row ID')
		}
	}

	mut key := row_key_prefix(t.id)
	key << r.id

	return key
}
