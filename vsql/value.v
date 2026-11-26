// value.v allows values of differnet types to be stored and dealt with at
// runtime and for storage. The Value object is used extensively internally, but
// also is the exposed type when sending results back.

module vsql

import math

// The concept is described by ISO/IEC 9075-1:2023, 4.6.2, Null value.

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
	// is_large is true for a string that's stored outside of its row, see
	// LargeValue.
	is_large bool
pub:
	// The type of this Value.
	typ Type
	// Used by all types (including those that have NULL built in like BOOLEAN).
	is_null bool
	// v packs the actual value. You need to use one of the methods to get the
	// actual value safely.
	v InternalValue
}

fn (e Value) compile(mut _ Compiler) !CompileResult {
	// A pointer to a copy is captured instead of the value to work around
	// https://github.com/vlang/v/issues/32934 (-autofree).
	e_ref := &Value{
		...e
	}
	return CompileResult{
		run:          fn [e_ref] (mut conn Connection, data Row, params map[string]Value) !Value {
			return *e_ref
		}
		typ:          e.typ
		contains_agg: false
		constant:     true
	}
}

union InternalValue {
mut:
	// BOOLEAN, a Boolean. It's a u8 rather than a Boolean so that a NULL (which
	// doesn't set any field of the union) has 0, which isn't TRUE or FALSE. V
	// sets an enum field of a union that isn't set to its first value (FALSE).
	bool_value u8
	// DOUBLE PRECISION and REAL
	f64_value f64
	// BIGINT, INTEGER and SMALLINT
	// INTERVAL: a number of months (year-month) or microseconds (day-time)
	int_value i64
	// CHARACTER VARYING(n), CHARACTER(n) and CHARACTER LARGE OBJECT(n)
	// BINARY(n), BINARY VARYING(n) and BINARY LARGE OBJECT(n) (each byte of the
	// string is an octet), see box_string.
	//
	// The string is behind a pointer because -autofree frees a string in a
	// union whichever field is set:
	// https://github.com/vlang/v/issues/32933
	string_value voidptr
	// DATE
	// TIME(n) WITH TIME ZONE and TIME(n) WITHOUT TIME ZONE
	// TIMESTAMP(n) WITH TIME ZONE and TIMESTAMP(n) WITHOUT TIME ZONE
	//
	// Time and Numeric are much larger than the other values, so they are kept
	// behind a pointer (see box_time and box_numeric) to keep every Value small.
	time_value voidptr
	// DECIMAL(n,m)
	// NUMERIC(n,m)
	numeric_value voidptr
	// DECFLOAT(p), see box_decfloat.
	decfloat_value voidptr
	// A string that's stored outside of its row (when Value.is_large), see
	// LargeValue.
	large_value voidptr
}

// StringBox holds the string of a Value, see box_string.
struct StringBox {
	s string
}

// own_string is a copy of s with -autofree, and s without it. It's for a
// string that's borrowed (such as a field of a parameter) but put into a value
// that the caller frees. -autofree doesn't copy it, so it frees the original
// (https://github.com/vlang/v/issues/32932). It's also used for a variable
// that's reassigned (https://github.com/vlang/v/issues/32944). The garbage
// collector doesn't need the copy.
fn own_string(s string) string {
	$if autofree {
		return s.clone()
	}
	return s
}

// map_value is the value of key in m (a copy), or none. It's used instead of
// "m[key] or { ... }", which -autofree doesn't copy, so the caller frees the
// value that's still in m (https://github.com/vlang/v/issues/32937).
@[manualfree]
fn map_value[K, V](m map[K]V, key K) ?V {
	if key in m {
		v := m[key]
		$if autofree {
			return own_copy(&v)
		}
		return v
	}
	return none
}

// own_elem is a[i], which is a copy with -autofree. "x := a[i]" isn't a copy,
// so -autofree frees the element when x is freed
// (https://github.com/vlang/v/issues/32949).
@[inline]
fn own_elem[T](a []T, i int) T {
	$if autofree {
		return own_copy(unsafe { &a[i] })
	}
	return a[i]
}

// opt_copy is o. "if x := o { ... }" on a local option moves its value out
// with -autofree, so o is none afterwards
// (https://github.com/vlang/v/issues/32951). "if x := opt_copy(o) { ... }"
// leaves o as it is. The same happens to a field of a mut receiver.
@[inline]
fn opt_copy[T](o ?T) ?T {
	return o
}

// heap_copy is a copy of *v on the heap, which is a deep copy (see own_copy)
// with -autofree. It's used instead of &v for a parameter v that's kept, since
// the caller frees v with -autofree (https://github.com/vlang/v/issues/32943).
fn heap_copy[T](v &T) &T {
	mut p := unsafe { &T(voidptr(vcalloc(int(sizeof(T))))) }
	$if autofree {
		unsafe {
			*p = own_copy(v)
		}
	} $else {
		unsafe {
			*p = *v
		}
	}
	return p
}

