module vsql

import strings

// ISO/IEC 9075-2:2016(E), 9.2, Store assignment
//
// Specify rules for assignments where the target permits null without the use
// of indicator parameters or indicator variables, such as storing SQL-data or
// setting the value of SQL parameters.
//
// The concepts are described by:
//
// ISO/IEC 9075-1:2003(E), 4.5, Sites and operations on sites
// ISO/IEC 9075-1:2003(E), 4.5.1, Sites
// ISO/IEC 9075-1:2003(E), 4.5.2, Assignment

const min_smallint = new_numeric_from_string('-32768')

const max_smallint = new_numeric_from_string('32767')

const min_integer = new_numeric_from_string('-2147483648')

const max_integer = new_numeric_from_string('2147483647')

const min_bigint = new_numeric_from_string('-9223372036854775808')

const max_bigint = new_numeric_from_string('9223372036854775807')

type CastFunc = fn (conn &Connection, v Value, to Type) !Value

// store_assignment converts a value to a type in the same way as storing it in
// a column of that type, such as a string to a NUMERIC. An error is returned if
// the value can't be stored in that type.
pub fn (mut conn Connection) store_assignment(v Value, to Type) !Value {
	// This isn't part of a statement, so it has its own statement timestamp
	// (for the date of a TIME that's converted to a TIMESTAMP).
	conn.set_statement_timestamp()

	return cast(mut conn, 'for store assignment', v, to)
}

// cast converts v to the type t by the rules of a store assignment, which are
// also used for a CAST of most of the supported types.
//
// ISO/IEC 9075-2:2016(E), 9.2, Store assignment, General Rules, 1-3
fn cast(mut conn Connection, msg string, v Value, t Type) !Value {
	// - GR 1. T is t and V is v.

	// - GR 2. There are no user-defined cast functions (S211), so V is never
	// replaced by UDCF(V).

	// - GR 3.a. V is the null value.
	if v.is_null {
		// - GR 3.a.i and 3.a.iv. T is set to the null value.
		if !v.typ.not_null {
			return v
		}

		// - GR 3.a.ii and 3.a.iii. The indicator of a host parameter (or a host
		// variable) is handled by the module, where any negative value is the null
		// value, so one that's less than -1 isn't 22010 (#783).
	}

	// - GR 3.b. Otherwise, by the type of T:
	match t.typ {
		.is_character {
			// - GR 3.b.i. A CHARACTER(L) is set to V when it has L characters.
			//
			// It doesn't state that the destination needs to also be a
			// character-type. This is what allows any string representation (for
			// example numbers) to be converted to a string, provided they still fit
			// all the same requirements.
			s := cast_character_source(v)
			chars := s.runes()

			l := t.size
			if l == chars.len {
				return new_character_value(s)
			}

			// - GR 3.b.ii. V is longer than L:
			m := chars.len
			if m > l {
				// - GR 3.b.ii.1. It's truncated if the extra characters are all
				// spaces.
				if chars[l..].all(it == ` `) {
					return new_character_value(chars[..l].string())
				}

				// - GR 3.b.ii.2. Otherwise, it's 22001 (string data, right
				// truncation).
				return sqlstate_22001(t)
			} else {
				// - GR 3.b.iii. V is shorter than L, so it's padded with spaces.
				pad := strings.repeat(` `, l - m)
				return new_character_value(s + pad)
			}
		}
		.is_varchar {
			// - GR 3.b.iv. A CHARACTER VARYING(L) is set to V when it isn't longer
			// than L.
			//
			// See note above about using v.str() instead of string_value().
			s := cast_character_source(v)
			chars := s.runes()

			// A CHARACTER VARYING without a length (such as the declared type of an
			// expression) has no maximum length.
			l := t.size
			m := chars.len
			if l == 0 || m <= l {
				return new_varchar_value(s)
			}

			// - GR 3.b.v. V is longer than L:
			if chars[l..].all(it == ` `) {
				// - GR 3.b.v.1. It's truncated if the extra characters are all spaces.
				return new_varchar_value(chars[..l].string())
			}

			// - GR 3.b.v.2. Otherwise, it's 22001 (string data, right truncation).
			return sqlstate_22001(t)
		}
		// - GR 3.b.vi-3.b.xiv. There are no CLOBs (T041), binary strings (T021) or
		// BLOBs, so fallthrough.
		.is_numeric, .is_decimal, .is_smallint, .is_integer, .is_bigint, .is_real,
		.is_double_precision {
			// - GR 3.b.xv. A number:
			// - GR 3.b.xv.1. V is already of the type of T.
			if v.typ == t {
				return v
			}

			// - GR 3.b.xv.2 and 3.b.xv.3. V is rounded or truncated to the type of
			// T (an exact numeric is truncated), or it's 22003 (numeric value out of
			// range). Both cases are handled by cast_numeric.
			if v.typ.typ.is_string() {
				return cast_character_to_number(mut conn, v, t)
			}

			return cast_numeric(mut conn, v, t)
		}
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone, .is_date,
		.is_time_with_time_zone, .is_time_without_time_zone {
			// - GR 3.b.xvi. A datetime:
			//
			// - GR 3.b.xvi.1. When only one of them has a time zone, V is first cast
			// to the type of T.
			if t.typ == .is_timestamp_with_time_zone && v.typ.typ == .is_timestamp_without_time_zone {
				return cast(mut conn, msg, cast_timestamp_without_to_timestamp_with(conn, v, t)!, t)
			}
			if t.typ == .is_timestamp_without_time_zone && v.typ.typ == .is_timestamp_with_time_zone {
				return cast(mut conn, msg, cast_timestamp_with_to_timestamp_without(conn, v, t)!, t)
			}

			// - GR 3.b.xvi.2.A. V is already of the type of T.
			if v.typ == t {
				return v
			}

			// - GR 3.b.xvi.2.B. Otherwise, V is rounded or truncated to the type of T
			// (the fractional seconds are truncated).
			//
			// I'm going to assume this also leaves open the opportunity to cast
			// between different types like DATE to TIMESTAMP.
			return cast_datetime(conn, v, t)

			// - GR 3.b.xvi.2.C. A datetime field overflow isn't possible right now
			// since the range is already validated at the time the timestamp is
			// created.
		}
		// - GR 3.b.xvii. There are no intervals (F052).
		.is_boolean {
			// - GR 3.b.xviii. A BOOLEAN is set to V.
			//
			// This seems oddly ambigious to me, they don't specify that the value
			// it's coming from must also be a BOOLEAN, so for now we must assume this
			// is not permitted.
			if v.typ.typ == .is_boolean {
				return v
			}
		}
	}

	// - GR 3.b.xix-3.b.xxiii. There are no row types (as a site), reference
	// types (S041), arrays (S091), multisets (S271) or user-defined types
	// (S023).

	return sqlstate_42846(v.typ, t)
}

