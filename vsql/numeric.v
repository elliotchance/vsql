// numeric.v contains the implementation and operations for the DECIMAL and
// NUMERIC types.

module vsql

import math.big

// The concept is described by ISO/IEC 9075-1:2003(E), 4.4.3.1, Numeric types.

// These are used for encoding certain aspects for storage. 1 << 0 was for a
// NULL, which is never stored as a Numeric (see Value.is_null).
const numeric_is_zero = u8(1 << 1)
const numeric_is_negative = u8(1 << 2)

struct Numeric {
	// typ contains the precision and scale that affect calculations.
	typ Type
	// numerator contains the sign (+/-) and may be zero, however, you should
	// always test the denominator for an actual zero.
	numerator big.Integer
	// denominator will not be negative. It may be zero to represent a zero value.
	denominator big.Integer
}

fn new_numeric(typ Type, numerator big.Integer, denominator big.Integer) Numeric {
	return Numeric{
		typ:         typ
		numerator:   numerator
		denominator: denominator
	}
}

// new_numeric_from_f64 is the exact value of the shortest decimal that is x,
// such as 0.000015 for 1.5e-5.
fn new_numeric_from_f64(x f64) Numeric {
	return new_numeric_from_string(x.strlong())
}

// NOTE: numeric value is expected to be well formed.
fn new_numeric_from_string(x string) Numeric {
	// The scale of an exact numeric literal is the number of digits after the
	// period, and its type must hold the value exactly (ISO/IEC 9075-2:2016(E),
	// 5.3, <literal>, Syntax Rules, 22).

	if x.contains('e') || x.contains('E') {
		return new_numeric_from_f64(x.f64())
	}

	mut n := x

	is_negative := n[0] == `-`
	if is_negative {
		n = n[1..]
	}

	mut size := 1
	mut scale := i16(0)

	parts := n.split('.')
	if parts.len == 1 {
		size = parts[0].len
	} else {
		size = parts[0].len + parts[1].len
		scale = i16(parts[1].len)
	}

	mut numerator := big.integer_from_string(parts[0]) or { big.zero_int }
	mut denominator := big.one_int

	if parts.len == 2 {
		denominator = big.integer_from_int(10).pow(u32(parts[1].len))
		numerator *= denominator
		numerator += big.integer_from_string(parts[1]) or { big.zero_int }
	}

	if is_negative {
		numerator = numerator.neg()
	}

	typ := Type{.is_numeric, size, scale, false}
	return new_numeric(typ, numerator, denominator)
}

fn (n Numeric) bytes() []u8 {
	mut buf := new_bytes([]u8{})
	mut flags := u8(0)
	if n.is_zero() {
		flags |= numeric_is_zero
	}
	if n.is_negative() {
		flags |= numeric_is_negative
	}
	buf.write_u8(flags)

	// If the value is 0 we don't need to encode anything further.
	if flags & numeric_is_zero != 0 {
		return buf.bytes()
	}

	numerator, _ := n.numerator.bytes()
	buf.write_i16(i16(numerator.len))
	buf.write_u8s(numerator)

	denominator, _ := n.denominator.bytes()
	buf.write_i16(i16(denominator.len))
	buf.write_u8s(denominator)

	return buf.bytes()
}

fn new_numeric_from_bytes(typ Type, data []u8) Numeric {
	mut buf := new_bytes(data)
	flags := buf.read_u8()

	if flags & numeric_is_zero != 0 {
		return new_numeric(typ, big.zero_int, big.integer_from_int(10).pow(u32(typ.scale)))
	}

	numerator_len := buf.read_i16()
	mut numerator := big.integer_from_bytes(buf.read_u8s(numerator_len), big.IntegerConfig{})

	denominator_len := buf.read_i16()
	denominator := big.integer_from_bytes(buf.read_u8s(denominator_len), big.IntegerConfig{})

	if flags & numeric_is_negative != 0 {
		numerator = numerator.neg()
	}

	return new_numeric(typ, numerator, denominator)
}

fn (n Numeric) str() string {
	denominator := big.integer_from_int(10).pow(u32(n.typ.scale))
	denominator_str := denominator.str()
	mut numerator := n.scale_numerator(denominator).numerator.str()

	// Remove the negative, this messes with length offsets.
	if n.is_negative() {
		numerator = numerator[1..]
	}

	mut s := if numerator.str().len >= denominator_str.len {
		numerator[..numerator.len - denominator_str.len + 1] + '.' + numerator[numerator.len -
			denominator_str.len + 1..]
	} else {
		'0.' + '0'.repeat(denominator_str.len - numerator.len - 1) + numerator.str()
	}

	if n.is_negative() {
		s = '-' + s
	}

	// This trims off the extra digit from above. We also need to remove a
	// possible trailing '.'.
	return s.trim_right('.')
}

fn (n Numeric) neg() Numeric {
	return new_numeric(n.typ, big.zero_int - n.numerator, n.denominator)
}

fn (n Numeric) f64() f64 {
	return n.numerator.str().f64() / n.denominator.str().f64()
}

