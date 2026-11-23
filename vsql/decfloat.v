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
// IEEE 754 to-scientific-string conversion. It's the implementation-defined
// literal of a DECFLOAT cast to a character string.
//
// ISO/IEC 9075-2:2023, 6.13, <cast specification>, General Rules, 11.c and 12.c
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

// round_decfloat is coefficient * 10^exponent rounded to p significant digits
// (half to even), or a 22003 error if its exponent is out of range for p.
// sticky means there are more nonzero digits after the coefficient, which only
// matters when it has more than p digits (see DecFloat.divide). A zero keeps
// its exponent, limited to the range of p.
//
// ISO/IEC 9075-2:2023, 6.30, <numeric value expression>, General Rules, 7
fn round_decfloat(coefficient big.Integer, exponent int, sticky bool, p int) !DecFloat {
	max := decfloat_max_exponent(p)
	if coefficient.signum == 0 {
		return DecFloat{big.zero_int, int_min(int_max(exponent, 2 - max - p), max - p + 1)}
	}

	negative := coefficient.signum < 0
	mut digits := coefficient.abs().str()
	mut e := exponent
	if digits.len > p {
		dropped := digits.len - p
		mut kept := big.integer_from_string(digits[..p]) or { big.zero_int }
		first := digits[p]
		rest_is_zero := !sticky && digits[p + 1..].trim_right('0') == ''
		if first > `5` || (first == `5` && (!rest_is_zero || digits[p - 1] % 2 == 1)) {
			kept += big.one_int
		}
		digits = kept.str()
		e += dropped
		// Rounding up 999 makes 1000, which has one more digit than p.
		if digits.len > p {
			digits = digits[..p]
			e++
		}
	}

	adjusted := e + digits.len - 1
	if adjusted > max || adjusted < 1 - max {
		return sqlstate_22003()
	}

	mut c := big.integer_from_string(digits) or { big.zero_int }
	if negative {
		c = c.neg()
	}

	return DecFloat{c, e}
}

fn int_min(a int, b int) int {
	return if a < b { a } else { b }
}

fn int_max(a int, b int) int {
	return if a > b { a } else { b }
}

// pow10 is 10^n.
fn pow10(n int) big.Integer {
	return big.integer_from_int(10).pow(u32(n))
}

fn (d DecFloat) is_zero() bool {
	return d.coefficient.signum == 0
}

fn (d DecFloat) neg() DecFloat {
	return DecFloat{d.coefficient.neg(), d.exponent}
}

fn (d DecFloat) abs() DecFloat {
	return DecFloat{d.coefficient.abs(), d.exponent}
}

// aligned is the coefficients of a and b with the same (the smaller) exponent,
// which is also returned.
fn aligned(a DecFloat, b DecFloat) (big.Integer, big.Integer, int) {
	e := int_min(a.exponent, b.exponent)
	return a.coefficient * pow10(a.exponent - e), b.coefficient * pow10(b.exponent - e), e
}

// add is a + b rounded to p digits. Like IEEE 754, the exponent is the smaller
// of the two, so 1.50 + 1 is 2.50.
fn (a DecFloat) add(b DecFloat, p int) !DecFloat {
	x, y, e := aligned(a, b)
	return round_decfloat(x + y, e, false, p)
}

fn (a DecFloat) subtract(b DecFloat, p int) !DecFloat {
	return a.add(b.neg(), p)
}

// multiply is a * b rounded to p digits. The exponents are added, so 1.5 * 1.5
// is 2.25.
fn (a DecFloat) multiply(b DecFloat, p int) !DecFloat {
	return round_decfloat(a.coefficient * b.coefficient, a.exponent + b.exponent, false, p)
}