// cast_character_source returns the string representation of v used when the
// target is a character string. For datetimes, the shortest <literal> (such as
// "DATE '2022-06-30'") is required rather than just the formatted value.
//
// ISO/IEC 9075-2:2016(E), 6.13, <cast specification>, General Rules, 11.e and 12.e
fn cast_character_source(v Value) string {
	return match v.typ.typ {
		.is_date, .is_time_with_time_zone, .is_time_without_time_zone,
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
			v.time_value().str_literal()
		}
		else {
			v.str()
		}
	}
}

fn cast_datetime(conn Connection, v Value, t Type) !Value {
	cast_rules := {
		'DATE AS TIMESTAMP WITHOUT TIME ZONE':                        CastFunc(cast_date_to_timestamp_without)
		'DATE AS TIMESTAMP WITH TIME ZONE':                           cast_date_to_timestamp_with
		'TIME WITH TIME ZONE AS TIME WITH TIME ZONE':                 cast_time_with_to_time_with
		'TIME WITH TIME ZONE AS TIME WITHOUT TIME ZONE':              cast_time_with_to_time_without
		'TIME WITHOUT TIME ZONE AS TIME WITHOUT TIME ZONE':           cast_time_without_to_time_without
		'TIME WITHOUT TIME ZONE AS TIME WITH TIME ZONE':              cast_time_without_to_time_with
		'TIME WITH TIME ZONE AS TIMESTAMP WITH TIME ZONE':            cast_time_with_to_timestamp_with
		'TIME WITH TIME ZONE AS TIMESTAMP WITHOUT TIME ZONE':         cast_time_with_to_timestamp_without
		'TIME WITHOUT TIME ZONE AS TIMESTAMP WITH TIME ZONE':         cast_time_without_to_timestamp_with
		'TIME WITHOUT TIME ZONE AS TIMESTAMP WITHOUT TIME ZONE':      cast_time_without_to_timestamp_without
		'TIMESTAMP WITH TIME ZONE AS DATE':                           cast_timestamp_with_to_date
		'TIMESTAMP WITH TIME ZONE AS TIME WITH TIME ZONE':            cast_timestamp_with_to_time_with
		'TIMESTAMP WITH TIME ZONE AS TIME WITHOUT TIME ZONE':         cast_timestamp_with_to_time_without
		'TIMESTAMP WITH TIME ZONE AS TIMESTAMP WITH TIME ZONE':       cast_timestamp_with_to_timestamp_with
		'TIMESTAMP WITH TIME ZONE AS TIMESTAMP WITHOUT TIME ZONE':    cast_timestamp_with_to_timestamp_without
		'TIMESTAMP WITHOUT TIME ZONE AS DATE':                        cast_timestamp_without_to_date
		'TIMESTAMP WITHOUT TIME ZONE AS TIME WITH TIME ZONE':         cast_timestamp_without_to_time_with
		'TIMESTAMP WITHOUT TIME ZONE AS TIME WITHOUT TIME ZONE':      cast_timestamp_without_to_time_without
		'TIMESTAMP WITHOUT TIME ZONE AS TIMESTAMP WITH TIME ZONE':    cast_timestamp_without_to_timestamp_with
		'TIMESTAMP WITHOUT TIME ZONE AS TIMESTAMP WITHOUT TIME ZONE': cast_timestamp_without_to_timestamp_without
	}

	key := '${v.typ.typ} AS ${t.typ}'
	if fnc := cast_rules[key] {
		cast_fn := fnc as CastFunc
		return cast_fn(conn, v, t)!
	}

	return sqlstate_42846(v.typ, t)
}

