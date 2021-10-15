// strings.v contains string functions.

module vsql

// POSITION(CHARACTER VARYING IN CHARACTER VARYING) INTEGER
fn func_position(args []Value) ?Value {
	index := args[1].string_value.index(args[0].string_value) or { -1 }

	return new_integer_value(index + 1)
}

// CHAR_LENGTH(CHARACTER VARYING) INTEGER
fn func_char_length(args []Value) ?Value {
	return new_integer_value(args[0].string_value.runes().len)
}

// OCTET_LENGTH(CHARACTER VARYING) INTEGER
fn func_octet_length(args []Value) ?Value {
	return new_integer_value(args[0].string_value.len)
}
