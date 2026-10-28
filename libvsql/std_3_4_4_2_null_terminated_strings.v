module main

// ISO/IEC 9075-3:2003(E), 4.4.2, Null terminated strings
//
// An input string is given with its length in octets, or NULL TERMINATED to
// use the length of the C string.

const sql_nts = -3

// input_string returns the first len octets of s, applying the rules that are
// common to each routine with an input string. A null pointer has a length of
// zero.
fn input_string(s &char, len i64) !string {
	if s == unsafe { nil } {
		return ''
	}

	if len >= 0 {
		return unsafe { tos(&u8(s), int(len)) }.clone()
	}

	if len == sql_nts {
		return unsafe { cstring_to_vstring(s) }
	}

	return cli_error('HY090', 'invalid string length or buffer length')
}