// check_store_assignment returns an error if a value can't be assigned to a
// column. Unlike CAST, a character string can't be assigned to a number, or a
// number to a character string.
//
// A datetime can only be assigned to the same kind of datetime (4.6.2): both
// DATE, both TIME or both TIMESTAMP (with or without a time zone).
//
// ISO/IEC 9075-2:2016(E), 9.2, Store assignment, Syntax Rules, 3
fn check_store_assignment(v Value, t Type) ! {
	if v.is_null {
		return
	}

	check_assignable(v.typ, t)!
}

// check_assignable returns an error if a value of type from can't be assigned
// to t, regardless of the value.
fn check_assignable(from Type, t Type) ! {
	if (from.typ.is_string() && t.typ.is_number()) || (from.typ.is_number() && t.typ.is_string()) {
		return sqlstate_42846(from, t)
	}

	if from.typ.is_datetime() || t.typ.is_datetime() {
		time_kinds := [SQLType.is_time_with_time_zone, .is_time_without_time_zone]
		timestamp_kinds := [SQLType.is_timestamp_with_time_zone, .is_timestamp_without_time_zone]
		if !((from.typ == .is_date && t.typ == .is_date)
			|| (from.typ in time_kinds && t.typ in time_kinds)
			|| (from.typ in timestamp_kinds && t.typ in timestamp_kinds)) {
			return sqlstate_42846(from, t)
		}
	}
}

// cast_character_to_number casts a character string to a number (ISO/IEC
// 9075-2:2016(E), 6.13, General Rules, 8.b and 9.b). Leading and trailing spaces
// are removed, and what's left must be a <signed numeric literal>.
fn cast_character_to_number(mut conn Connection, v Value, t Type) !Value {
	s := v.string_value().trim(' ')

	return match numeric_literal_kind(s) {
		.exact { cast(mut conn, '', new_numeric_value(s.trim_left('+')), t)! }
		.approximate { cast(mut conn, '', new_double_precision_value(s.f64()), t)! }
		.invalid { sqlstate_22018() }
	}
}

enum NumericLiteralKind {
	invalid
	exact       // such as 12, -1.5 or .5
	approximate // such as 1e2 or -1.5E-3
}

// numeric_literal_kind returns whether s is a <signed numeric literal> (ISO/IEC
// 9075-2:2016(E), 5.3).
fn numeric_literal_kind(s string) NumericLiteralKind {
	mut i := 0
	if i < s.len && (s[i] == `+` || s[i] == `-`) {
		i++
	}

	mut digits := 0
	for i < s.len && s[i].is_digit() {
		i++
		digits++
	}
	if i < s.len && s[i] == `.` {
		i++
		for i < s.len && s[i].is_digit() {
			i++
			digits++
		}
	}
	if digits == 0 {
		return .invalid
	}
	if i == s.len {
		return .exact
	}

	if s[i] != `e` && s[i] != `E` {
		return .invalid
	}
	i++
	if i < s.len && (s[i] == `+` || s[i] == `-`) {
		i++
	}
	exponent_start := i
	for i < s.len && s[i].is_digit() {
		i++
	}
	if i == exponent_start || i != s.len {
		return .invalid
	}

	return .approximate
}

