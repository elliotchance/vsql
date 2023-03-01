// value.v allows values of differnet types to be stored and dealt with at
// runtime and for storage. The Value object is used extensively internally, but
// also is the exposed type when sending results back.

module vsql

import regex

// Possible values for a BOOLEAN.
pub enum Boolean {
	// These must not be negative values because they are encoded as u8 on disk.
	// 0 is resevered for encoding NULL on disk, but is not a valid value in
	// memory.
	is_false = 1
	is_true  = 2
}

// Returns ``TRUE``, ``FALSE`` or ``UNKNOWN``.
pub fn (b Boolean) str() string {
	return match b {
		.is_false { 'FALSE' }
		.is_true { 'TRUE' }
	}
}

// A single value. It contains it's type information in ``typ``.
pub struct Value {
pub mut:
	// TODO(elliotchance): Make these non-mutable.
	// The type of this Value.
	typ Type
	// Used by all types (including those that have NULL built in like BOOLEAN).
	is_null bool
	// v packs the actual value. You need to use one of the methods to get the
	// actual value safely.
	v InternalValue
}

fn (e Value) compile(mut c Compiler) !CompileResult {
	return CompileResult{
		run: fn [e] (mut conn Connection, data Row, params map[string]Value) !Value {
			return e
		}
		typ: e.typ
		contains_agg: false
	}
}

union InternalValue {
mut:
	// BOOLEAN
	bool_value Boolean
	// DOUBLE PRECISION and REAL
	f64_value f64
	// BIGINT, INTEGER and SMALLINT
	int_value i64
	// CHARACTER VARYING(n) and CHARACTER(n)
	// NUMERIC
	string_value string
	// DATE
	// TIME(n) WITH TIME ZONE and TIME(n) WITHOUT TIME ZONE
	// TIMESTAMP(n) WITH TIME ZONE and TIMESTAMP(n) WITHOUT TIME ZONE
	time_value Time
	// DECIMAL(n,m)
	// NUMERIC(n,m)
	numeric_value Numeric
}

// new_null_value creates a NULL value of a specific type. In SQL, all NULL
// values need to have a type.
pub fn new_null_value(typ SQLType) Value {
	return Value{
		typ: Type{typ, 0, 0, false}
		is_null: true
	}
}

// new_boolean_value creates a ``TRUE`` or ``FALSE`` value. For ``UNKNOWN`` (the
// ``BOOLEAN`` equivilent of NULL) you will need to use ``new_unknown_value``.
pub fn new_boolean_value(b bool) Value {
	return Value{
		typ: Type{.is_boolean, 0, 0, false}
		v: InternalValue{
			bool_value: if b { .is_true } else { .is_false }
		}
	}
}

// new_unknown_value returns an ``UNKNOWN`` value. This is the ``NULL``
// representation of ``BOOLEAN``.
pub fn new_unknown_value() Value {
	return Value{
		typ: Type{.is_boolean, 0, 0, false}
		is_null: true
	}
}

// new_double_precision_value creates a ``DOUBLE PRECISION`` value.
pub fn new_double_precision_value(x f64) Value {
	return Value{
		typ: Type{.is_double_precision, 0, 0, false}
		v: InternalValue{
			f64_value: x
		}
	}
}

// new_integer_value creates an ``INTEGER`` value.
pub fn new_integer_value(x int) Value {
	return Value{
		typ: Type{.is_integer, 0, 0, false}
		v: InternalValue{
			int_value: x
		}
	}
}

// new_bigint_value creates a ``BIGINT`` value.
pub fn new_bigint_value(x i64) Value {
	return Value{
		typ: Type{.is_bigint, 0, 0, false}
		v: InternalValue{
			int_value: x
		}
	}
}

// new_real_value creates a ``REAL`` value.
pub fn new_real_value(x f32) Value {
	return Value{
		typ: Type{.is_real, 0, 0, false}
		v: InternalValue{
			f64_value: x
		}
	}
}

// new_smallint_value creates a ``SMALLINT`` value.
pub fn new_smallint_value(x i16) Value {
	return Value{
		typ: Type{.is_smallint, 0, 0, false}
		v: InternalValue{
			int_value: x
		}
	}
}

// new_varchar_value creates a ``CHARACTER VARYING`` value.
pub fn new_varchar_value(x string) Value {
	return Value{
		typ: Type{.is_varchar, x.len, 0, false}
		v: InternalValue{
			string_value: x
		}
	}
}

// new_character_value creates a ``CHARACTER`` value. The size is determined
// from the length of the string itself.
pub fn new_character_value(x string) Value {
	return Value{
		typ: Type{.is_character, x.len, 0, false}
		v: InternalValue{
			string_value: x
		}
	}
}

// new_numeric_value expects a value to be valid and the size and scale are
// determined from the value as:
//
//   123     -> NUMERIC(3, 0)
//   123.    -> NUMERIC(3, 0)
//   1.23    -> NUMERIC(3, 2)
//   -1.23   -> NUMERIC(3, 2)
//   12.00   -> NUMERIC(4, 2)
//
pub fn new_numeric_value(x string) Value {
	n := new_numeric_from_string(x)

	return Value{
		typ: n.typ
		v: InternalValue{
			numeric_value: n.normalize_denominator(n.typ)
		}
	}
}

