module vsql

import strings

// ISO/IEC 9075-2:2016(E), 9.2, Store assignment
//
// Specify rules for assignments where the target permits null without the use
// of indicator parameters or indicator variables, such as storing SQL-data or
// setting the value of SQL parameters.

const min_smallint = new_numeric_from_string('-32768')

const max_smallint = new_numeric_from_string('32767')

const min_integer = new_numeric_from_string('-2147483648')

const max_integer = new_numeric_from_string('2147483647')

const min_bigint = new_numeric_from_string('-9223372036854775808')

const max_bigint = new_numeric_from_string('9223372036854775807')

type CastFunc = fn (conn &Connection, v Value, to Type) !Value

// explicit cast follows the rules outlined in Subclause 9.2,
// "Store assignment", in ISO/IEC 9075-2.
fn cast(mut conn Connection, msg string, v Value, t Type) !Value {
	// - 1. Let T be the TARGET and let V be the VALUE in an application of the
	// General Rules of this Subclause.

	// - 2. If the declared type of V is not assignable to the declared type of T,
	// then for the remaining General Rules of this Subclause V is effectively
	// replaced by the result of evaluating the expression UDCF(V).
	//
	// User-defined cast functions are not currently supported.

	// - 3. Case:
	// - 3.a. If V is the null value, then Case:
	if v.is_null {
		// - 3.a.i. If V is specified using NULL, then T is set to the null value.
		if !v.typ.not_null {
			return v
		}

		// - 3.a.ii. If V is a host parameter and contains an indicator parameter,
		// then, Case:
		//
		// - 3.a.ii.1. If the value of the indicator parameter is equal to –1
		// (negative one), then T is set to the null value.
		//
		// - 3.a.ii.2. If the value of the indicator parameter is less than –1
		// (negative one), then an exception condition is raised: data exception —
		// invalid indicator parameter value.
		//
		// - 3.a.iii. If V is a host variable and contains an indicator variable,
		// then Case:
		//
		// - 3.a.iii.1. If the value of the indicator variable is equal to –1
		// (negative one), then T is set to the null value.
		//
		// - 3.a.iii.2. If the value of the indicator variable is less than –1
		// (negative one), then an exception con- dition is raised: data exception —
		// invalid indicator parameter value.
		//
		// - 3.a.iv. Otherwise, T is set to the null value.
		//
		// Declaring host parameters is not supported yet, so fallthough.
	}

	// - 3.b. Otherwise, Case:
	match t.typ {
		.is_character {
			// - 3.b.i. If the declared type of T is fixed-length character string
			// with length in characters L and the length in characters of V is equal
			// to L, then the value of T is set to V.
			//
			// It doesn't state that the destination needs to also be a
			// character-type. This is what allows any string representation (for
			// example numbers) to be converted to a string, provided they still fit
			// all the same requirements.
			s := v.str()

			l := t.size
			if l == s.len {
				return new_character_value(s)
			}

			// - 3.b.ii. If the declared type of T is fixed-length character string
			// with length in characters L and the length in characters M of V is
			// larger than L, then, Case:
			m := s.len
			if m > l {
				// - 3.b.ii.1. If the rightmost M–L characters of V are all <space>s,
				// then the value of T is set to the first L characters of V.
				if s[l..].trim_space() == '' {
					return new_character_value(s[..l])
				}

				// - 3.b.ii.2. If one or more of the rightmost M–L characters of V are
				// not <space>s, then an exception condition is raised: data exception —
				// string data, right truncation.
				return sqlstate_22001(t)
			} else {
				// - 3.b.iii. If the declared type of T is fixed-length character string
				// with length in characters L and the length in characters M of V is
				// less than L, then the first M characters of T are set to V and the
				// last L–M characters of T are set to <space>s.
				pad := strings.repeat(` `, l - m)
				return new_character_value(s + pad)
			}
		}
		.is_varchar {
			// - 3.b.iv. If the declared type of T is variable-length character string
			// and the length in characters M of V is not greater than the maximum
			// length in characters of T, then the value of T is set to V and the
			// length in characters of T is set to M.
			//
			// See note above about using v.str() instead of string_value().
			s := v.str()

			l := t.size
			m := s.len
			if m <= l {
				return new_varchar_value(s)
			}

			// - 3.b.v. If the declared type of T is variable-length character string
			// and the length in characters M of V is greater than the maximum length
			// in characters L of T, then, Case:
			pad := strings.repeat(` `, m - l)
			if pad == s[l..] {
				// - 3.b.v.1. If the rightmost M–L characters of V are all <space>s,
				// then the value of T is set to the first L characters of V and the
				// length in characters of T is set to L.
				return new_varchar_value(s[..l])
			}

			// - 3.b.v.2. If one or more of the rightmost M–L characters of V are
			// not <space>s, then an exception condition is raised: data exception —
			// string data, right truncation.
			return sqlstate_22001(t)
		}
		// - 3.b.vi. If the declared type of T is a character large object type and
		// the length in characters M of V is not greater than the maximum length in
		// characters of T, then the value of T is set to V and the length in
		// characters of T is set to M.
		// - 3.b.vii. If the declared type of T is a character large object type and
		// the length in characters M of V is greater than the maximum length in
		// characters L of T, then, Case:
		// - 3.b.vii.1. If the rightmost M–L characters of V are all <space>s, then
		// the value of T is set to the first L characters of V and the length in
		// characters of T is set to L.
		// - 3.b.vii.2. If one or more of the rightmost M–L characters of V are not
		// <space>s, then an exception condition is raised: data exception — string
		// data, right truncation.
		// - 3.b.viii. If the declared type of T is fixed-length binary string with
		// length in octets L and the length in octets of V is equal to L, then the
		// value of T is set to V.
		// - 3.b.ix. If the declared type of T is fixed-length binary string with
		// length in octets L and the length in octets M of V is larger than L,
		// then, Case:
		// - 3.b.ix.1. If the rightmost M–L octets of V are all equal to X'00', then
		// the value of T is set to the first L octets of V.
		// - 3.b.ix.2. If one or more of the rightmost M–L octets of V are not equal
		// to X'00', then an exception condition is raised: data exception — string
		// data, right truncation.
		// - 3.b.x. If the declared type of T is fixed-length binary string with
		// length in octets L and the length in octets M of V is less than L, then
		// the first M octets of T are set to V and the last L–M octets of T are set
		// to X'00's.
		// - 3.b.xi. If the declared type of T is variable-length binary string and
		// the length in octets M of V is not greater than the maximum length in
		// octets of T, then the value of T is set to V and the length in octets of
		// T is set to M.
		// - 3.b.xii. If the declared type of T is variable-length binary string and
		// the length in octets M of V is greater than the maximum length in octets
		// L of T, then, Case:
		// - 3.b.xii.1. If the rightmost M–L octets of V are all equal to X'00',
		// then the value of T is set to the first L octets of V and the length in
		// octets of T is set to L.
		// - 3.b.xii.2. If one or more of the rightmost M–L octets of V are not
		// equal to X'00', then an exception condition is raised: data exception —
		// string data, right truncation.
		// - 3.b.xiii. If the declared type of T is binary large object string and
		// the length in octets M of V is not greater than the maximum length in
		// octets of T, then the value of T is set to V and the length in octets of
		// T is set to M.
		// - 3.b.xiv. If the declared type of T is binary large object string and
		// the length in octets M of V is greater than the maximum length in octets
		// L of T, then, Case:
		// - 3.b.xiv.1. If the rightmost M–L octets of V are all equal to X'00',
		// then the value of T is set to the first L octets of V and the length in
		// octets of T is set to L.
		// - 3.b.xiv.2. If one or more of the rightmost M–L octets of V are not
		// equal to X'00', then an exception condition is raised: data exception —
		// string data, right truncation.
		//
		// All of these are not supported types, so fallthrough.
		//
		.is_numeric, .is_decimal, .is_smallint, .is_integer, .is_bigint, .is_real,
		.is_double_precision {
			// - 3.b.xv. If the declared type of T is numeric, then, Case:
			// - 3.b.xv.1. If V is a value of the declared type of T, then the value
			// of T is set to V.
			if v.typ == t {
				return v
			}

			// - 3.b.xv.2. If a value of the declared type of T can be obtained from V
			// by rounding or truncation, then the value of T is set to that value.
			// If the declared type of T is exact numeric, then it is
			// implementation-defined whether the approximation is obtained by
			// rounding or by truncation.
			//
			// - 3.b.xv.3. Otherwise, an exception condition is raised: data exception
			// — numeric value out of range.
			//
			// Both cases are handled by cast_numeric.
			return cast_numeric(mut conn, v, t)
		}
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone, .is_date,
		.is_time_with_time_zone, .is_time_without_time_zone {
			// - 3.b.xvi. If the declared type DT of T is datetime, then
			//
			// - 3.b.xvi.1. If only one of DT and the declared type of V is datetime
			// with time zone, then V is effectively replaced by: CAST ( V AS DT )
			if t.typ == .is_timestamp_with_time_zone && v.typ.typ == .is_timestamp_without_time_zone {
				return cast(mut conn, msg, cast_timestamp_without_to_timestamp_with(conn,
					v, t)!, t)
			}
			if t.typ == .is_timestamp_without_time_zone && v.typ.typ == .is_timestamp_with_time_zone {
				return cast(mut conn, msg, cast_timestamp_with_to_timestamp_without(conn,
					v, t)!, t)
			}

			// - 3.b.xvi.2. Case:
			//
			// - 3.b.xvi.2.A. If V is a value of the declared type of T, then the
			// value of T is set to V.
			if v.typ == t {
				return v
			}

			// - 3.b.xvi.2.B. If a value of the declared type of T can be obtained
			// from V by rounding or truncation, then the value of T is set to that
			// value. It is implementation-defined whether the approximation is
			// obtained by rounding or truncation.
			//
			// I'm going to assume this also leaves open the opportunity to cast
			// between different types like DATE to TIMESTAMP.
			return cast_datetime(conn, v, t)

			// - 3.b.xvi.2.C. Otherwise, an exception condition is raised: data
			// exception — datetime field overflow.
			//
			// This is not possible right now since the range is already validated at
			// the time the timestamp is created.
		}
		// - 3.b.xvii. If the declared type of T is interval, then, Case:
		//
		// - 3.b.xvii.1. If V is a value of the declared type of T, then the value
		// of T is set to V.
		//
		// - 3.b.xvii.2. If a value of the declared type of T can be obtained from V
		// by rounding or truncation, then the value of T is set to that value. It
		// is implementation-defined whether the approximation is obtained by
		// rounding or by truncation.
		//
		// - 3.b.xvii.3. Otherwise, an exception condition is raised: data exception
		// — interval field overflow.
		//
		// INTERVAL type is not supported yet.
		.is_boolean {
			// - 3.b.xviii. If the declared type of T is boolean, then the value of T
			// is set to V.
			//
			// This seems oddly ambigious to me, they don't specify that the value
			// it's coming from must also be a BOOLEAN, so for now we must assume this
			// is not permitted.
			if v.typ.typ == .is_boolean {
				return v
			}
		}
		// - 3.b.xix. If the declared type of T is a row type, then:
		// - 3.b.xix.1. Let n be the degree of T.
		// - 3.b.xix.2. For i ranging from 1 (one) to n, the General Rules of this
		// Subclause are applied to the i-th element of T and the i-th element of V
		// as TARGET and VALUE, respectively.
		// - 3.b.xx. If the declared type of T is a reference type, then the value
		// of T is set to V.
		// - 3.b.xxi. If the declared type of T is an array type or a distinct type
		// whose source type is an array type, then, Case:
		// - 3.b.xxi.1. If the maximum cardinality L of T is equal to the
		// cardinality M of V, then the elements of T are set to the values of the
		// corresponding elements of V by applying the General Rules of this
		// Subclause to each pair of elements with the element of T as TARGET and
		// the element of V as VALUE.
		// - 3.b.xxi.2. If the maximum cardinality L of T is smaller than the
		// cardinality M of V, then Case:
		// - 3.b.xxi.2.A. If the rightmost M–L elements of V are all null, then the
		// elements of T are set to the values of the first L corresponding elements
		// of V by applying the General Rules of this Subclause to each pair of
		// elements with the element of T as TARGET and the element of V as VALUE.
		// - 3.b.xxi.2.B. If one or more of the rightmost M–L elements of V are not
		// the null value, then an exception condition is raised: data exception —
		// array data, right truncation.
		// - 3.b.xxi.3. If the maximum cardinality L of T is greater than the
		// cardinality M of V, then the M first elements of T are set to the values
		// of the corresponding elements of V by applying the General Rules of this
		// Subclause to each pair of elements with the element of T as TARGET and
		// the element of V as VALUE. The cardinality of the value of T is set to M.
		// NOTE 363 — The maximum cardinality L of T is unchanged.
		// - 3.b.xxii. If the declared type of T is a multiset type or a distinct
		// type whose source type is a multiset type, then the value of T is set to
		// V.
		// - 3.b.xxiii. If the declared type of T is a user-defined type, then the
		// value of T is set to V.
		//
		// All of these are not supported yet.
	}

	return sqlstate_42846(v.typ, t)
}

