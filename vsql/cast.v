// cast.v handles the conversion of a value from one type to another.

module vsql

// TODO(elliotchance): This should be rewritten to follow the table in
//  <cast specification>.

type CastFunc = fn (conn &Connection, v Value, to Type) !Value

fn register_cast_rules(mut conn Connection) {
	conn.cast_rules['BOOLEAN AS BOOLEAN'] = cast_passthru
	conn.cast_rules['SMALLINT AS SMALLINT'] = cast_passthru
	conn.cast_rules['SMALLINT AS INTEGER'] = cast_smallint_to_integer
	conn.cast_rules['SMALLINT AS BIGINT'] = cast_smallint_to_bigint
	conn.cast_rules['SMALLINT AS REAL'] = cast_smallint_to_real
	conn.cast_rules['SMALLINT AS DOUBLE PRECISION'] = cast_smallint_to_double_precision
	conn.cast_rules['INTEGER AS SMALLINT'] = cast_integer_to_smallint
	conn.cast_rules['INTEGER AS INTEGER'] = cast_passthru
	conn.cast_rules['INTEGER AS BIGINT'] = cast_integer_to_bigint
	conn.cast_rules['INTEGER AS REAL'] = cast_integer_to_real
	conn.cast_rules['INTEGER AS DOUBLE PRECISION'] = cast_integer_to_double_precision
	conn.cast_rules['BIGINT AS SMALLINT'] = cast_bigint_to_smallint
	conn.cast_rules['BIGINT AS INTEGER'] = cast_bigint_to_integer
	conn.cast_rules['BIGINT AS BIGINT'] = cast_passthru
	conn.cast_rules['BIGINT AS REAL'] = cast_bigint_to_real
	conn.cast_rules['BIGINT AS DOUBLE PRECISION'] = cast_bigint_to_double_precision
	conn.cast_rules['REAL AS SMALLINT'] = cast_real_to_smallint
	conn.cast_rules['REAL AS INTEGER'] = cast_real_to_integer
	conn.cast_rules['REAL AS BIGINT'] = cast_real_to_bigint
	conn.cast_rules['REAL AS REAL'] = cast_passthru
	conn.cast_rules['REAL AS DOUBLE PRECISION'] = cast_real_to_double_precision
	conn.cast_rules['DOUBLE PRECISION AS SMALLINT'] = cast_double_precision_to_smallint
	conn.cast_rules['DOUBLE PRECISION AS INTEGER'] = cast_double_precision_to_integer
	conn.cast_rules['DOUBLE PRECISION AS BIGINT'] = cast_double_precision_to_bigint
	conn.cast_rules['DOUBLE PRECISION AS REAL'] = cast_double_precision_to_real
	conn.cast_rules['DOUBLE PRECISION AS DOUBLE PRECISION'] = cast_passthru
	conn.cast_rules['CHARACTER VARYING AS CHARACTER VARYING'] = cast_varchar_to_varchar
	conn.cast_rules['CHARACTER VARYING AS CHARACTER'] = cast_varchar_to_character
	conn.cast_rules['CHARACTER AS CHARACTER VARYING'] = cast_character_to_varchar
	conn.cast_rules['CHARACTER AS CHARACTER'] = cast_character_to_character
	conn.cast_rules['DATE AS DATE'] = cast_passthru
	conn.cast_rules['DATE AS TIMESTAMP WITHOUT TIME ZONE'] = cast_date_to_timestamp_without
	conn.cast_rules['DATE AS TIMESTAMP WITH TIME ZONE'] = cast_date_to_timestamp_with
	conn.cast_rules['TIME WITH TIME ZONE AS TIME WITH TIME ZONE'] = cast_time_with_to_time_with
	conn.cast_rules['TIME WITH TIME ZONE AS TIME WITHOUT TIME ZONE'] = cast_time_with_to_time_without
	conn.cast_rules['TIME WITHOUT TIME ZONE AS TIME WITHOUT TIME ZONE'] = cast_time_without_to_time_without
	conn.cast_rules['TIME WITHOUT TIME ZONE AS TIME WITH TIME ZONE'] = cast_time_without_to_time_with
	conn.cast_rules['TIMESTAMP WITH TIME ZONE AS DATE'] = cast_timestamp_with_to_date
	conn.cast_rules['TIMESTAMP WITH TIME ZONE AS TIME WITH TIME ZONE'] = cast_timestamp_with_to_time_with
	conn.cast_rules['TIMESTAMP WITH TIME ZONE AS TIME WITHOUT TIME ZONE'] = cast_timestamp_with_to_time_without
	conn.cast_rules['TIMESTAMP WITH TIME ZONE AS TIMESTAMP WITH TIME ZONE'] = cast_timestamp_with_to_timestamp_with
	conn.cast_rules['TIMESTAMP WITH TIME ZONE AS TIMESTAMP WITHOUT TIME ZONE'] = cast_timestamp_with_to_timestamp_without
	conn.cast_rules['TIMESTAMP WITHOUT TIME ZONE AS DATE'] = cast_timestamp_without_to_date
	conn.cast_rules['TIMESTAMP WITHOUT TIME ZONE AS TIME WITH TIME ZONE'] = cast_timestamp_without_to_time_with
	conn.cast_rules['TIMESTAMP WITHOUT TIME ZONE AS TIME WITHOUT TIME ZONE'] = cast_timestamp_without_to_time_without
	conn.cast_rules['TIMESTAMP WITHOUT TIME ZONE AS TIMESTAMP WITH TIME ZONE'] = cast_timestamp_without_to_timestamp_with
	conn.cast_rules['TIMESTAMP WITHOUT TIME ZONE AS TIMESTAMP WITHOUT TIME ZONE'] = cast_timestamp_without_to_timestamp_without
}

