module main

// ISO/IEC 9075-3:2003(E), 5.9, Character string retrieval
//
// Specify the rules for retrieving character string values.

// retrieve_string copies value into target (which has room for target_length
// octets), and sets returned_length to the length of value. It's null
// terminated if nts (the NULL TERMINATION of the SQL-environment) is true. A
// truncated value raises a warning.
fn retrieve_string(mut diag Diagnostics, nts bool, target &char, value string, target_length i64, returned_length voidptr, returned_length_size int) ! {
	// - 2. If TL is not greater than zero, then an exception condition is
	// raised: CLI-specific condition — invalid string length or buffer length.
	//
	// When null termination is False, a zero buffer size is the same as a null
	// pointer (see 4.4.3, "Null pointers"), so nothing is copied.
	if target_length < 0 || (target_length == 0 && nts) {
		return cli_error('HY090', 'invalid string length or buffer length')
	}

	// - 4. If RL is not a null pointer, then the value of the host variable
	// addressed by RL is set to L.
	set_length(returned_length, returned_length_size, value.len)

	// - 5. The value is copied, and truncated with a warning if it doesn't fit.
	if !copy_c_string(target, value, target_length, nts) {
		diag.warning('01004', 'string data, right truncation')
	}
}

// copy_c_string copies as much of value as fits into target (including the
// null terminator when nts is true), returning false if it was truncated.
fn copy_c_string(target &char, value string, target_length i64, nts bool) bool {
	room := if nts { target_length - 1 } else { target_length }
	n := if value.len <= room { value.len } else { int(room) }
	unsafe {
		vmemcpy(target, value.str, n)
		if nts {
			target[n] = 0
		}
	}

	return n == value.len
}

// set_length sets a SMALLINT (size 2) or INTEGER output length, unless it's a
// null pointer.
fn set_length(ptr voidptr, size int, len int) {
	if ptr == unsafe { nil } {
		return
	}

	unsafe {
		if size == 2 {
			*&i16(ptr) = i16(len)
		} else {
			*&SQLInteger(ptr) = SQLInteger(len)
		}
	}
}