// own_array is a copy of a with -autofree, and a without it, like own_string.
fn own_array[T](a []T) []T {
	$if autofree {
		return a.clone()
	}
	return a
}

// box_string is s on the heap, for InternalValue.string_value.
fn box_string(s string) voidptr {
	// -autofree can't see that s is kept by the box, so the caller would free
	// it.
	return voidptr(&StringBox{own_string(s)})
}

// box_time is t on the heap, for InternalValue.time_value.
fn box_time(t Time) voidptr {
	return voidptr(&Time{
		...t
	})
}

// box_numeric is n on the heap, for InternalValue.numeric_value.
fn box_numeric(n Numeric) voidptr {
	// The integers are copied with -autofree, see own_integer.
	return voidptr(&Numeric{
		typ:         n.typ
		numerator:   own_integer(n.numerator)
		denominator: own_integer(n.denominator)
	})
}

// new_null_value creates a NULL value of a specific type. In SQL, all NULL
// values need to have a type.
pub fn new_null_value(typ SQLType) Value {
	return Value{
		typ:     Type{typ, 0, 0, false, false}
		is_null: true
	}
}

// with_type returns the value with a different declared type, such as the type
// of the expression that produced it. The value itself isn't converted.
fn (v Value) with_type(typ Type) Value {
	return Value{
		...v
		typ: typ
	}
}

// new_boolean_value creates a ``TRUE`` or ``FALSE`` value. For ``UNKNOWN`` (the
// ``BOOLEAN`` equivilent of NULL) you will need to use ``new_unknown_value``.
// It's also the value of a <boolean literal>, which is a BOOLEAN.
//
// ISO/IEC 9075-2:2023, 5.3, <literal>, Syntax Rules, 47
pub fn new_boolean_value(b bool) Value {
	return Value{
		typ: Type{.is_boolean, 0, 0, false, false}
		v:   InternalValue{
			bool_value: u8(if b { Boolean.is_true } else { Boolean.is_false })
		}
	}
}

// new_unknown_value returns an ``UNKNOWN`` value. This is the ``NULL``
// representation of ``BOOLEAN``.
pub fn new_unknown_value() Value {
	return Value{
		typ:     Type{.is_boolean, 0, 0, false, false}
		is_null: true
	}
}

// new_double_precision_value creates a ``DOUBLE PRECISION`` value.
pub fn new_double_precision_value(x f64) Value {
	return Value{
		typ: Type{.is_double_precision, 0, 0, false, false}
		v:   InternalValue{
			f64_value: x
		}
	}
}

// new_integer_value creates an ``INTEGER`` value.
pub fn new_integer_value(x int) Value {
	return Value{
		typ: Type{.is_integer, 0, 0, false, false}
		v:   InternalValue{
			int_value: x
		}
	}
}

// new_bigint_value creates a ``BIGINT`` value.
pub fn new_bigint_value(x i64) Value {
	return Value{
		typ: Type{.is_bigint, 0, 0, false, false}
		v:   InternalValue{
			int_value: x
		}
	}
}

// approximate_value is a DOUBLE PRECISION or REAL from the result of a
// calculation. Infinity isn't an SQL value, so a result that's too large for the
// type raises 22003 (numeric value out of range). A REAL that's too small
// becomes zero when it's converted from x, which also raises 22003. The caller
// needs to check for a DOUBLE PRECISION that's too small, since x is already
// zero (see approximate_nonzero_value).
//
// ISO/IEC 9075-2:2023, 6.30, <numeric value expression>, General Rules, 6
fn approximate_value(x f64, typ SQLType) !Value {
	if typ == .is_real {
		if math.is_inf(f32(x), 0) || (x != 0 && f32(x) == 0) {
			return sqlstate_22003()
		}

		return new_real_value(f32(x))
	}

	if math.is_inf(x, 0) {
		return sqlstate_22003()
	}

	return new_double_precision_value(x)
}

// approximate_nonzero_value is approximate_value for a calculation where the
// exact result isn't zero, so x is only zero if the result is too small for the
// type. A denormal is still in the range.
//
// ISO/IEC 9075-2:2023, 6.30, <numeric value expression>, General Rules, 6
fn approximate_nonzero_value(x f64, typ SQLType) !Value {
	if x == 0 {
		return sqlstate_22003()
	}

	return approximate_value(x, typ)
}

// new_real_value creates a ``REAL`` value.
pub fn new_real_value(x f32) Value {
	return Value{
		typ: Type{.is_real, 0, 0, false, false}
		v:   InternalValue{
			f64_value: x
		}
	}
}