fn cast_numeric(mut _ Connection, v Value, t Type) !Value {
	// It would be more efficient to build a matrix of every combination, but for
	// now it's easier to convert to a lossless number then the final destination
	// type.

	// A boolean or datetime can't be cast to a number.
	//
	// ISO/IEC 9075-2:2016(E), 6.13, <cast specification>, Syntax Rules, 7
	if v.typ.typ == .is_boolean || v.typ.typ.is_datetime() {
		return sqlstate_42846(v.typ, t)
	}

	match t.typ {
		.is_smallint {
			mut numeric_value := v.as_numeric()!
			check_numeric_range(numeric_value, .is_smallint)!

			return new_smallint_value(i16(numeric_value.i64()))
		}
		.is_integer {
			mut numeric_value := v.as_numeric()!
			check_numeric_range(numeric_value, .is_integer)!

			// This is a bug: https://github.com/vlang/v/issues/17637
			// There are unit tests for this, so feel free to remove this in the
			// future and see it it works.
			if numeric_value.str() == '-2147483648' {
				return new_integer_value(-2147483648)
			}

			return new_integer_value(int(numeric_value.i64()))
		}
		.is_bigint {
			mut numeric_value := v.as_numeric()!
			check_numeric_range(numeric_value, .is_bigint)!

			return new_bigint_value(numeric_value.str().i64())
		}
		.is_real {
			return approximate_value(v.as_f64()!, .is_real)
		}
		.is_double_precision {
			return approximate_value(v.as_f64()!, .is_double_precision)
		}
		.is_numeric, .is_decimal {
			mut numeric_value := v.as_numeric()!

			// We must not lose any significant figures. A NUMERIC/DECIMAL without a
			// precision has the maximum precision. We can't trust the size of the
			// existing number as all the digits may not be used.
			parts := numeric_value.str().split('.')
			if parts[0].trim_left('-').len > t.numeric_precision() - t.scale {
				// numeric value out of range
				return sqlstate_22003()
			}

			n :=
				new_numeric(t, numeric_value.numerator, numeric_value.denominator).normalize_denominator(t)

			if t.typ == .is_numeric {
				return new_numeric_value_from_numeric(n)
			}

			return new_decimal_value_from_numeric(n)
		}
		else {}
	}

	return sqlstate_42846(v.typ, t)
}

fn check_integer_range(x i64, typ SQLType) ! {
	match typ {
		.is_smallint {
			if x < -32768 || x > 32767 {
				return sqlstate_22003()
			}
		}
		.is_integer {
			if x < -2147483648 || x > 2147483647 {
				return sqlstate_22003()
			}
		}
		else {}
	}
}

// '2022-06-30' => '2022-06-30 00:00:00.000000'
fn cast_date_to_timestamp_without(_ &Connection, v Value, to Type) !Value {
	return new_timestamp_value(v.time_value().str_full_timestamp(to.size, false, true))
}

// '2022-06-30' => '2022-06-30 00:00:00.000000+05:00'
fn cast_date_to_timestamp_with(conn &Connection, v Value, to Type) !Value {
	return new_timestamp_value(v.time_value().str_full_timestamp(to.size, false, true) +
		time_zone_value(conn))
}

// '12:34:56.000000+0500' => '12:34:56.000000'
fn cast_time_with_to_time_without(_ &Connection, v Value, to Type) !Value {
	return new_time_value(v.time_value().str_full_time(to.size, false, true))
}

// '12:34:56.999999' => '12:34:56.999999+0500'
fn cast_time_without_to_time_with(conn &Connection, v Value, to Type) !Value {
	return new_time_value(v.time_value().str_full_time(to.size, false, true) + time_zone_value(conn))
}

// When a TIME is cast to a TIMESTAMP the date is the same as CURRENT_DATE.
//
// ISO/IEC 9075-2:2016(E), 6.13, <cast specification>, General Rules, 18 and 19
fn current_date_str(conn &Connection) string {
	now := local_now(conn)

	return now.strftime('%Y-%m-%d')
}

// '12:34:56.999999+0500' => '2022-06-30 12:34:56.999999+0500'
fn cast_time_with_to_timestamp_with(conn &Connection, v Value, to Type) !Value {
	return new_timestamp_value(current_date_str(conn) + ' ' +
		v.time_value().str_full_time(to.size, true, true))
}

