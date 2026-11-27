module vsql

import math.big

// The functions that format a number of bytes as a size (such as 24 MB) and
// parse a size back into bytes (V410-01 and V410-02). They aren't in the SQL
// standard. The sizes are calculated exactly (rather than with a DOUBLE
// PRECISION), so they're rounded the same way for any number of bytes.
//
// A unit is bytes (B), a binary unit of 1024 to a power (KiB to YiB, the IEC
// prefixes), or a decimal unit of 1000 to a power (kB to YB, the SI prefixes).
// See parse_size_unit for how they can be written.

fn register_size_funcs(mut conn Connection) ! {
	numeric := Type{SQLType.is_numeric, 0, 0, false, false}
	bigint := Type{SQLType.is_bigint, 0, 0, false, false}
	varchar := Type{SQLType.is_varchar, 0, 0, false, false}

	// Any exact number is implicitly cast to a NUMERIC (see best_function), so
	// there's only one function for each number of arguments, which is also the
	// type of a dynamic parameter. A NULL significant figures, unit or base is
	// the default, so the functions that have them are called on a NULL
	// argument, and are given the names of their parameters (see
	// register_func).
	conn.register_func(Func{'FORMAT_SIZE', [numeric], false, func_format_size, varchar, false, true, [
		vsql_format_size,
	], [], false})!
	conn.register_func(Func{'FORMAT_SIZE', [numeric, bigint], false, func_format_size, varchar, true, true, [
		vsql_format_size,
	], size_arg_names['FORMAT_SIZE'][..2], false})!
	conn.register_func(Func{'FORMAT_SIZE', [numeric, bigint, varchar], false, func_format_size, varchar, true, true, [
		vsql_format_size,
	], size_arg_names['FORMAT_SIZE'][..3], false})!
	conn.register_func(Func{'FORMAT_SIZE', [numeric, bigint, varchar, bigint], false, func_format_size, varchar, true, true, [
		vsql_format_size,
	], size_arg_names['FORMAT_SIZE'], false})!
	conn.register_func(Func{'PARSE_SIZE', [varchar], false, func_parse_size, bigint, false, true, [
		vsql_parse_size,
	], [], false})!
	conn.register_func(Func{'PARSE_SIZE', [varchar, bigint], false, func_parse_size, bigint, true, true, [
		vsql_parse_size,
	], size_arg_names['PARSE_SIZE'], false})!
}

// SizeUnit is bytes (exponent 0), or 1024 (binary) or 1000 to the power of
// exponent.
struct SizeUnit {
	exponent int
	binary   bool
}

const size_prefixes = 'KMGTPEZY'
const size_decimal_names = ['kilo', 'mega', 'giga', 'tera', 'peta', 'exa', 'zetta', 'yotta']
const size_binary_names = ['kibi', 'mebi', 'gibi', 'tebi', 'pebi', 'exbi', 'zebi', 'yobi']

// parse_size_unit finds the unit, in upper or lower case, ignoring white space:
// nothing, B, BYTE or BYTES for bytes, and K, KB or KILOBYTE(S) for kilobytes,
// or KI, KIB or KIBIBYTE(S) for kibibytes (and the same for M to Y).
fn parse_size_unit(text string) ?SizeUnit {
	mut unit := []u8{}
	for c in text.to_lower() {
		if !c.is_space() {
			unit << c
		}
	}
	u := unit.bytestr()

	if u in ['', 'b', 'byte', 'bytes'] {
		return SizeUnit{}
	}
	for i, name in size_decimal_names {
		p := size_prefixes[i..i + 1].to_lower()
		if u in [p, p + 'b', name + 'byte', name + 'bytes'] {
			return SizeUnit{i + 1, false}
		}
		binary_name := size_binary_names[i]
		if u in [p + 'i', p + 'ib', binary_name + 'byte', binary_name + 'bytes'] {
			return SizeUnit{i + 1, true}
		}
	}

	return none
}

// label is how the unit is written: B, KiB to YiB, or kB to YB (the SI prefix
// for kilo is a lower case k).
fn (u SizeUnit) label() string {
	if u.exponent == 0 {
		return 'B'
	}
	if u.binary {
		return size_prefixes[u.exponent - 1..u.exponent] + 'iB'
	}
	if u.exponent == 1 {
		return 'kB'
	}

	return size_prefixes[u.exponent - 1..u.exponent] + 'B'
}

// step is how many of the unit before it are in one of the unit: 1024 for a
// binary unit, or 1000 for a decimal unit, unless the base is 2 or 10 (see
// PARSE_SIZE), which is used for every unit instead.
fn (u SizeUnit) step(base int) int {
	return match base {
		2 { 1024 }
		10 { 1000 }
		else {
			if u.binary { 1024 } else { 1000 }
		}
	}
}