fn cast_datetime(conn Connection, v Value, t Type) !Value {
	cast_rules := {
		'DATE AS TIMESTAMP WITHOUT TIME ZONE':                        CastFunc(cast_date_to_timestamp_without)
		'DATE AS TIMESTAMP WITH TIME ZONE':                           cast_date_to_timestamp_with
		'TIME WITH TIME ZONE AS TIME WITH TIME ZONE':                 cast_time_with_to_time_with
		'TIME WITH TIME ZONE AS TIME WITHOUT TIME ZONE':              cast_time_with_to_time_without
		'TIME WITHOUT TIME ZONE AS TIME WITHOUT TIME ZONE':           cast_time_without_to_time_without
		'TIME WITHOUT TIME ZONE AS TIME WITH TIME ZONE':              cast_time_without_to_time_with
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

fn cast_numeric(mut conn Connection, v Value, t Type) !Value {
	// It would be more efficient to build a matrix of every combination, but for
	// now it's easier to convert to a lossless number then the final destination
	// type.

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
			return new_real_value(f32(v.as_f64()!))
		}
		.is_double_precision {
			return new_double_precision_value(v.as_f64()!)
		}
		.is_numeric, .is_decimal {
			// There is a special case where we should pass through an already
			// NUMERIC/DECIMAL value if there is no specified destination precision.
			// This will prevent as_numeric() from truncating the extra NUMERIC
			// precision. Technically this is not required for NUMERIC, but it's just
			// more efficient to avoid the reparsing below.
			if t.size == 0 && (v.typ.typ == .is_numeric || v.typ.typ == .is_decimal) {
				return v
			}

			mut numeric_value := v.as_numeric()!

			// If the destination size = 0, then this is a cast to NUMERIC/DECIMAL and
			// so we determine the size and scale from the original rules of a NUMERIC
			// literal.
			if t.size == 0 {
				if t.typ == .is_numeric {
					return new_numeric_value(numeric_value.str())
				}

				return new_decimal_value(numeric_value.str())
			}

			// We must not lose any significant figures. We can't trust the size of
			// the existing number as all the digits may not be used.
			parts := numeric_value.str().split('.')
			if parts[0].trim_left('-').len > t.size - t.scale {
				// numeric value out of range
				return sqlstate_22003()
			}

			n := new_numeric(t, numeric_value.numerator, numeric_value.denominator).normalize_denominator(t)

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

fn check_floating_range(x f64, typ SQLType) ! {
	match typ {
		.is_smallint {
			if x < -32768.0 || x > 32767.0 {
				return sqlstate_22003()
			}
		}
		.is_integer {
			if x < -2147483648.0 || x > 2147483647.0 {
				return sqlstate_22003()
			}
		}
		.is_bigint {
			if x < -9223372036854775808.0 || x > 9223372036854775807.0 {
				return sqlstate_22003()
			}
		}
		else {}
	}
}

// '2022-06-30' => '2022-06-30 00:00:00.000000'
fn cast_date_to_timestamp_without(conn &Connection, v Value, to Type) !Value {
	return new_timestamp_value(v.time_value().str_full_timestamp(to.size, false, true))
}

// '2022-06-30' => '2022-06-30 00:00:00.000000+05:00'
fn cast_date_to_timestamp_with(conn &Connection, v Value, to Type) !Value {
	return new_timestamp_value(v.time_value().str_full_timestamp(to.size, false, true) +
		time_zone_value(conn))
}

// '12:34:56.000000+0500' => '12:34:56.000000'
fn cast_time_with_to_time_without(conn &Connection, v Value, to Type) !Value {
	return new_time_value(v.time_value().str_full_time(to.size, false, true))
}

// '12:34:56.999999' => '12:34:56.999999+0500'
fn cast_time_without_to_time_with(conn &Connection, v Value, to Type) !Value {
	return new_time_value(v.time_value().str_full_time(to.size, false, true) + time_zone_value(conn))
}

// '2022-06-30 12:34:56.999999+0500' => '2022-06-30'
fn cast_timestamp_with_to_date(conn &Connection, v Value, to Type) !Value {
	return new_date_value(v.time_value().str_date())
}

// '2022-06-30 12:34:56.999999+0500' => '12:34:56.999999+0500'
fn cast_timestamp_with_to_time_with(conn &Connection, v Value, to Type) !Value {
	return new_time_value(v.time_value().str_full_time(to.size, true, true))
}

// '2022-06-30 12:34:56.999999+0500' => '12:34:56.999999'
fn cast_timestamp_with_to_time_without(conn &Connection, v Value, to Type) !Value {
	return new_time_value(v.time_value().str_full_time(to.size, false, true))
}

// '2022-06-30 12:34:56.999999+0500' => '2022-06-30 12:34:56.999999'
fn cast_timestamp_with_to_timestamp_without(conn &Connection, v Value, to Type) !Value {
	return new_timestamp_value(v.time_value().str_full_timestamp(to.size, false, true))
}

// '12:34:56.999999+0500' => '12:34:56.999999+0500'
fn cast_time_with_to_time_with(conn &Connection, v Value, to Type) !Value {
	return new_time_value(v.time_value().str_full_time(to.size, true, true))
}

// '12:34:56.999999' => '12:34:56.999999'
fn cast_time_without_to_time_without(conn &Connection, v Value, to Type) !Value {
	return new_time_value(v.time_value().str_full_time(to.size, false, true))
}

// '2022-06-30 12:34:56.999999+0500' => '2022-06-30 12:34:56.999999+0500'
fn cast_timestamp_with_to_timestamp_with(conn &Connection, v Value, to Type) !Value {
	return new_timestamp_value(v.time_value().str_full_timestamp(to.size, true, true))
}

// '2022-06-30 12:34:56.999999' => '2022-06-30'
fn cast_timestamp_without_to_date(conn &Connection, v Value, to Type) !Value {
	return new_date_value(v.time_value().str_date())
}

// '2022-06-30 12:34:56.999999' => '12:34:56.999999+0500'
fn cast_timestamp_without_to_time_with(conn &Connection, v Value, to Type) !Value {
	return new_time_value(v.time_value().str_full_time(to.size, false, true) + time_zone_value(conn))
}

// '2022-06-30 12:34:56.999999' => '12:34:56.999999'
fn cast_timestamp_without_to_time_without(conn &Connection, v Value, to Type) !Value {
	return new_time_value(v.time_value().str_full_time(to.size, false, true))
}

// '2022-06-30 12:34:56.999999' => '2022-06-30 12:34:56.999999+0500'
fn cast_timestamp_without_to_timestamp_with(conn &Connection, v Value, to Type) !Value {
	return new_timestamp_value(v.time_value().str_full_timestamp(to.size, false, true) +
		time_zone_value(conn))
}

// '2022-06-30 12:34:56.999999' => '2022-06-30 12:34:56.999999'
fn cast_timestamp_without_to_timestamp_without(conn &Connection, v Value, to Type) !Value {
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
