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
	data RowData
}

// RowData is the value of each column of a Row, by the id of the column. Rows
// with the same columns (such as the rows of a scan) share keys, so they're
// only copied when a row gets a new key (see set). This is much smaller and
// faster to make than a map for each row.
struct RowData {
mut:
	keys   []string
	values []Value
}

fn new_row(data map[string]Value) Row {
	return Row{
		data: new_row_data_from_map(data)
	}
}

fn new_row_data_from_map(data map[string]Value) RowData {
	mut d := RowData{
		keys:   []string{cap: data.len}
		values: []Value{cap: data.len}
	}
	for k, v in data {
		d.keys << k
		d.values << v
	}

	return d
}

// index is the position of key, or -1 if the row doesn't have it.
fn (d RowData) index(key string) int {
	for i, k in d.keys {
		if k == key {
			return i
		}
	}

	return -1
}

fn (d RowData) get(key string) ?Value {
	i := d.index(key)
	if i < 0 {
		return none
	}

	return d.values[i]
}

// value is the value of key, or the zero Value if the row doesn't have it.
fn (d RowData) value(key string) Value {
	return d.get(key) or { Value{} }
}

// set replaces the value of key, or adds it after the others. Adding a key
// copies the keys and values, since they may be shared with other rows.
fn (mut d RowData) set(key string, value Value) {
	i := d.index(key)
	if i >= 0 {
		d.values[i] = value
		return
	}

	mut keys := []string{cap: d.keys.len + 1}
	keys << d.keys
	keys << key
	mut values := []Value{cap: d.values.len + 1}
	values << d.values
	values << value
	d.keys = keys
	d.values = values
}

// clone copies the values, so they can be changed without changing d. The keys
// are shared, because set copies them before changing them.
fn (d RowData) clone() RowData {
	return RowData{
		keys:   d.keys
		values: d.values.clone()
	}
}

// merged is the keys and values of d, then those of other. A value of other
// replaces the value of d with the same key.
fn (d RowData) merged(other RowData) RowData {
	if d.keys.len == 0 {
		return other.clone()
	}

	mut r := RowData{
		keys:   []string{cap: d.keys.len + other.keys.len}
		values: []Value{cap: d.keys.len + other.keys.len}
	}
	r.keys << d.keys
	r.values << d.values
	for i, k in other.keys {
		j := r.index(k)
		if j >= 0 {
			r.values[j] = other.values[i]
		} else {
			r.keys << k
			r.values << other.values[i]
		}
	}

	return r
}

fn (d RowData) len() int {
	return d.keys.len
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
	return r.data.get(name) or {
		// Be helpful and look for silly mistakes.
		for n in r.data.keys {
			if n.to_upper() == name.to_upper() {
				return error('no such column ${name}, did you mean ${n}?')
			}
		}

		return error('no such column ${name}')
	}
}