// '12:34:56.999999+0500' => '2022-06-30 12:34:56.999999'
fn cast_time_with_to_timestamp_without(conn &Connection, v Value, to Type) !Value {
	return new_timestamp_value(current_date_str(conn) + ' ' +
		v.time_value().str_full_time(to.size, false, true))
}

// '12:34:56.999999' => '2022-06-30 12:34:56.999999+0500'
fn cast_time_without_to_timestamp_with(conn &Connection, v Value, to Type) !Value {
	return new_timestamp_value(current_date_str(conn) + ' ' +
		v.time_value().str_full_time(to.size, false, true) + time_zone_value(conn))
}

// '12:34:56.999999' => '2022-06-30 12:34:56.999999'
fn cast_time_without_to_timestamp_without(conn &Connection, v Value, to Type) !Value {
	return new_timestamp_value(current_date_str(conn) + ' ' +
		v.time_value().str_full_time(to.size, false, true))
}

// '2022-06-30 12:34:56.999999+0500' => '2022-06-30'
fn cast_timestamp_with_to_date(_ &Connection, v Value, _ Type) !Value {
	return new_date_value(v.time_value().str_date())
}

// '2022-06-30 12:34:56.999999+0500' => '12:34:56.999999+0500'
fn cast_timestamp_with_to_time_with(_ &Connection, v Value, to Type) !Value {
	return new_time_value(v.time_value().str_full_time(to.size, true, true))
}

// '2022-06-30 12:34:56.999999+0500' => '12:34:56.999999'
fn cast_timestamp_with_to_time_without(_ &Connection, v Value, to Type) !Value {
	return new_time_value(v.time_value().str_full_time(to.size, false, true))
}

// '2022-06-30 12:34:56.999999+0500' => '2022-06-30 12:34:56.999999'
fn cast_timestamp_with_to_timestamp_without(_ &Connection, v Value, to Type) !Value {
	return new_timestamp_value(v.time_value().str_full_timestamp(to.size, false, true))
}

// '12:34:56.999999+0500' => '12:34:56.999999+0500'
fn cast_time_with_to_time_with(_ &Connection, v Value, to Type) !Value {
	return new_time_value(v.time_value().str_full_time(to.size, true, true))
}

// '12:34:56.999999' => '12:34:56.999999'
fn cast_time_without_to_time_without(_ &Connection, v Value, to Type) !Value {
	return new_time_value(v.time_value().str_full_time(to.size, false, true))
}

// '2022-06-30 12:34:56.999999+0500' => '2022-06-30 12:34:56.999999+0500'
fn cast_timestamp_with_to_timestamp_with(_ &Connection, v Value, to Type) !Value {
	return new_timestamp_value(v.time_value().str_full_timestamp(to.size, true, true))
}

// '2022-06-30 12:34:56.999999' => '2022-06-30'
fn cast_timestamp_without_to_date(_ &Connection, v Value, _ Type) !Value {
	return new_date_value(v.time_value().str_date())
}

// '2022-06-30 12:34:56.999999' => '12:34:56.999999+0500'
fn cast_timestamp_without_to_time_with(conn &Connection, v Value, to Type) !Value {
	return new_time_value(v.time_value().str_full_time(to.size, false, true) + time_zone_value(conn))
}

// '2022-06-30 12:34:56.999999' => '12:34:56.999999'
fn cast_timestamp_without_to_time_without(_ &Connection, v Value, to Type) !Value {
	return new_time_value(v.time_value().str_full_time(to.size, false, true))
}

// '2022-06-30 12:34:56.999999' => '2022-06-30 12:34:56.999999+0500'
fn cast_timestamp_without_to_timestamp_with(conn &Connection, v Value, to Type) !Value {
	return new_timestamp_value(v.time_value().str_full_timestamp(to.size, false, true) +
		time_zone_value(conn))
}

// '2022-06-30 12:34:56.999999' => '2022-06-30 12:34:56.999999'
fn cast_timestamp_without_to_timestamp_without(_ &Connection, v Value, to Type) !Value {
	return new_timestamp_value(v.time_value().str_full_timestamp(to.size, false, true))
}

fn check_numeric_range(x Numeric, typ SQLType) ! {
	match typ {
		.is_smallint {
			if x.less_than(min_smallint) || x.greater_than(max_smallint) {
				return sqlstate_22003()
			}
		}
		.is_integer {
			if x.less_than(min_integer) || x.greater_than(max_integer) {
				return sqlstate_22003()
			}
		}
		.is_bigint {
			if x.less_than(min_bigint) || x.greater_than(max_bigint) {
				return sqlstate_22003()
			}
		}
		else {}
	}
}
