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
	mut new_s := own_string(s)
	for new_s.len < len {
		new_s = c + new_s
	}

	return new_s
}

// The copies in the list functions (append_list, concat_lists, prepend_list and
// push_list) work around
// https://github.com/vlang/v/issues/32943 (-autofree): the caller frees what's
// pushed. The local in concat_lists works around
// https://github.com/vlang/v/issues/32946.
fn append_list[T](list []T, element T) []T {
	mut new_list := list.clone()
	$if autofree {
		new_list << own_copy(&element)
		return new_list
	}
	new_list << element
	return new_list
}

fn concat_lists[T](a []T, b []T) []T {
	mut new_list := a.clone()
	others := own_array(b)
	new_list << others
	return new_list
}

fn prepend_list[T](element T, list []T) []T {
	mut new_list := [own_copy(&element)]
	others := own_array(list)
	new_list << others
	return new_list
}

fn push_list[T](element T, list []T) []T {
	mut new_list := [own_copy(&element)]
	for i in 0 .. list.len {
		new_list << own_elem(list, i)
	}

	return new_list
}

// free_when_grown lets a (with -autofree) free its old memory each time it
// grows, which works around https://github.com/vlang/v/issues/32977: without a
// GC, an array that grows leaks each buffer that it outgrows. It's only for an
// array that's never sliced while it grows, since a slice would then point to
// freed memory.
@[inline]
fn free_when_grown[T](mut a []T) {
	$if autofree {
		unsafe {
			a.flags |= .noslices
		}
	}
}
