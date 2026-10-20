// values.v converts values between V and vsql.

module vorm

import orm
import time
import vsql

// is_auto_value is true when a serial field should be given the next value of
// its sequence. That's when the field was left as zero, like other databases.
fn is_auto_value(p orm.Primitive) bool {
	return match p {
		orm.Null { true }
		i8, i16, int, i64, u8, u16, u32, u64 { u64(p) == 0 }
		else { false }
	}
}

// to_column_value converts a value from V to the type of the column, if it's
// known.
fn (mut db DB) to_column_value(p orm.Primitive, column_type ?vsql.Type) !vsql.Value {
	typ := column_type or { return to_value(p)! }
	if p is orm.Null {
		return vsql.new_null_value(typ.typ)
	}

	value := to_value(p)!
	if value.typ.typ == typ.typ {
		return value
	}

	return db.conn.store_assignment(value, typ)
}

// to_value converts a value from V to vsql.
fn to_value(p orm.Primitive) !vsql.Value {
	return match p {
		orm.Null { vsql.new_null_value(.is_varchar) }
		bool { vsql.new_boolean_value(p) }
		i8, i16, u8 { vsql.new_smallint_value(i16(p)) }
		int, u16 { vsql.new_integer_value(int(p)) }
		i64, u32 { vsql.new_bigint_value(i64(p)) }
		u64 { vsql.new_numeric_value(p.str()) }
		f32 { vsql.new_real_value(p) }
		f64 { vsql.new_double_precision_value(p) }
		string { vsql.new_varchar_value(p) }
		time.Time { vsql.new_timestamp_value(p.format_ss_micro())! }
		orm.InfixType { to_value(p.right)! }
		else { error('vsql: ${p.type_name()} is not supported') }
	}
}

// to_primitive converts a value from vsql to the V type that the ORM expects,
// see orm.type_idx. The column may have a different type to the V field, such
// as an int field with @[sql_type: 'NUMERIC(10)'].
fn to_primitive(v vsql.Value, typ int) !orm.Primitive {
	if v.is_null {
		return orm.null_primitive
	}

	return match typ {
		orm.type_idx['bool'] { orm.Primitive(v.bool_value() == .is_true) }
		orm.type_idx['i8'] { orm.Primitive(i8(to_int(v))) }
		orm.type_idx['i16'] { orm.Primitive(i16(to_int(v))) }
		orm.type_idx['int'], orm.serial, orm.enum_ { orm.Primitive(int(to_int(v))) }
		orm.type_idx['i64'] { orm.Primitive(to_int(v)) }
		orm.type_idx['u8'] { orm.Primitive(u8(to_int(v))) }
		orm.type_idx['u16'] { orm.Primitive(u16(to_int(v))) }
		orm.type_idx['u32'] { orm.Primitive(u32(to_int(v))) }
		orm.type_idx['u64'] { orm.Primitive(to_u64(v)) }
		orm.type_idx['f32'] { orm.Primitive(f32(to_f64(v))) }
		orm.type_idx['f64'] { orm.Primitive(to_f64(v)) }
		orm.time_ { orm.Primitive(v.time_value().t) }
		else { orm.Primitive(to_string(v)) }
	}
}

fn to_int(v vsql.Value) i64 {
	if v.typ.uses_int() {
		return v.int_value()
	}

	if v.typ.uses_f64() {
		return i64(v.f64_value())
	}

	// A NUMERIC or DECIMAL (or a string) is truncated, like 12.5 to 12.
	return i64(to_string(v).f64())
}

// to_u64 is separate from to_int because a u64 is stored as NUMERIC(20), which
// can be larger than an i64.
fn to_u64(v vsql.Value) u64 {
	if v.typ.uses_int() {
		return u64(v.int_value())
	}

	return to_string(v).u64()
}

fn to_f64(v vsql.Value) f64 {
	if v.typ.uses_f64() {
		return v.f64_value()
	}

	if v.typ.uses_int() {
		return f64(v.int_value())
	}

	return to_string(v).f64()
}

fn to_string(v vsql.Value) string {
	if v.typ.uses_string() {
		return v.string_value()
	}

	return v.str()
}
