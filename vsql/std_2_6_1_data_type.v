module vsql

// ISO/IEC 9075-2:2016(E), 6.1, <data type>
//
// Specify a data type.
//
// The concepts are described by:
//
// ISO/IEC 9075-1:2003(E), 4.4.3.2, Character string types
// ISO/IEC 9075-1:2003(E), 4.6.2, Descriptors relating to character sets
// ISO/IEC 9075-1:2003(E), 4.6.2.1, Character sets
// ISO/IEC 9075-1:2003(E), 4.6.2.2, Collations
// ISO/IEC 9075-2:2016(E), 4.1, Data types
// ISO/IEC 9075-2:2016(E), 4.2, Character strings
// ISO/IEC 9075-2:2016(E), 4.4, Numbers
// ISO/IEC 9075-2:2016(E), 4.6, Datetimes and intervals

// max_character_length is the maximum <length> of a CHARACTER or CHARACTER
// VARYING (6.1 Syntax Rule 15).
const max_character_length = 10485760

// max_numeric_precision is the maximum <precision> of a NUMERIC or DECIMAL (6.1
// Syntax Rule 25). It's also the precision of a NUMERIC or DECIMAL that doesn't
// specify one (6.1 Syntax Rule 20), see Type.numeric_precision.
const max_numeric_precision = 1000

// max_float_precision is the maximum <precision> of a FLOAT (6.1 Syntax Rule
// 29). A FLOAT is always a DOUBLE PRECISION, which has a binary precision of 53.
const max_float_precision = 53

// check_data_type returns an error if a declared type is larger than the
// maximum allowed. It's checked when a statement declares the type (such as
// CREATE TABLE or CAST) rather than by the parser, so that a table definition
// read from the file is never rejected.
fn check_data_type(t Type) ! {
	match t.typ {
		.is_character, .is_varchar {
			if t.size > max_character_length {
				return sqlstate_42601('${t.typ} length must not be greater than ${max_character_length}')
			}
		}
		.is_numeric, .is_decimal {
			if t.size > max_numeric_precision {
				return sqlstate_42601('${t.typ} precision must not be greater than ${max_numeric_precision}')
			}
		}
		.is_double_precision {
			if t.size > max_float_precision {
				return sqlstate_42601('FLOAT precision must not be greater than ${max_float_precision}')
			}
		}
		else {}
	}
}

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

// ISO/IEC 9075-2:2016(E), 6.1, <data type>, Syntax Rules, 38: <time precision>
// and <timestamp precision> share an implementation-defined maximum, which must
// be at least 6. vsql's maximum is 6.
fn check_fractional_seconds_precision(name string, prec string) ! {
	if prec.int() > 6 {
		return sqlstate_42601('${name}(${prec}): cannot have precision greater than 6')
	}
}
