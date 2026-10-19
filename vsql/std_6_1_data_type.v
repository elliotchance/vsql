module vsql

// ISO/IEC 9075-2:2016(E), 6.1, <data type>
//
// Specify a data type.

// parse_type_with_length is used for a data type with an explicit <length>,
// which must be greater than 0 (6.1 Syntax Rule 4).
fn parse_type_with_length(name string, length string) !Type {
	if length.int() < 1 {
		return sqlstate_42601('${name} length must be greater than 0')
	}

	return new_type(name, length.int(), 0)
}

// parse_type_with_precision is used for a data type with an explicit
// <precision>, which must be greater than 0 (6.1 Syntax Rule 21). The <scale>
// must not be greater than the <precision> (6.1 Syntax Rule 23).
fn parse_type_with_precision(name string, precision string, scale string) !Type {
	if precision.int() < 1 {
		return sqlstate_42601('${name} precision must be greater than 0')
	}

	if scale.int() > precision.int() {
		return sqlstate_42601('${name} scale (${scale}) must not be greater than precision (${precision})')
	}

	return new_type(name, precision.int(), i16(scale.int()))
}

fn parse_timestamp_prec_tz_type(prec string, tz bool) !Type {
	check_fractional_seconds_precision('TIMESTAMP', prec)!

	if tz {
		return new_type('TIMESTAMP WITH TIME ZONE', prec.int(), 0)
	}

	return new_type('TIMESTAMP WITHOUT TIME ZONE', prec.int(), 0)
}

fn parse_time_prec_tz_type(prec string, tz bool) !Type {
	check_fractional_seconds_precision('TIME', prec)!

	if tz {
		return new_type('TIME WITH TIME ZONE', prec.int(), 0)
	}

	return new_type('TIME WITHOUT TIME ZONE', prec.int(), 0)
}

// ISO/IEC 9075-2:2016(E), 6.1, 38) The maximum value of <time precision> and
// the maximum value of <timestamp precision> shall be the same
// implementation-defined value that is not less than 6.
fn check_fractional_seconds_precision(name string, prec string) ! {
	if prec.int() > 6 {
		return sqlstate_42601('${name}(${prec}): cannot have precision greater than 6')
	}
}