// new_smallint_value creates a ``SMALLINT`` value.
pub fn new_smallint_value(x i16) Value {
	return Value{
		typ: Type{.is_smallint, 0, 0, false, false}
		v:   InternalValue{
			int_value: x
		}
	}
}

// new_varchar_value creates a ``CHARACTER VARYING`` value.
pub fn new_varchar_value(x string) Value {
	return Value{
		typ: Type{.is_varchar, x.len_utf8(), 0, false, false}
		v:   InternalValue{
			string_value: box_string(x)
		}
	}
}

// new_character_value creates a ``CHARACTER`` value. The size is determined
// from the length of the string itself, in characters (not bytes).
pub fn new_character_value(x string) Value {
	return Value{
		typ: Type{.is_character, x.len_utf8(), 0, false, false}
		v:   InternalValue{
			string_value: box_string(x)
		}
	}
}

// new_clob_value creates a ``CHARACTER LARGE OBJECT`` value.
pub fn new_clob_value(x string) Value {
	return Value{
		typ: Type{.is_clob, x.len_utf8(), 0, false, false}
		v:   InternalValue{
			string_value: box_string(x)
		}
	}
}

// new_binary_value creates a ``BINARY`` value of the octets of x. The size is
// the number of octets.
pub fn new_binary_value(x []u8) Value {
	return new_binary_string_value(.is_binary, x.bytestr())
}

