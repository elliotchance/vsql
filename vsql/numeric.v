// numeric.v contains the implementation and operations for the DECIMAL and
// NUMERIC types.

module vsql

import math.big

const (
	numeric_is_null     = u8(1 << 0)
	numeric_is_zero     = u8(1 << 1)
	numeric_is_positive = u8(1 << 2)
)

struct Numeric {
	// typ contains the precision and scale that affect calculations.
	typ       Type
	flags     u8 // numeric_* constants
	numerator big.Integer
	// denominator will not be negative and will only be 0 (should be ignored)
	// if the numeric_is_zero flag is set.
	denominator big.Integer
}

fn new_numeric(typ Type, positive bool, numerator big.Integer, denominator big.Integer) Numeric {
	mut flags := u8(0)

	if numerator == big.zero_int {
		flags |= vsql.numeric_is_zero
	}

	if positive {
		flags |= vsql.numeric_is_positive
	}

	return Numeric{
		typ: typ
		flags: flags
		numerator: numerator
		denominator: denominator
	}
}

fn new_numeric_from_int(n int) Numeric {
	return new_numeric_from_string(n.str())
}

// NOTE: numeric value is expected to be well formed.
fn new_numeric_from_string(n_ string) Numeric {
	mut n := n_
	mut positive := true
	if n[0] == `-` {
		positive = false
		n = n[1..]
	}

	parts := n.split('.')
	mut numerator := big.integer_from_string(parts[0]) or { big.zero_int }
	mut denominator := big.one_int

	if parts.len == 2 {
		denominator = big.integer_from_int(10).pow(u32(parts[1].len))
		numerator *= denominator
		numerator += big.integer_from_string(parts[1]) or { big.zero_int }
	}

	return new_numeric(Type{.is_numeric, 0, 0, false, false}, positive, numerator, denominator)
}

fn (n Numeric) bytes() []u8 {
	mut buf := new_bytes([]u8{})
	buf.write_u8(n.flags)

	// If the value is NULL or 0 we don't need to encode anything further.
	if !(n.flags & vsql.numeric_is_null != 0 || n.flags & vsql.numeric_is_zero != 0) {
		numerator, _ := n.numerator.bytes()
		buf.write_i16(i16(numerator.len))
		buf.write_u8s(numerator)

		denominator, _ := n.denominator.bytes()
		buf.write_i16(i16(denominator.len))
		buf.write_u8s(denominator)
	}

	return buf.bytes()
}

fn (n Numeric) str() string {
	if n.denominator == big.one_int {
		return if n.flags & vsql.numeric_is_positive == 0 { '-' } else { '' } + n.numerator.str()
	}

	denominator_digits := n.denominator.str().len
	mut s := ((n.numerator * big.integer_from_int(10).pow(u32(denominator_digits))) / n.denominator).str()
	decimal_at := n.numerator.str().len - n.denominator.str().len + 1
	s = s[..decimal_at] + '.' + s[decimal_at..]
	s = s.trim_right('.0')

	return if n.flags & vsql.numeric_is_positive == 0 { '-' } else { '' } + s
}

fn (n Numeric) neg() Numeric {
	return new_numeric(n.typ, !(n.flags & vsql.numeric_is_positive != 0), n.numerator,
		n.denominator)
}

fn (n Numeric) precision() int {
	// TODO(elliotchance): This is a poor implementation.
	s := n.str().split('.')
	if s.len == 2 {
		return s[0].len + s[1].len
	}

	return s[0].len
}

fn (n Numeric) scale() int {
	// TODO(elliotchance): This is a poor implementation.
	s := n.str().split('.')
	if s.len == 2 {
		return s[1].len
	}

	return 0
}

fn (n Numeric) whole_digits() int {
	return n.precision() - n.scale()
}

fn (n Numeric) f64() f64 {
	return n.numerator.str().f64() / n.denominator.str().f64()
}

// TODO(elliotchance): This doesn't correctly round, it just truncates the
//  value. That because this is an extra expensive and hacky approach. Please
//  improve it.
fn (n Numeric) round(scale i16) Numeric {
	parts := n.str().split('.')

	// Check if there's enough digits to round.
	if parts.len < 2 || parts[1].len <= scale {
		return n
	}

	numerator := big.integer_from_string(parts[0] + parts[1][..scale]) or { big.one_int }
	denominator := n.denominator / big.integer_from_int(10).pow(u32(-(scale - n.denominator.str().len) - 1))

	return new_numeric(Type{
		typ: n.typ.typ
		size: n.typ.size
		scale: scale
		not_null: n.typ.not_null
	}, n.flags & vsql.numeric_is_positive != 0, numerator, denominator)
}

fn (n Numeric) add(n2 Numeric) Numeric {
	numerator := (n.numerator * n2.denominator) + (n2.numerator * n.denominator)
	denominator := n.denominator * n2.denominator

	// TODO(elliotchance): Need to pick the correct type.
	// TODO(elliotchance): Sign could be wrong.
	return new_numeric(new_type('NUMERIC', 0, 0), n.flags & vsql.numeric_is_positive != 0,
		numerator, denominator)
}

fn (n Numeric) subtract(n2 Numeric) Numeric {
	numerator := (n.numerator * n2.denominator) - (n2.numerator * n.denominator)
	denominator := n.denominator * n2.denominator

	// TODO(elliotchance): Need to pick the correct type.
	// TODO(elliotchance): Sign could be wrong.
	return new_numeric(new_type('NUMERIC', 0, 0), n.flags & vsql.numeric_is_positive != 0,
		numerator, denominator)
}

fn (n Numeric) multiply(n2 Numeric) Numeric {
	numerator := n.numerator * n2.numerator
	denominator := n.denominator * n2.denominator

	// TODO(elliotchance): Need to pick the correct type.
	// TODO(elliotchance): Sign could be wrong.
	return new_numeric(new_type('NUMERIC', 0, 0), n.flags & vsql.numeric_is_positive != 0,
		numerator, denominator)
}