// new_decimal_value expects a value to be valid and the size and scale are
// determined from the value as:
//
//   123     -> DECIMAL(3, 0)
//   123.    -> DECIMAL(3, 0)
//   1.23    -> DECIMAL(3, 2)
//   -1.23   -> DECIMAL(3, 2)
//   12.00   -> DECIMAL(4, 2)
//
pub fn new_decimal_value(x string) Value {
	// All the same rules for determining NUMERIC can be used for DECIMAL,
	// including denoninator being a power of 10. We just need to change it to a
	// DECIMAL type.
	n := new_numeric_from_string(x)
	typ := new_type('DECIMAL', n.typ.size, n.typ.scale)

	return Value{
		typ: typ
		v: InternalValue{
			numeric_value: n.normalize_denominator(typ)
		}
	}
}

fn new_numeric_value_from_numeric(n Numeric) Value {
	return Value{
		typ: n.typ
		v: InternalValue{
			numeric_value: n.normalize_denominator(n.typ)
		}
	}
}

fn new_decimal_value_from_numeric(n Numeric) Value {
	typ := new_type('DECIMAL', n.typ.size, n.typ.scale)

	return Value{
		typ: typ
		v: InternalValue{
			numeric_value: n.normalize_denominator(n.typ)
		}
	}
}

// new_timestamp_value creates a ``TIMESTAMP`` value.
pub fn new_timestamp_value(ts string) !Value {
	t := new_timestamp_from_string(ts)!

	return Value{
		typ: t.typ
		v: InternalValue{
			time_value: t
		}
	}
}

// new_time_value creates a ``TIME`` value.
pub fn new_time_value(ts string) !Value {
	t := new_time_from_string(ts)!

	return Value{
		typ: t.typ
		v: InternalValue{
			time_value: t
		}
	}
}

// new_date_value creates a ``DATE`` value.
pub fn new_date_value(ts string) !Value {
	t := new_date_from_string(ts)!

	return Value{
		typ: t.typ
		v: InternalValue{
			time_value: t
		}
	}
}

fn f64_string(x f64, bits i16) string {
	mut s := if bits == 32 { '${x:.6}' } else { '${x:.12}' }

	if s.contains('e') {
		if s.contains('.') {
			parts := s.split('e')
			s = parts[0].trim_right('0') + 'e' + parts[1]
		}
	} else {
		if s.contains('.') {
			s = s.trim_right('0')
		}
		s += 'e0'
	}

	return s
}

// as_int() is not safe to use if the value is not numeric. It is used in cases
// where a placeholder might be anything but needs to be an int (such as for an
// OFFSET).
fn (v Value) as_int() i64 {
	if v.typ.typ == .is_numeric {
		return i64(v.numeric_value().f64())
	}

	if v.typ.uses_int() {
		return v.int_value()
	}

	return i64(v.f64_value())
}

fn (v Value) as_f64() !f64 {
	if v.typ.typ == .is_boolean {
		// See the notes below about sqlstate_22003().
		return sqlstate_22003()
	}

	if v.typ.typ == .is_character || v.typ.typ == .is_varchar {
		s := v.string_value()

		mut re := regex.regex_opt(r'^\d+(\.\d+)?$') or {
			return error('cannot compile regex for number: ${err}')
		}
		if !re.matches_string(s) {
			// This sounds a little counterintuitive, but the SQL standard says this
			// situation must be classified as "data exception — numeric value out of
			// range". See cast().
			return sqlstate_22003()
		}

		return s.f64()
	}

	if v.typ.typ == .is_numeric {
		// This will always be valid because the SQL parser wouldn't allow it
		// otherwise.
		return v.numeric_value().f64()
	}

	if v.typ.uses_int() {
		return v.int_value()
	}

	return v.f64_value()
}

fn (v Value) as_numeric() !Numeric {
	if v.typ.typ == .is_boolean {
		return sqlstate_22003()
	}

	if v.typ.typ == .is_numeric {
		return v.numeric_value()
	}

	s := v.str()
	if s.contains('e') {
		// This covers the approximate to exact number conversion.
		return new_numeric_from_f64(v.as_f64()!)
	}

	return new_numeric_from_string(s)
}

fn (v Value) pstr(params map[string]Value) string {
	if v.typ.typ != .is_numeric && (v.typ.uses_string() || v.typ.uses_time()) {
		return '\'${v.str()}\''
	}

	return v.str()
}

// The string representation of this value. Different types will have different
// formatting.
pub fn (v Value) str() string {
	if v.is_null {
		return if v.typ.typ == .is_boolean { 'UNKNOWN' } else { 'NULL' }
	}

	return match v.typ.typ {
		.is_boolean {
			v.bool_value().str()
		}
		.is_double_precision {
			f64_string(v.f64_value(), 64)
		}
		.is_real {
			f64_string(v.f64_value(), 32)
		}
		.is_bigint, .is_integer, .is_smallint {
			v.int_value().str()
		}
		.is_varchar, .is_character {
			v.string_value()
		}
		.is_date, .is_time_with_time_zone, .is_time_without_time_zone,
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
			v.time_value().str()
		}
		.is_decimal, .is_numeric {
			v.numeric_value().str()
		}
	}
}

pub fn (v Value) bool_value() Boolean {
	unsafe {
		return v.v.bool_value
	}
}

pub fn (v Value) int_value() i64 {
	unsafe {
		return v.v.int_value
	}
}

pub fn (v Value) f64_value() f64 {
	unsafe {
		return v.v.f64_value
	}
}

pub fn (v Value) string_value() string {
	unsafe {
		return v.v.string_value
	}
}

pub fn (v Value) time_value() Time {
	unsafe {
		return v.v.time_value
	}
}

pub fn (v Value) numeric_value() Numeric {
	unsafe {
		return v.v.numeric_value
	}
}
