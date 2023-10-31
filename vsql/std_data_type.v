module vsql

// ISO/IEC 9075-2:2016(E), 6.1, <data type>
//
// # Function
//
// Specify a data type.
//
// # Format
//~
//~ <data type> /* Type */ ::=
//~     <predefined type>
//~
//~ <predefined type> /* Type */ ::=
//~     <character string type>
//~   | <numeric type>
//~   | <boolean type>
//~   | <datetime type>
//~
//~ <character string type> /* Type */ ::=
//~     CHARACTER                                                         -> character
//~   | CHARACTER <left paren> <character length> <right paren>           -> character_n
//~   | CHAR                                                              -> character
//~   | CHAR <left paren> <character length> <right paren>                -> character_n
//~   | CHARACTER VARYING <left paren> <character length> <right paren>   -> varchar
//~   | CHAR VARYING <left paren> <character length> <right paren>        -> varchar
//~   | VARCHAR <left paren> <character length> <right paren>             -> varchar
//~
//~ <numeric type> /* Type */ ::=
//~     <exact numeric type>
//~   | <approximate numeric type>
//~
//~ <exact numeric type> /* Type */ ::=
//~     SMALLINT   -> smallint
//~   | INTEGER    -> integer
//~   | INT        -> integer
//~   | BIGINT     -> bigint
//~
//~ <approximate numeric type> /* Type */ ::=
//~     FLOAT                                          -> float
//~   | FLOAT <left paren> <precision> <right paren>   -> float_n
//~   | REAL                                           -> real
//~   | DOUBLE PRECISION                               -> double_precision
//~
//~ <length> /* string */ ::=
//~     <unsigned integer>
//~
//~ <character length> /* string */ ::=
//~     <length>
//~
//~ <char length units> /* string */ ::=
//~     CHARACTERS
//~   | OCTETS
//~
//~ <precision> /* string */ ::=
//~     <unsigned integer>
//~
//~ <boolean type> /* Type */ ::=
//~     BOOLEAN   -> boolean_type
//~
//~ <datetime type> /* Type */ ::=
//~     DATE                                               -> date_type
//~   | TIME                                               -> time_type
//~   | TIME <left paren> <time precision> <right paren>   -> time_prec_type
//~   | TIME <with or without time zone>                   -> time_tz_type
//~   | TIME <left paren> <time precision> <right paren>
//~     <with or without time zone>                        -> time_prec_tz_type
//~   | TIMESTAMP                                          -> timestamp_type
//~   | TIMESTAMP
//~     <left paren> <timestamp precision> <right paren>   -> timestamp_prec_type
//~   | TIMESTAMP <with or without time zone>              -> timestamp_tz_type
//~   | TIMESTAMP
//~     <left paren> <timestamp precision> <right paren>
//~     <with or without time zone>                        -> timestamp_prec_tz_type
//~
//~ <with or without time zone> /* bool */ ::=
//~     WITH TIME ZONE      -> yes
//~   | WITHOUT TIME ZONE   -> no
//~
//~ <time precision> /* string */ ::=
//~     <time fractional seconds precision>
//~
//~ <timestamp precision> /* string */ ::=
//~     <time fractional seconds precision>
//~
//~ <time fractional seconds precision> /* string */ ::=
//~     <unsigned integer>

fn parse_character_n(length string) !Type {
	return new_type('CHARACTER', length.int(), 0)
}

fn parse_character() !Type {
	return new_type('CHARACTER', 1, 0)
}

fn parse_varchar(length string) !Type {
	return new_type('CHARACTER VARYING', length.int(), 0)
}

fn parse_smallint() !Type {
	return new_type('SMALLINT', 0, 0)
}

fn parse_bigint() !Type {
	return new_type('BIGINT', 0, 0)
}

fn parse_integer() !Type {
	return new_type('INTEGER', 0, 0)
}

fn parse_double_precision() !Type {
	return new_type('DOUBLE PRECISION', 0, 0)
}

fn parse_float_n(length string) !Type {
	return new_type('FLOAT', length.int(), 0)
}

fn parse_float() !Type {
	return new_type('FLOAT', 0, 0)
}

fn parse_real() !Type {
	return new_type('REAL', 0, 0)
}

fn parse_timestamp_prec_tz_type(prec string, tz bool) !Type {
	if tz {
		return new_type('TIMESTAMP WITH TIME ZONE', prec.int(), 0)
	}

	return new_type('TIMESTAMP WITHOUT TIME ZONE', prec.int(), 0)
}

fn parse_timestamp_prec_type(prec string) !Type {
	return parse_timestamp_prec_tz_type(prec, false)
}

fn parse_timestamp_tz_type(tz bool) !Type {
	// ISO/IEC 9075-2:2016(E), 6.1, 36) If <timestamp precision> is not
	// specified, then 6 is implicit.
	return parse_timestamp_prec_tz_type('6', tz)
}

fn parse_timestamp_type() !Type {
	return parse_timestamp_prec_tz_type('0', false)
}

fn parse_time_prec_tz_type(prec string, tz bool) !Type {
	if tz {
		return new_type('TIME WITH TIME ZONE', prec.int(), 0)
	}

	return new_type('TIME WITHOUT TIME ZONE', prec.int(), 0)
}

fn parse_time_type() !Type {
	return parse_time_prec_tz_type('0', false)
}

fn parse_time_prec_type(prec string) !Type {
	return parse_time_prec_tz_type(prec, false)
}

fn parse_time_tz_type(tz bool) !Type {
	return parse_time_prec_tz_type('0', tz)
}

fn parse_date_type() !Type {
	return new_type('DATE', 0, 0)
}

fn parse_yes() !bool {
	return true
}

fn parse_no() !bool {
	return false
}

fn parse_boolean_type() !Type {
	return new_type('BOOLEAN', 0, 0)
}
