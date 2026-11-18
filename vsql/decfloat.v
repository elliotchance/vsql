// decfloat.v contains the implementation of the DECFLOAT type.

module vsql

import math.big

// The concepts are described by:
//
// ISO/IEC 9075-1:2023, 4.6.3.1, Numeric types
// ISO/IEC 9075-2:2023, 4.5.2, Characteristics of numbers

// The precision of a DECFLOAT is one of two implementation-defined values,
// like the IEEE 754 decimal64 and decimal128 formats. A DECFLOAT without a
// precision has the larger one.
//
// ISO/IEC 9075-2:2023, 6.1, <data type>, Syntax Rules, 22 and 23
const decfloat_small_precision = 16
const max_decfloat_precision = 34

// decfloat_max_exponent is the largest adjusted exponent (the exponent of the
// first significant digit) of a DECFLOAT with the precision p, and the smallest
// is 1 - decfloat_max_exponent(p). These are the limits of decimal64 and
// decimal128.
//
// ISO/IEC 9075-2:2023, 6.1, <data type>, Syntax Rules, 36
fn decfloat_max_exponent(p int) int {
	return if p == decfloat_small_precision { 384 } else { 6144 }
}

// new_decfloat_type is a DECFLOAT(p), which has a decimal precision of p
// digits. p must be one of the precisions that a DECFLOAT can have.
//
// ISO/IEC 9075-2:2023, 6.1, <data type>, Syntax Rules, 23 and 35
fn new_decfloat_type(p int) !Type {
	if p != decfloat_small_precision && p != max_decfloat_precision {
		return sqlstate_42601('DECFLOAT precision must be ${decfloat_small_precision} or ${max_decfloat_precision}')
	}

	return Type{.is_decfloat, p, 0, false, false}
}

// DecFloat is a decimal floating-point number: coefficient * 10^exponent. The
// trailing zeros of the coefficient are kept, so 1.50 is 150 * 10^-2 and 1.5 is
// 15 * 10^-1.
struct DecFloat {
	coefficient big.Integer
	exponent    int
}

// box_decfloat is d on the heap, for InternalValue.decfloat_value.
fn box_decfloat(d DecFloat) voidptr {
	return voidptr(&DecFloat{
		...d
	})
}

// new_decfloat_value is a DECFLOAT of the type.
fn new_decfloat_value(typ Type, d DecFloat) Value {
	return Value{
		typ: typ
		v:   InternalValue{
			decfloat_value: box_decfloat(d)
		}
	}
}

// new_decfloat_from_string is the number s (such as "-1.50" or "1.5E+20"),
// rounded to the precision p (half to even), or an error if its exponent is out
// of range for p. s must be a valid <signed numeric literal>.
fn new_decfloat_from_string(s string, p int) !DecFloat {
	negative := s.starts_with('-')
	mut unsigned := s.trim_left('-+')
	mut exponent := 0
	at := unsigned.index_any('eE')
	if at >= 0 {
		exponent = unsigned[at + 1..].trim_left('+').int()
		unsigned = unsigned[..at]
	}
	mut digits := unsigned.replace('.', '').trim_left('0')
	if unsigned.contains('.') {
		exponent -= unsigned.all_after('.').len
	}

	if digits == '' {
		return DecFloat{big.zero_int, if exponent < -decfloat_max_exponent(p) - p + 1 {
			-decfloat_max_exponent(p) - p + 1
		} else {
			exponent
		}}
	}

	if digits.len > p {
		dropped := digits.len - p
		mut kept := big.integer_from_string(digits[..p]) or { big.zero_int }
		first := digits[p]
		rest_is_zero := digits[p + 1..].trim_right('0') == ''
		if first > `5` || (first == `5` && (!rest_is_zero || digits[p - 1] % 2 == 1)) {
			kept += big.one_int
		}
		digits = kept.str()
		exponent += dropped
		// Rounding up 999 makes 1000, which has one more digit than p.
		if digits.len > p {
			digits = digits[..p]
			exponent++
		}
	}

	adjusted := exponent + digits.len - 1
	max := decfloat_max_exponent(p)
	if adjusted > max || adjusted < 1 - max {
		return sqlstate_22003()
	}

	mut coefficient := big.integer_from_string(digits) or { big.zero_int }
	if negative {
		coefficient = coefficient.neg()
	}

	return DecFloat{coefficient, exponent}
}

// str is the number in plain notation when it's not too small or large, such
// as "1.50", otherwise in scientific notation, such as "1.5E+20". This is the
// IEEE 754 to-scientific-string conversion.
fn (d DecFloat) str() string {
	negative := d.coefficient.signum < 0
	sign := if negative { '-' } else { '' }
	digits := d.coefficient.abs().str()
	adjusted := d.exponent + digits.len - 1

	if d.exponent <= 0 && adjusted >= -6 {
		if d.exponent == 0 {
			return sign + digits
		}

		places := -d.exponent
		if digits.len > places {
			return '${sign}${digits[..digits.len - places]}.${digits[digits.len - places..]}'
		}

		return '${sign}0.${'0'.repeat(places - digits.len)}${digits}'
	}

	mantissa := if digits.len > 1 { '${digits[..1]}.${digits[1..]}' } else { digits }
	exponent_sign := if adjusted >= 0 { '+' } else { '' }

	return '${sign}${mantissa}E${exponent_sign}${adjusted}'
}

// exact_str is the number without an exponent, such as "1500" for 1.5E+3.
fn (d DecFloat) exact_str() string {
	sign := if d.coefficient.signum < 0 { '-' } else { '' }
	digits := d.coefficient.abs().str()
	if d.exponent >= 0 {
		return sign + digits + '0'.repeat(d.exponent)
	}

	places := -d.exponent
	if digits.len > places {
		return '${sign}${digits[..digits.len - places]}.${digits[digits.len - places..]}'
	}

	return '${sign}0.${'0'.repeat(places - digits.len)}${digits}'
}

// bytes is how a DECFLOAT is written in a row: the exponent as an i16, then the
// coefficient (with a sign) as a string with a 1 byte length.
fn (d DecFloat) bytes() []u8 {
	mut buf := new_empty_bytes()
	buf.write_i16(i16(d.exponent))
	s := d.coefficient.str()
	buf.write_u8(u8(s.len))
	buf.write_u8s(s.bytes())

	return buf.bytes()
}

// read_decfloat reads a DECFLOAT written by DecFloat.bytes.
fn read_decfloat(mut buf Bytes) DecFloat {
	exponent := buf.read_i16()
	s := buf.read_u8s(buf.read_u8()).bytestr()

	return DecFloat{big.integer_from_string(s) or { big.zero_int }, exponent}
}