fn (r Row) for_storage() Row {
	mut new_data := RowData{}
	for i, k in r.data.keys {
		parts := k.split('.')
		new_data.set(parts[parts.len - 1], r.data.values[i])
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

		key := if table_name == '' { col.name.sub_entity_name } else { col.name.id() }
		r.data.set(key, v)
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

// max_row_size is the most bytes that a row can be written in. The page object
// that holds it (see PageObject.length) must have a length that fits in an
// int, including its key, which fits in a page.
const max_row_size = max_i32 - page_object_prefix_length - max_page_size

// size_hint is about how many bytes the row will be written in (see bytes), so
// that a long value is only copied once. It's not exact because the size of a
// NUMERIC or DECIMAL depends on its digits.
fn (r Row) size_hint(t Table) i64 {
	mut size := i64(4 + r.id.len)
	for col in t.columns {
		v := r.data.value(col.name.sub_entity_name)
		size += 1 + if !v.is_null && col.typ.typ in [.is_varchar, .is_character] {
			4 + v.string_value().len
		} else {
			16
		}
	}

	return size
}

// bytes is how the row is written in a page object. A row that's bigger than
// max_row_size is 54000 (program limit exceeded).
fn (r Row) bytes(t Table) ![]u8 {
	return r.bytes_with_limit(t, max_row_size)
}

// bytes_with_limit is bytes, but with a smaller limit for tests. Only a
// CHARACTER or CHARACTER VARYING value can be big enough to reach the limit, so
// the size is checked before each one is written, rather than after the buffer
// has already grown too big.
fn (r Row) bytes_with_limit(t Table, limit i64) ![]u8 {
	mut buf := new_bytes_with_capacity(int(math.min(r.size_hint(t), limit)))

	buf.write_u16(u16(r.id.len))
	buf.write_u8s(r.id)

	// The number of columns lets a row written before a column was added to the
	// table still be read.
	buf.write_u16(u16(t.columns.len))

	for col in t.columns {
		v := r.data.value(col.name.sub_entity_name)

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
					// 0 is NULL, whatever else the value holds.
					buf.write_u8(if v.is_null { 0 } else { u8(v.bool_value()) })
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
					s := v.string_value()
					if i64(buf.data.len) + 4 + s.len > limit {
						return sqlstate_54000('row is bigger than the maximum of ${limit} bytes')
					}
					buf.write_string4(s)
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
	return new_row_from_bytes_with_ids(t, t.column_ids(), data, tid)
}

// column_ids is the id of each column of the table, in order.
fn (t Table) column_ids() []string {
	return t.columns.map(it.name.id())
}

// new_row_from_bytes_with_ids is new_row_from_bytes with the ids of the columns
// of the table (see column_ids), so that they aren't made again for each row.
fn new_row_from_bytes_with_ids(t Table, ids []string, data []u8, tid u64) Row {
	return new_row_from_bytes_needed(t, ids, [], data, tid)
}

// skip_value moves buf past a value of typ (that isn't NULL), see Row.bytes.
fn skip_value(mut buf Bytes, typ SQLType) {
	buf.at += match typ {
		.is_boolean { 1 }
		.is_smallint { 2 }
		.is_integer, .is_real { 4 }
		.is_bigint, .is_double_precision, .is_date, .is_time_without_time_zone,
		.is_timestamp_without_time_zone {
			8
		}
		.is_time_with_time_zone, .is_timestamp_with_time_zone { 10 }
		.is_varchar, .is_character { int(buf.read_i32()) }
		.is_numeric, .is_decimal { int(buf.read_i16()) }
	}
}

// new_row_from_bytes_needed is new_row_from_bytes_with_ids, but if needed isn't
// empty, only the columns that are needed are read.
fn new_row_from_bytes_needed(t Table, ids []string, needed []bool, data []u8, tid u64) Row {
	// The values are copied out of data, so it doesn't need to be copied first
	// (see new_bytes).
	mut buf := Bytes{
		data: data
	}
	mut values := []Value{cap: t.columns.len}

	row_id := buf.read_u8s(buf.read_u16())
	column_count := int(buf.read_u16())

	for i, col in t.columns {
		// Columns that didn't exist when the row was written are NULL. Any
		// values after the last column are ignored.
		if i >= column_count {
			values << Value{
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

		// A column that isn't needed still takes its place in values, so that
		// each value stays at the position of its key.
		if needed.len > 0 && !needed[i] {
			if !v.is_null || v.typ.typ == .is_boolean {
				skip_value(mut buf, col.typ.typ)
			}
			values << Value{
				typ:     col.typ
				is_null: true
			}
			continue
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
					v.v.time_value = box_time(new_time_from_bytes(typ, buf.read_u8s(8)))
				}
				.is_time_with_time_zone {
					typ := Type{.is_time_with_time_zone, col.typ.size, col.typ.scale, col.not_null}
					v.v.time_value = box_time(new_time_from_bytes(typ, buf.read_u8s(10)))
				}
				.is_time_without_time_zone {
					typ :=
						Type{.is_time_without_time_zone, col.typ.size, col.typ.scale, col.not_null}
					v.v.time_value = box_time(new_time_from_bytes(typ, buf.read_u8s(8)))
				}
				.is_timestamp_with_time_zone {
					typ :=
						Type{.is_timestamp_with_time_zone, col.typ.size, col.typ.scale, col.not_null}
					v.v.time_value = box_time(new_time_from_bytes(typ, buf.read_u8s(10)))
				}
				.is_timestamp_without_time_zone {
					typ :=
						Type{.is_timestamp_without_time_zone, col.typ.size, col.typ.scale, col.not_null}
					v.v.time_value = box_time(new_time_from_bytes(typ, buf.read_u8s(8)))
				}
				.is_numeric, .is_decimal {
					typ := Type{col.typ.typ, col.typ.size, col.typ.scale, col.not_null}
					len := buf.read_i16()
					v.v.numeric_value = box_numeric(new_numeric_from_bytes(typ, buf.read_u8s(len)))
				}
			}
		}

		values << v
	}

	return Row{row_id, tid, RowData{ids, values}}
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
// SPACE characteristic of the default collation), so the keys must sort that
// way too. For example, 'a' is equal to 'a ' and greater than 'a' followed by a
// tab, but less than 'a b'.
//
// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 3.b
// ISO/IEC 9075-2:2016(E), 9.12, Grouping operations, Syntax Rules, 4
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
			write_key_value(mut pk, r.data.value(col_name), t.column(col_name)!.typ.typ)
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
