module main

// ISO/IEC 9075-3:2003(E), 5.9, Character string retrieval
//
// Specify the rules for retrieving character string values.

// retrieve_string copies value into target (which has room for target_length
// octets) as a null terminated string, and sets returned_length to the length
// of value. A truncated value raises a warning.
fn retrieve_string(mut diag Diagnostics, target &char, value string, target_length i64, returned_length voidptr, returned_length_size int) ! {
	// - 2. If TL is not greater than zero, then an exception condition is
	// raised: CLI-specific condition — invalid string length or buffer length.
	if target_length <= 0 {
		return cli_error('HY090', 'invalid string length or buffer length')
	}

	// - 4. If RL is not a null pointer, then the value of the host variable
	// addressed by RL is set to L.
	set_length(returned_length, returned_length_size, value.len)

	// - 5.b. Null termination is always True.
	if !copy_c_string(target, value, target_length) {
		diag.warning('01004', 'string data, right truncation')
	}
}

// copy_c_string copies as much of value as fits into target (including the
// null terminator), returning false if it was truncated.
fn copy_c_string(target &char, value string, target_length i64) bool {
	n := if value.len <= target_length - 1 { value.len } else { int(target_length - 1) }
	unsafe {
		vmemcpy(target, value.str, n)
		target[n] = 0
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