// new_binary_string_value is a BINARY, BINARY VARYING or BINARY LARGE OBJECT
// of the octets of x.
fn new_binary_string_value(typ SQLType, x string) Value {
	return Value{
		typ: Type{typ, x.len, 0, false, false}
		v:   InternalValue{
			string_value: box_string(x)
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
		v:   InternalValue{
			numeric_value: box_numeric(n.normalize_denominator(n.typ))
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
	n := new_numeric_from_string(x)
	typ := new_type('DECIMAL', n.typ.size, n.typ.scale)

	return Value{
		typ: typ
		v:   InternalValue{
			numeric_value: box_numeric(n.normalize_denominator(typ))
		}
	}
}

fn new_numeric_value_from_numeric(n Numeric) Value {
	return Value{
		typ: n.typ
		v:   InternalValue{
			numeric_value: box_numeric(n.normalize_denominator(n.typ))
		}
	}
}

fn new_decimal_value_from_numeric(n Numeric) Value {
	typ := new_type('DECIMAL', n.typ.size, n.typ.scale)

	return Value{
		typ: typ
		v:   InternalValue{
			numeric_value: box_numeric(n.normalize_denominator(n.typ))
		}
	}
}

// new_timestamp_value creates a ``TIMESTAMP`` value.
pub fn new_timestamp_value(ts string) !Value {
	t := new_timestamp_from_string(ts)!

	return Value{
		typ: t.typ
		v:   InternalValue{
			time_value: box_time(t)
		}
	}
}

// new_time_value creates a ``TIME`` value.
pub fn new_time_value(ts string) !Value {
	t := new_time_from_string(ts)!

	return Value{
		typ: t.typ
		v:   InternalValue{
			time_value: box_time(t)
		}
	}
}

// new_date_value creates a ``DATE`` value.
pub fn new_date_value(ts string) !Value {
	t := new_date_from_string(ts)!

	return Value{
		typ: t.typ
		v:   InternalValue{
			time_value: box_time(t)
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
	if v.typ.typ == .is_numeric || v.typ.typ == .is_decimal {
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

	if v.typ.typ == .is_numeric || v.typ.typ == .is_decimal {
		// This will always be valid because the SQL parser wouldn't allow it
		// otherwise.
		return v.numeric_value().f64()
	}

	if v.typ.typ == .is_decfloat {
		return v.decfloat_value().str().f64()
	}

	if v.typ.uses_int() {
		return f64(v.int_value())
	}

	return v.f64_value()
}

fn (v Value) as_numeric() !Numeric {
	if v.typ.typ == .is_boolean {
		return sqlstate_22003()
	}

	if v.typ.typ == .is_numeric || v.typ.typ == .is_decimal {
		return v.numeric_value()
	}

	if v.typ.typ == .is_decfloat {
		return new_numeric_from_string(v.decfloat_value().exact_str())
	}

	s := v.str()
	if s.contains('e') {
		// This covers the approximate to exact number conversion.
		return new_numeric_from_f64(v.as_f64()!)
	}

	return new_numeric_from_string(s)
}

fn (v Value) pstr(_ map[string]Value) string {
	// A datetime is shown as a literal, such as DATE '2022-06-30', rather than a
	// character string.
	if v.typ.typ.is_datetime() && !v.is_null {
		return v.time_value().str_literal()
	}

	if v.typ.typ.is_binary_string() || v.typ.typ.is_interval() || v.typ.typ == .is_decfloat {
		return v.literal()
	}

	if v.typ.typ != .is_numeric && (v.typ.uses_string() || v.typ.uses_time()) {
		return "'${v.str().replace("'", "''")}'"
	}

	return v.str()
}

// literal returns the value as an SQL literal that results in the same value
// when it's used in a statement, such as 'it''s' or DATE '2022-06-30'.
pub fn (v Value) literal() string {
	if v.is_null {
		return 'NULL'
	}

	return match v.typ.typ {
		// The shortest representation that converts back to the same value. It must
		// contain an exponent to be an approximate numeric literal.
		.is_double_precision {
			approximate_numeric_literal(v.f64_value().str())
		}
		.is_real {
			approximate_numeric_literal(f32(v.f64_value()).str())
		}
		.is_varchar, .is_character {
			"'${v.string_value().replace("'", "''")}'"
		}
		.is_date, .is_time_with_time_zone, .is_time_without_time_zone,
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
			v.time_value().str_literal()
		}
		.is_boolean, .is_bigint, .is_integer, .is_smallint, .is_decimal, .is_numeric {
			v.str()
		}
		// A <character string literal> and a <binary string literal> are a
		// CHARACTER and a BINARY, but they can be assigned to any character or
		// binary string type.
		.is_clob {
			"'${v.string_value().replace("'", "''")}'"
		}
		.is_binary, .is_varbinary, .is_blob {
			"X'${v.str()}'"
		}
		// There's no DECFLOAT literal, so it's a character string cast to a
		// DECFLOAT, which keeps every digit and the exponent.
		.is_decfloat {
			"CAST('${v.str()}' AS DECFLOAT(${v.typ.size}))"
		}
		.is_interval_year_month, .is_interval_day_time {
			"INTERVAL '${v.str()}' ${v.typ.interval_qualifier()}"
		}
	}
}

fn approximate_numeric_literal(s string) string {
	return if s.contains('e') { own_string(s) } else { s + 'e0' }
}

// The string representation of this value. Different types will have different
// formatting. The null value is NULL (or UNKNOWN for a BOOLEAN), which is how
// "vsql cli" shows it.
pub fn (v Value) str() string {
	// ISO/IEC 9075-2:2023, 22.1, <direct SQL statement>
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
			// Trailing zeros up to the scale are part of the value, so 12.00 isn't
			// shown as 12.
			//
			// ISO/IEC 9075-2:2023, 6.13, <cast specification>, General Rules, 11.a.i
			v.numeric_value().str()
		}
		.is_clob {
			v.string_value()
		}
		// A binary string is shown as the hexadecimal digits of each octet, like
		// a <binary string literal>.
		.is_binary, .is_varbinary, .is_blob {
			v.string_value().bytes().hex().to_upper()
		}
		.is_decfloat {
			v.decfloat_value().str()
		}
		.is_interval_year_month, .is_interval_day_time {
			interval_string(v.typ, v.int_value())
		}
	}
}

pub fn (v Value) bool_value() Boolean {
	unsafe {
		return Boolean(v.v.bool_value)
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

// string_value is the value of a character string or binary string. A large
// value (see LargeValue) is read the first time, and is empty if it can't be
// read, such as when the row was changed by another transaction that committed
// before it was read. Row.get_string and Row.get_lob return that error instead.
pub fn (v Value) string_value() string {
	if v.is_large {
		mut lv := v.large_value()
		return own_string(lv.load() or { '' })
	}

	// A NULL has the empty string.
	p := unsafe { v.v.string_value }
	if isnil(p) {
		return ''
	}

	// The copy works around https://github.com/vlang/v/issues/32932
	// (-autofree): the caller would free the value's string.
	return own_string(unsafe { (&StringBox(p)).s })
}

pub fn (v Value) time_value() Time {
	// A NULL has the zero Time.
	p := unsafe { v.v.time_value }
	return if isnil(p) { Time{} } else { unsafe { *(&Time(p)) } }
}

fn (v Value) decfloat_value() DecFloat {
	// A NULL has the zero DecFloat.
	p := unsafe { v.v.decfloat_value }
	if isnil(p) {
		return DecFloat{}
	}

	// The caller gets its own coefficient with -autofree, see own_integer.
	d := unsafe { &DecFloat(p) }
	return DecFloat{own_integer(d.coefficient), d.exponent}
}

pub fn (v Value) numeric_value() Numeric {
	// A NULL has the zero Numeric.
	p := unsafe { v.v.numeric_value }
	if isnil(p) {
		return Numeric{}
	}

	// The caller gets its own integers with -autofree, see own_integer.
	n := unsafe { &Numeric(p) }
	return Numeric{n.typ, own_integer(n.numerator), own_integer(n.denominator)}
}