fn cast(conn &Connection, msg string, v Value, to Type) !Value {
	// For now, all NULLs are allowed to be converted to any other NULL. This
	// should not technically be true, but it will do for now.
	if v.is_null {
		return new_null_value(to.typ)
	}

	key := '${v.typ.typ} AS ${to.typ}'
	if fnc := conn.cast_rules[key] {
		cast_fn := fnc as CastFunc
		return cast_fn(conn, v, to)!
	}

	return sqlstate_42846(v.typ, to)
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

fn cast_passthru(conn &Connection, v Value, to Type) !Value {
	return v
}

fn cast_bigint_to_smallint(conn &Connection, v Value, to Type) !Value {
	check_integer_range(v.int_value(), .is_smallint)!

	return new_smallint_value(i16(v.int_value()))
}

fn cast_bigint_to_integer(conn &Connection, v Value, to Type) !Value {
	check_integer_range(v.int_value(), .is_integer)!

	return new_integer_value(int(v.int_value()))
}

fn cast_bigint_to_real(conn &Connection, v Value, to Type) !Value {
	return new_real_value(f32(v.int_value()))
}

fn cast_bigint_to_double_precision(conn &Connection, v Value, to Type) !Value {
	return new_double_precision_value(f64(v.int_value()))
}

fn cast_smallint_to_integer(conn &Connection, v Value, to Type) !Value {
	return new_integer_value(int(v.int_value()))
}

fn cast_smallint_to_bigint(conn &Connection, v Value, to Type) !Value {
	return new_bigint_value(int(v.int_value()))
}

fn cast_smallint_to_real(conn &Connection, v Value, to Type) !Value {
	return new_real_value(f32(v.int_value()))
}

fn cast_smallint_to_double_precision(conn &Connection, v Value, to Type) !Value {
	return new_double_precision_value(f64(v.int_value()))
}

fn cast_integer_to_smallint(conn &Connection, v Value, to Type) !Value {
	check_integer_range(v.int_value(), .is_smallint)!

	return new_smallint_value(i16(v.int_value()))
}

fn cast_integer_to_bigint(conn &Connection, v Value, to Type) !Value {
	return new_bigint_value(int(v.int_value()))
}

fn cast_integer_to_real(conn &Connection, v Value, to Type) !Value {
	return new_real_value(f32(v.int_value()))
}

fn cast_integer_to_double_precision(conn &Connection, v Value, to Type) !Value {
	return new_double_precision_value(f64(v.int_value()))
}

fn cast_real_to_smallint(conn &Connection, v Value, to Type) !Value {
	check_floating_range(v.f64_value(), .is_smallint)!

	return new_smallint_value(i16(v.f64_value()))
}

fn cast_real_to_integer(conn &Connection, v Value, to Type) !Value {
	check_floating_range(v.f64_value(), .is_integer)!

	return new_integer_value(int(v.f64_value()))
}

fn cast_real_to_bigint(conn &Connection, v Value, to Type) !Value {
	check_floating_range(v.f64_value(), .is_bigint)!

	return new_bigint_value(i64(v.f64_value()))
}

fn cast_real_to_double_precision(conn &Connection, v Value, to Type) !Value {
	return new_double_precision_value(f64(v.f64_value()))
}

fn cast_double_precision_to_smallint(conn &Connection, v Value, to Type) !Value {
	check_floating_range(v.f64_value(), .is_smallint)!

	return new_smallint_value(i16(v.f64_value()))
}

fn cast_double_precision_to_integer(conn &Connection, v Value, to Type) !Value {
	check_floating_range(v.f64_value(), .is_integer)!

	return new_integer_value(int(v.f64_value()))
}

fn cast_double_precision_to_bigint(conn &Connection, v Value, to Type) !Value {
	check_floating_range(v.f64_value(), .is_bigint)!

	return new_bigint_value(i64(v.f64_value()))
}

fn cast_double_precision_to_real(conn &Connection, v Value, to Type) !Value {
	return new_real_value(f32(v.f64_value()))
}

fn cast_varchar_to_varchar(conn &Connection, v Value, to Type) !Value {
	if to.size > 0 && v.string_value().len > to.size {
		return sqlstate_22001(to)
	}

	return new_varchar_value(v.string_value(), to.size)
}

fn cast_varchar_to_character(conn &Connection, v Value, to Type) !Value {
	if to.size > 0 && v.string_value().len > to.size {
		return sqlstate_22001(to)
	}

	return new_character_value(v.string_value(), to.size)
}

fn cast_character_to_varchar(conn &Connection, v Value, to Type) !Value {
	if to.size > 0 && v.string_value().len > to.size {
		return sqlstate_22001(to)
	}

	return new_varchar_value(v.string_value(), to.size)
}

fn cast_character_to_character(conn &Connection, v Value, to Type) !Value {
	if to.size > 0 && v.string_value().len > to.size {
		return sqlstate_22001(to)
	}

	return new_character_value(v.string_value(), to.size)
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