// divide is a / b rounded to p digits. Like IEEE 754, an exact quotient has
// the exponent of a minus the exponent of b if it can, so 6 / 2 is 3 and 1 / 4
// is 0.25, and a quotient that isn't exact has p digits.
fn (a DecFloat) divide(b DecFloat, p int) !DecFloat {
	if b.is_zero() {
		return sqlstate_22012() // division by zero
	}

	preferred := a.exponent - b.exponent
	if a.is_zero() {
		return round_decfloat(big.zero_int, preferred, false, p)
	}

	// The quotient has at least p + 1 digits, so that it can be rounded.
	x := a.coefficient.abs()
	y := b.coefficient.abs()
	shift := int_max(0, p + 1 + y.str().len - x.str().len)
	mut q, r := (x * pow10(shift)).div_mod(y)
	mut e := preferred - shift
	if r.signum == 0 {
		ten := big.integer_from_int(10)
		for e < preferred {
			next, rest := q.div_mod(ten)
			if rest.signum != 0 {
				break
			}
			q = next
			e++
		}
	}
	if (a.coefficient.signum < 0) != (b.coefficient.signum < 0) {
		q = q.neg()
	}

	return round_decfloat(q, e, r.signum != 0, p)
}

// compare_decfloat compares the values of a and b, so 1.5 and 1.50 are equal.
fn compare_decfloat(a DecFloat, b DecFloat) CompareResult {
	x, y, _ := aligned(a, b)
	if x < y {
		return .is_less
	}
	if x > y {
		return .is_greater
	}

	return .is_equal
}

// integer_part is d truncated towards zero, with an exponent of 0 or more.
fn (d DecFloat) integer_part() DecFloat {
	if d.exponent >= 0 {
		return d
	}

	return DecFloat{d.coefficient / pow10(-d.exponent), 0}
}

// sqrt is the square root of d rounded to p digits, or a 2201F error if d is
// negative. The exponent of an exact root is half the exponent of d if it can
// be, so SQRT(4) is 2 and SQRT(0.25) is 0.5.
fn (d DecFloat) sqrt(p int) !DecFloat {
	if d.coefficient.signum < 0 {
		return sqlstate_2201f()
	}
	// The preferred exponent is half of the exponent of d, rounded down.
	preferred := if d.exponent >= 0 { d.exponent / 2 } else { -((-d.exponent + 1) / 2) }
	if d.is_zero() {
		return round_decfloat(big.zero_int, preferred, false, p)
	}

	// The coefficient is shifted by an even number of places, so that the root
	// has at least p + 1 digits, and its exponent is half of an even number.
	mut shift := int_max(0, 2 * (p + 1) - d.coefficient.str().len + 1)
	if (d.exponent - shift) % 2 != 0 {
		shift++
	}
	n := d.coefficient * pow10(shift)
	mut root := n.isqrt()
	exact := root * root == n
	mut e := (d.exponent - shift) / 2
	// An exact root of a coefficient with an even exponent is a whole number,
	// so it always has the preferred exponent, without losing any digits.
	if exact {
		root /= pow10(preferred - e)
		e = preferred
	}

	return round_decfloat(root, e, !exact, p)
}

// normalized_str is the value of d without its trailing zeros or an exponent,
// so that equal values have the same string, such as "1.5" for 1.50.
fn (d DecFloat) normalized_str() string {
	s := d.exact_str()
	if s.contains('.') {
		return s.trim_right('0').trim_right('.')
	}

	return if d.is_zero() { '0' } else { s }
}