fn (n Numeric) add(n2 Numeric) Numeric {
	typ := exact_arithmetic_type(n.typ, n2.typ, '+')
	a, b := common_denominator(n, n2)
	x := new_numeric(typ, a.numerator + b.numerator, a.denominator)
	return x.normalize_denominator(typ)
}

fn (n Numeric) subtract(n2 Numeric) Numeric {
	typ := exact_arithmetic_type(n.typ, n2.typ, '-')
	a, b := common_denominator(n, n2)
	x := new_numeric(typ, a.numerator - b.numerator, a.denominator)
	return x.normalize_denominator(typ)
}

fn (n Numeric) multiply(n2 Numeric) Numeric {
	typ := exact_arithmetic_type(n.typ, n2.typ, '*')
	x := new_numeric(typ, n.numerator * n2.numerator, n.denominator * n2.denominator)
	return x.normalize_denominator(typ)
}

fn (n Numeric) divide(n2 Numeric) !Numeric {
	if n2.is_zero() {
		return sqlstate_22012() // division by zero
	}

	return n.multiply(n2.reciprocal())
}

// check_numeric_precision returns n, or an error if its integer part has more
// digits than its type can hold. The type of an arithmetic result is limited to
// the maximum precision, see exact_arithmetic_type.
//
// ISO/IEC 9075-2:2016(E), 6.29, <numeric value expression>, General Rules, 5
fn check_numeric_precision(n Numeric) !Numeric {
	integer := n.integer().str().trim_left('-')
	digits := if integer == '0' { 0 } else { integer.len }
	if digits > n.typ.numeric_precision() - n.typ.scale {
		return sqlstate_22003() // numeric value out of range
	}

	return n
}

fn (n Numeric) is_zero() bool {
	return n.numerator == big.zero_int
}

fn (n Numeric) is_negative() bool {
	return n.numerator.signum == -1
}

// scale_numerator will return a new Numeric with a numerator that has been
// scaled (larger or smaller) to match the denominator. Where denominator is
// expected to be 10^x.
fn (n Numeric) scale_numerator(denominator big.Integer) Numeric {
	// Multiplying before dividing means that only the digits that don't fit are
	// lost, for example 187/90 (~2.0777) -> (187*100)/90 = 207 -> 207/100.
	numerator := (n.numerator * denominator) / n.denominator

	return new_numeric(n.typ, numerator, denominator)
}

// This is an important step for NUMERIC and DECIMAL after every operation to
// make sure the denominator is scaled correctly, which may cause the value to
// lose precision if it goes beyond the specified precision.
fn (n Numeric) normalize_denominator(typ Type) Numeric {
	denominator := big.integer_from_int(10).pow(u32(typ.scale))
	max_denominator := big.integer_from_int(10).pow(u32(typ.scale + 1)) - big.one_int

	// DECIMAL only need to scale when the denominator goes beyond the bounds.
	if typ.typ == .is_decimal && n.denominator > max_denominator {
		return n.scale_numerator(denominator)
	}

	// NUMERIC always needs to have a fixed denominator.
	if typ.typ == .is_numeric && n.denominator != denominator {
		return n.scale_numerator(denominator)
	}

	// No scaling needed. Avoid any unnecessary math.
	return n
}

fn common_denominator(n1 Numeric, n2 Numeric) (Numeric, Numeric) {
	if n1.denominator == n2.denominator {
		return n1, n2
	}

	// Pick the highest scale for the result.
	typ := if n1.typ.scale > n2.typ.scale { n1.typ } else { n2.typ }

	n3 := new_numeric(typ, n1.numerator * n2.denominator, n1.denominator * n2.denominator)
	n4 := new_numeric(typ, n2.numerator * n1.denominator, n2.denominator * n1.denominator)

	return n3, n4
}

fn (n Numeric) compare(n2 Numeric) CompareResult {
	n3, n4 := common_denominator(n, n2)

	if n3.numerator < n4.numerator {
		return .is_less
	}

	if n3.numerator > n4.numerator {
		return .is_greater
	}

	return .is_equal
}

fn (n Numeric) equals(n2 Numeric) bool {
	n3, n4 := common_denominator(n, n2)

	return n3.numerator == n4.numerator
}

fn (n Numeric) less_than(n2 Numeric) bool {
	n3, n4 := common_denominator(n, n2)

	return n3.numerator < n4.numerator
}

fn (n Numeric) greater_than(n2 Numeric) bool {
	n3, n4 := common_denominator(n, n2)

	return n3.numerator > n4.numerator
}

fn (n Numeric) i64() i64 {
	return big_integer_to_i64(n.integer())
}

// big_integer_to_i64 converts an integer that is known to fit into an i64.
// big.Integer.int() can't be used because it only returns 32 bits.
fn big_integer_to_i64(n big.Integer) i64 {
	return n.str().i64()
}

fn (n Numeric) integer() big.Integer {
	return n.numerator / n.denominator
}

fn (n Numeric) reciprocal() Numeric {
	return new_numeric(n.typ, n.denominator, n.numerator)
}

fn (n Numeric) trunc() Numeric {
	// TODO(elliotchance): I'm sure this is not the most efficient way to do this.
	// Please improve.
	return new_numeric_from_string(n.str().split('.')[0])
}