// bytes is the number of bytes in one of the unit, which is the step to the
// power of the exponent (so it's always 1 for bytes).
fn (u SizeUnit) bytes(base int) big.Integer {
	return big.integer_from_int(u.step(base)).pow(u32(u.exponent))
}

// size_base is the base argument of FORMAT_SIZE or PARSE_SIZE: 0 (also for a
// NULL or a missing one), 2 or 10.
fn size_base(name string, args []Value, i int) !int {
	base := if args.len > i && !args[i].is_null { args[i].int_value() } else { 0 }
	if base !in [i64(0), 2, 10] {
		return sqlstate_22023('${name}: base must be 0, 2 or 10')
	}

	return int(base)
}

// round_half_away is numerator / denominator (both positive) rounded to the
// nearest integer, with a half rounded up.
fn round_half_away(numerator big.Integer, denominator big.Integer) big.Integer {
	two := big.integer_from_int(2)
	return (numerator * two + denominator) / (denominator * two)
}

// FORMAT_SIZE(NUMERIC [, BIGINT [, CHARACTER VARYING [, BIGINT]]]) CHARACTER VARYING
//
// The number of bytes (rounded to a whole number), followed by a space and the
// unit, such as 24 MB. Without a unit (or a NULL), it's the largest decimal
// unit that's not more than the bytes, so the number is from 1 up to (but not
// including) 1000, or B for less than 1 kB, because powers of 1000 are easier
// to think about. A base of 2 uses the binary units instead (KiB to YiB, from 1
// up to 1024). Otherwise, it's always in that unit, which can be binary, and a
// base of 2 or 10 is used for it like PARSE_SIZE, so PARSE_SIZE with the same
// base reads it back.
//
// The significant figures (0 or NULL by default) are the most digits that the
// number has, without any zeros at the end of the fraction, so 1.5 kB is 1.5
// with 3 significant figures, and 1 MB is 1. The digits of the whole number
// are never rounded, so 999 kB is 999 with 2 significant figures. 0 rounds to
// a whole number. Bytes don't have a fraction. When rounding makes the number
// 1000 (or 1024), it's 1 of the next unit, unless the unit was given.
//
// It's a 22023 error when the significant figures aren't from 0 to 20, the
// unit isn't known, or the base isn't 0, 2 or 10.
fn func_format_size(_ FunctionContext, args []Value) !Value {
	if args[0].is_null {
		return new_null_value(.is_varchar)
	}

	figures := if args.len > 1 && !args[1].is_null { args[1].int_value() } else { 0 }
	if figures < 0 || figures > 20 {
		return sqlstate_22023('FORMAT_SIZE: significant figures must be from 0 to 20')
	}

	base := size_base('FORMAT_SIZE', args, 3)!
	is_auto := args.len < 3 || args[2].is_null
	mut unit := SizeUnit{
		binary: base == 2
	}
	if !is_auto {
		unit = parse_size_unit(args[2].string_value()) or {
			return sqlstate_22023('FORMAT_SIZE: unknown unit: ${args[2].string_value()}')
		}
	}

	n := args[0].as_numeric()!
	bytes := if n.denominator.signum == 0 {
		big.zero_int
	} else {
		round_half_away(n.numerator.abs(), n.denominator)
	}
	if is_auto {
		for unit.exponent < size_prefixes.len
			&& !(bytes < SizeUnit{unit.exponent + 1, unit.binary}.bytes(base)) {
			unit = SizeUnit{unit.exponent + 1, unit.binary}
		}
	}

	mut number, mut carried := format_size_number(bytes, unit, base, int(figures))
	if is_auto && carried && unit.exponent < size_prefixes.len {
		unit = SizeUnit{unit.exponent + 1, unit.binary}
		number, carried = format_size_number(bytes, unit, base, int(figures))
	}

	sign := if n.numerator.signum < 0 && number != '0' { '-' } else { '' }
	return new_varchar_value('${sign}${number} ${unit.label()}')
}

// format_size_number is the bytes (not negative) in the unit, rounded to the
// significant figures (see FORMAT_SIZE), and true if it was rounded up to the
// step of the unit (1024 or 1000).
fn format_size_number(bytes big.Integer, unit SizeUnit, base int, figures int) (string, bool) {
	if unit.exponent == 0 || bytes.signum == 0 {
		return bytes.str(), false
	}

	denominator := unit.bytes(base)
	mut places := 0
	if figures > 0 {
		places = figures - size_whole_digits(bytes, denominator)
		if places < 0 {
			places = 0
		}
	}

	scale := pow10(places)
	rounded := round_half_away(bytes * scale, denominator)
	carried := !(rounded < big.integer_from_int(unit.step(base)) * scale)

	mut digits := rounded.str()
	if places > 0 {
		if digits.len <= places {
			digits = '0'.repeat(places + 1 - digits.len) + digits
		}
		digits = (digits[..digits.len - places] + '.' + digits[digits.len - places..]).trim_right('0').trim_right('.')
	}

	return digits, carried
}