// The numeric functions of a DECFLOAT return a DECFLOAT with the largest
// precision of the arguments (see RoutineInvocation.compile), so each one is
// registered with DECFLOAT(34) arguments and rounds to the precision of its
// first argument, which every argument has been cast to. ABS, MOD, FLOOR,
// CEIL, SQRT, POWER with a whole number exponent, and the vsql extensions
// ROUND, TRUNC and SIGN are exact (then rounded). The other functions are
// calculated with a DOUBLE PRECISION, so the result only has about 16
// significant digits, and an argument or result outside the range of a DOUBLE
// PRECISION is a 22003 error. Each result's precision is implementation-defined.
//
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 11, 12.a, 13.a, 14.a, 16.a, 17.a, 18.a and 20.c
fn register_decfloat_funcs(mut conn Connection) ! {
	decfloat := Type{.is_decfloat, max_decfloat_precision, 0, false, false}
	bigint := Type{.is_bigint, 0, 0, false, false}

	conn.register_func(Func{'ABS', [decfloat], false, func_abs_decfloat, decfloat, false, true, [], [], false})!
	conn.register_func(Func{'MOD', [decfloat, decfloat], false, func_mod_decfloat, decfloat, false, true, [], [], false})!
	for name in ['FLOOR', 'CEIL', 'CEILING'] {
		conn.register_func(Func{name, [decfloat], false, func_floor_ceil_decfloat(name == 'FLOOR'), decfloat, false, true, [], [], false})!
	}
	conn.register_func(Func{'SQRT', [decfloat], false, func_sqrt_decfloat, decfloat, false, true, [], [], false})!
	conn.register_func(Func{'POWER', [decfloat, decfloat], false, func_power_decfloat, decfloat, false, true, [], [], false})!

	approximate := {
		'ACOS':  func_acos
		'ASIN':  func_asin
		'ATAN':  func_atan
		'COS':   func_cos
		'COSH':  func_cosh
		'EXP':   func_exp
		'LN':    func_ln
		'LOG10': func_log10
		'SIN':   func_sin
		'SINH':  func_sinh
		'TAN':   func_tan
		'TANH':  func_tanh
	}
	for name, f in approximate {
		conn.register_func(Func{name, [decfloat], false, with_double_precision(f), decfloat, false, true, [], [], false})!
	}
	conn.register_func(Func{'LOG', [decfloat, decfloat], false, with_double_precision(func_log), decfloat, false, true, [], [], false})!

	for name in ['ROUND', 'TRUNC'] {
		feature := if name == 'ROUND' { vsql_round } else { vsql_trunc }
		truncate := name == 'TRUNC'
		conn.register_func(Func{name, [decfloat], false, fn [truncate] (_ FunctionContext, args []Value) !Value {
			return round_decfloat_value(args[0], 0, truncate)
		}, decfloat, false, true, [feature], [], false})!
		conn.register_func(Func{name, [decfloat, bigint], false, fn [truncate] (_ FunctionContext, args []Value) !Value {
			return round_decfloat_value(args[0], args[1].int_value(), truncate)
		}, decfloat, false, true, [feature], [], false})!
	}
	conn.register_func(Func{'SIGN', [decfloat], false, func_sign_decfloat, decfloat, false, true, [
		vsql_sign,
	], [], false})!
}

// with_double_precision is f (a function of DOUBLE PRECISION arguments) for
// DECFLOAT arguments, with the result rounded to the precision of the first
// argument.
fn with_double_precision(f fn (FunctionContext, []Value) !Value) fn (FunctionContext, []Value) !Value {
	return fn [f] (ctx FunctionContext, args []Value) !Value {
		mut doubles := []Value{}
		for arg in args {
			doubles << approximate_value(arg.as_f64()!, .is_double_precision)!
		}

		return cast_to_decfloat(f(ctx, doubles)!, args[0].typ)
	}
}

// ABS(DECFLOAT) DECFLOAT
fn func_abs_decfloat(_ FunctionContext, args []Value) !Value {
	return new_decfloat_value(args[0].typ, args[0].decfloat_value().abs())
}

// MOD(DECFLOAT, DECFLOAT) DECFLOAT
//
// The result has the sign of the dividend, like the other numbers. It's exact,
// with the smaller exponent of the two, so MOD(7.5, 2) is 1.5.
//
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 9
fn func_mod_decfloat(_ FunctionContext, args []Value) !Value {
	n := args[0].decfloat_value()
	m := args[1].decfloat_value()
	if m.is_zero() {
		return sqlstate_22012() // division by zero
	}

	x, y, e := aligned(n, m)
	mut r := x.abs() % y.abs()
	if x.signum < 0 {
		r = r.neg()
	}

	return new_decfloat_value(args[0].typ, round_decfloat(r, e, false, args[0].typ.size)!)
}

// FLOOR(DECFLOAT) DECFLOAT
// CEIL(DECFLOAT) DECFLOAT
//
// A whole number keeps its exponent, otherwise the result has an exponent of 0.
fn func_floor_ceil_decfloat(floor bool) fn (FunctionContext, []Value) !Value {
	return fn [floor] (_ FunctionContext, args []Value) !Value {
		d := args[0].decfloat_value()
		mut t := d.abs().integer_part()
		if d.coefficient.signum < 0 {
			t = t.neg()
		}
		if compare_decfloat(t, d) != .is_equal {
			if floor && d.coefficient.signum < 0 {
				t = DecFloat{t.coefficient - big.one_int, 0}
			}
			if !floor && d.coefficient.signum > 0 {
				t = DecFloat{t.coefficient + big.one_int, 0}
			}
		}

		return new_decfloat_value(args[0].typ, round_decfloat(t.coefficient, t.exponent,
			false, args[0].typ.size)!)
	}
}

