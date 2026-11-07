// utils.v is just general helpful functions that don't fall into any specific
// category.

module vsql

pub fn pluralize(n int, word string) string {
	if n == 1 {
		return word
	}

	return '${word}s'
}

// compare_bytes returns a negative number, zero or a positive number when a is
// less than, equal to or greater than b. Only the sign is meaningful.
fn compare_bytes(a []u8, b []u8) int {
	// Only compare digits to the minimum length of both.
	min := if a.len < b.len { a.len } else { b.len }

	if min > 0 {
		cmp := unsafe { int(C.memcmp(a.data, b.data, u32(min))) }
		if cmp != 0 {
			return cmp
		}
	}

	// Equality probably doesn't matter for sorting, but let's check for that
	// too.
	if a.len == b.len {
		return 0
	}

	// If the shared length is the same, we treat the longer string as the
	// greater.
	return a.len - b.len
}

fn left_pad(s string, c string, len int) string {
	mut new_s := s
	for new_s.len < len {
		new_s = c + new_s
	}

	return new_s
}

fn append_list[T](list []T, element T) []T {
	mut new_list := list.clone()
	new_list << element
	return new_list
}

fn concat_lists[T](a []T, b []T) []T {
	mut new_list := a.clone()
	new_list << b
	return new_list
}

fn prepend_list[T](element T, list []T) []T {
	mut new_list := [element]
	new_list << list
	return new_list
}

fn push_list[T](element T, list []T) []T {
	mut new_list := [element]
	for e in list {
		new_list << e
	}

	return new_list
}
