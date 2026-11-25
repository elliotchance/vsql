module main

// ISO/IEC 9075-3:2003, 5.10, Binary large object string retrieval
//
// Specify the rules for retrieving BINARY LARGE OBJECT string values.
//
// The same rules retrieve a BINARY or BINARY VARYING value (SQL_BINARY or
// SQL_VARBINARY), which isn't in SQL/CLI 2003.

// retrieve_octets copies value into target (which has room for target_length
// octets), and sets returned_length to the length of value. It's never null
// terminated. A truncated value raises a warning.
fn retrieve_octets(mut diag Diagnostics, target &char, value string, target_length i64, returned_length voidptr) ! {
	// ISO/IEC 9075-3:2003, 5.10, Binary large object string retrieval, General Rules, 2
	if target_length <= 0 {
		return cli_error('HY090', 'invalid string length or buffer length')
	}

	// ISO/IEC 9075-3:2003, 5.10, Binary large object string retrieval, General Rules, 3 and 4
	set_length(returned_length, 4, value.len)

	// ISO/IEC 9075-3:2003, 5.10, Binary large object string retrieval, General Rules, 5
	if !copy_c_string(target, value, target_length, false) {
		diag.warning('01004', 'string data, right truncation')
	}
}