// SQRT(DECFLOAT) DECFLOAT
//
// SQRT(x) is POWER(x, 0.5), so x can't be negative.
//
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 19
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 14.e
fn func_sqrt_decfloat(_ FunctionContext, args []Value) !Value {
	return new_decfloat_value(args[0].typ, args[0].decfloat_value().sqrt(args[0].typ.size)!)
}

// POWER(DECFLOAT, DECFLOAT) DECFLOAT
//
// A whole number exponent is calculated exactly (a negative one is the
// reciprocal), as is an exponent of 0.5 (the square root). Any other exponent
// is calculated with a DOUBLE PRECISION.
//
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 14
fn func_power_decfloat(ctx FunctionContext, args []Value) !Value {
	p := args[0].typ.size
	base := args[0].decfloat_value()
	exponent := args[1].decfloat_value()

	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 14.b
	if base.is_zero() && exponent.coefficient.signum < 0 {
		return sqlstate_2201f()
	}

	if compare_decfloat(exponent, DecFloat{big.integer_from_int(5), -1}) == .is_equal {
		return new_decfloat_value(args[0].typ, base.sqrt(p)!)
	}

	whole := exponent.abs().integer_part()
	if compare_decfloat(whole, exponent.abs()) == .is_equal {
		k := whole.exact_str()
		// A result with more digits than this is out of range anyway, unless
		// the base is a power of 10, so it's left to the DOUBLE PRECISION.
		if k.len < 6 && base.coefficient.abs().str().len * k.int() <= 20000 {
			n := u32(k.int())
			mut result := round_decfloat(base.coefficient.pow(n), base.exponent * int(n),
				false, p) or {
				// A result that's out of range may still have a reciprocal that
				// isn't.
				if exponent.coefficient.signum >= 0 {
					return err
				}
				DecFloat{base.coefficient.pow(n), base.exponent * int(n)}
			}
			if exponent.coefficient.signum < 0 {
				result = DecFloat{big.one_int, 0}.divide(result, p)!
			}

			return new_decfloat_value(args[0].typ, result)
		}
	}

	return with_double_precision(func_power)(ctx, args)!
}

// round_decfloat_value is ROUND(v, places) or TRUNC(v, places) of a DECFLOAT,
// to places decimal places (a negative number of places is to the left of the
// decimal point). Unlike a NUMERIC, the result has an exponent of -places (or
// 0), so ROUND(1.5) is 2, not 2.0. A number with fewer decimal places is
// unchanged. ROUND rounds half away from zero, and TRUNC towards zero.
fn round_decfloat_value(v Value, places i64, truncate bool) !Value {
	d := v.decfloat_value()
	if i64(d.exponent) >= -places {
		return v
	}

	// Every digit is to the right of the place it's rounded to, so it's 0.
	digits := d.coefficient.abs().str().len
	if -places >= i64(digits + d.exponent) + 1 {
		return new_decfloat_value(v.typ, round_decfloat(big.zero_int, int_min(0, int(-places)),
			false, v.typ.size)!)
	}

	t := int(-places)
	factor := pow10(t - d.exponent)
	mut q, r := d.coefficient.abs().div_mod(factor)
	if !truncate && r * big.integer_from_int(2) >= factor {
		q += big.one_int
	}
	if d.coefficient.signum < 0 {
		q = q.neg()
	}

	// The digits left of the decimal point are zeros, rather than an exponent.
	if t > 0 {
		return new_decfloat_value(v.typ, round_decfloat(q * pow10(t), 0, false, v.typ.size)!)
	}

	return new_decfloat_value(v.typ, round_decfloat(q, t, false, v.typ.size)!)
}

// SIGN(DECFLOAT) DECFLOAT is -1, 0 or 1.
fn func_sign_decfloat(_ FunctionContext, args []Value) !Value {
	return new_decfloat_value(args[0].typ, DecFloat{big.integer_from_int(args[0].decfloat_value().coefficient.signum), 0})
}
