module vsql

// ISO/IEC 9075-2:2016(E), 6.1, <data type>
//
// Specify a data type.

fn parse_timestamp_prec_tz_type(prec string, tz bool) !Type {
	if tz {
		return new_type('TIMESTAMP WITH TIME ZONE', prec.int(), 0)
	}

	return new_type('TIMESTAMP WITHOUT TIME ZONE', prec.int(), 0)
}

fn parse_time_prec_tz_type(prec string, tz bool) !Type {
	if tz {
		return new_type('TIME WITH TIME ZONE', prec.int(), 0)
	}

	return new_type('TIME WITHOUT TIME ZONE', prec.int(), 0)
}