// size_whole_digits is the number of digits of numerator / denominator (which
// isn't zero) before the decimal point, or for a number less than 1, minus the
// number of zeros after it, such as -3 for 0.000488.
fn size_whole_digits(numerator big.Integer, denominator big.Integer) int {
	if !(numerator < denominator) {
		return (numerator / denominator).str().len
	}

	mut zeros := 0
	for numerator * pow10(zeros + 1) < denominator {
		zeros++
	}

	return -zeros
}

// PARSE_SIZE(CHARACTER VARYING [, BIGINT]) BIGINT
//
// The number of bytes of a size, such as 24117248 for 23 MiB, rounded to a
// whole number. The number can have a sign, a fraction and an exponent (such as
// -1.5e3), and its digits can be grouped by an underscore anywhere between
// them, or by commas in groups of three (so 1,5 is an error, rather than 15).
// The unit can be any of the ones in parse_size_unit, and there can be any white
// space before, between and after them.
//
// A binary unit is 1024 to a power, and a decimal unit is 1000 to a power,
// unless the base (0 or NULL by default) is 2 or 10, which is used for every unit
// instead (such as for a system that's known to write MB for 1024 KiB). Bytes
// are always bytes.
//
// It's a 22018 error when the size can't be read, a 22003 error when it's more
// than a BIGINT, and a 22023 error when the base isn't 0, 2 or 10.
fn func_parse_size(_ FunctionContext, args []Value) !Value {
	if args[0].is_null {
		return new_null_value(.is_bigint)
	}

	base := size_base('PARSE_SIZE', args, 1)!

	return new_bigint_value(parse_size(args[0].string_value(), base)!)
}

fn parse_size(text string, base int) !i64 {
	s := text.trim_space()
	mut i := 0
	mut negative := false
	if i < s.len && s[i] in [`+`, `-`] {
		negative = s[i] == `-`
		i++
		for i < s.len && s[i].is_space() {
			i++
		}
	}

	// The whole number. The commas must be between groups of three digits,
	// after the first group of one to three digits.
	mut digits := []u8{}
	mut groups := []int{}
	mut group := 0
	for i < s.len {
		c := s[i]
		if c.is_digit() {
			digits << c
			group++
		} else if c == `_` && i > 0 && s[i - 1].is_digit() && i + 1 < s.len && s[i + 1].is_digit() {
			// An underscore between digits is ignored.
		} else if c == `,` && group > 0 && i + 1 < s.len && s[i + 1].is_digit() {
			groups << group
			group = 0
		} else {
			break
		}
		i++
	}
	if groups.len > 0 && (groups[0] > 3 || groups[1..].any(it != 3) || group != 3) {
		return sqlstate_22018()
	}

	mut places := 0
	if i < s.len && s[i] == `.` {
		i++
		for i < s.len {
			c := s[i]
			if c.is_digit() {
				digits << c
				places++
			} else if !(c == `_` && s[i - 1].is_digit() && i + 1 < s.len && s[i + 1].is_digit()) {
				break
			}
			i++
		}
	}
	if digits.len == 0 {
		return sqlstate_22018()
	}

	// An E is an exponent when it's followed by a digit (otherwise it's the
	// unit, such as EiB). An exponent of more than four digits is out of range.
	mut exponent := 0
	if i < s.len && s[i] in [`e`, `E`] {
		mut j := i + 1
		mut exponent_negative := false
		if j < s.len && s[j] in [`+`, `-`] {
			exponent_negative = s[j] == `-`
			j++
		}
		mut exponent_digits := ''
		for j < s.len && s[j].is_digit() {
			exponent_digits += s[j..j + 1]
			j++
		}
		if exponent_digits.len > 0 {
			if exponent_digits.len > 4 {
				return sqlstate_22003()
			}
			exponent = exponent_digits.int()
			if exponent_negative {
				exponent = -exponent
			}
			i = j
		}
	}

	unit := parse_size_unit(s[i..]) or { return sqlstate_22018() }

	mut numerator := (big.integer_from_string(digits.bytestr())!) * unit.bytes(base)
	mut denominator := pow10(places)
	if exponent > 0 {
		numerator = numerator * pow10(exponent)
	} else {
		denominator = denominator * pow10(-exponent)
	}

	bytes := round_half_away(numerator, denominator)
	if big.integer_from_i64(max_i64) < bytes {
		return sqlstate_22003()
	}

	n := big_integer_to_i64(bytes)
	return if negative { -n } else { n }
}

// size_arg_names are the names of the parameters of the functions in this
// file (see builtin_arg_names).
const size_arg_names = {
	'FORMAT_SIZE': ['BYTES', 'SIGNIFICANT_FIGURES', 'UNIT', 'BASE']
	'PARSE_SIZE':  ['SIZE', 'BASE']
}
