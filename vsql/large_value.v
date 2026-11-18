// large_value.v stores long character and binary strings outside of their row,
// so that reading a row (such as for a table scan) doesn't read them.

module vsql

import math

// A character string or binary string that's longer than the threshold (see
// large_value_threshold) is written in a row as a reference, and its octets are
// stored in Large Value Objects (see large_value_key), in chunks. A row that
// isn't changed keeps the same reference, so the value isn't copied.
//
// The reference is written where the 4 byte length of the string would be, as
// large_value_marker (a length can't be negative), then the value ID (u64), the
// length in octets (i32), the length in characters (i32, the same as the
// octets for a binary string) and the size of each chunk (i32). Whether a value
// is inline or a reference is known from each value, so the threshold (and the
// chunk size) can change without changing the file format.
const large_value_marker = i32(-1)

// large_value_threshold is the most octets that a string is written inline in a
// row, which is a quarter of a page.
fn large_value_threshold(page_size int) int {
	return page_size / 4
}

// large_value_chunk_size is the most octets in each Large Value Object, so that
// each one fits in a page (see Btree.add).
fn large_value_chunk_size(page_size int) int {
	return (page_size - page_header_size) / 2 - page_object_prefix_length - large_value_key_length
}

const large_value_key_length = 21

// large_value_key is the key of a chunk of a large value: L, the table ID, the
// value ID and the chunk number.
fn large_value_key(table_id u64, value_id u64, chunk int) []u8 {
	mut key := new_empty_bytes()
	key.write_u8(`L`)
	key.write_u64(table_id)
	key.write_u64(value_id)
	key.write_i32(chunk)

	return key.bytes()
}

// LargeValue is a string value that's stored outside of its row. The octets
// are only read when they're needed (see load), and then they're kept.
@[heap]
struct LargeValue {
	table_id   u64
	value_id   u64
	octets     int
	characters int
	chunk_size int
mut:
	// storage is where the value is read from, which is set once the row is
	// read from the storage (see Storage.resolve_row).
	storage &Storage = unsafe { nil }
	loaded  bool
	data    string
}

// new_large_value is a Value that's a reference to a large value of type typ.
fn new_large_value(typ Type, lv &LargeValue) Value {
	return Value{
		typ:      typ
		is_large: true
		v:        InternalValue{
			large_value: voidptr(lv)
		}
	}
}

// large_value is the reference of a Value that is_large.
fn (v Value) large_value() &LargeValue {
	return unsafe { &LargeValue(v.v.large_value) }
}

// chunks is the number of Large Value Objects of the value.
fn (lv &LargeValue) chunks() int {
	return (lv.octets + lv.chunk_size - 1) / lv.chunk_size
}

// load is the octets of the value, which are read the first time.
fn (mut lv LargeValue) load() !string {
	if !lv.loaded {
		mut buf := []u8{len: lv.octets}
		n := lv.read_at(0, mut buf)!
		lv.data = buf[..n].bytestr()
		lv.loaded = true
	}

	return lv.data
}

// read_at reads the octets from offset into buf, and returns how many were
// read (less than buf.len at the end of the value). Only the chunks that have
// them are read.
fn (mut lv LargeValue) read_at(offset i64, mut buf []u8) !int {
	if offset >= lv.octets || buf.len == 0 {
		return 0
	}
	end := math.min(i64(lv.octets), offset + buf.len)
	if lv.loaded {
		for i in offset .. end {
			buf[i - offset] = lv.data[i]
		}

		return int(end - offset)
	}

	first := int(offset / lv.chunk_size)
	last := int((end - 1) / lv.chunk_size)
	objects := lv.storage.read_large_value(lv.table_id, lv.value_id, first, last)!
	if objects.len != last - first + 1 {
		return sqlstate_0f001()
	}

	mut n := 0
	for object in objects {
		mut key := new_bytes(object.key[17..])
		chunk_start := i64(key.read_i32()) * lv.chunk_size
		from := math.max(offset, chunk_start)
		to := math.min(end, chunk_start + object.value.len)
		for i in from .. to {
			buf[i - offset] = object.value[i - chunk_start]
			n++
		}
	}

	return n
}

// read_large_value is the Large Value Objects of a value, from the chunk first
// to last. The chunks never change, so they're read whether they're visible or
// not: the reference to them is in a row that was visible. If the file isn't
// locked (the value is read after the statement that read the row), it's
// locked to read them.
fn (mut f Storage) read_large_value(table_id u64, value_id u64, first int, last int) ![]PageObject {
	if !isnil(f.catalog) && f.catalog.path != ':memory:' && f.file_locks == 0 {
		f.catalog.open_read_connection()!
		defer {
			f.catalog.release_read_connection()
		}

		return f.raw_objects(large_value_key(table_id, value_id, first), large_value_key(table_id,
			value_id, last))
	}

	return f.raw_objects(large_value_key(table_id, value_id, first), large_value_key(table_id,
		value_id, last))
}

// write_large_value stores the octets of s as a new large value of the table,
// with the next value ID (the same counter as row IDs). The first one raises
// the Read Version and the Write Version, since older versions can't read it.
fn (mut f Storage) write_large_value(table_id u64, s string, characters int) !&LargeValue {
	f.header.row_id++
	if f.header.read_version < data_types_file_format_version {
		f.header.read_version = data_types_file_format_version
	}
	if f.header.write_version < data_types_file_format_version {
		f.header.write_version = data_types_file_format_version
	}

	chunk_size := large_value_chunk_size(f.btree.page_size)
	lv := &LargeValue{
		table_id:   table_id
		value_id:   f.header.row_id
		octets:     s.len
		characters: characters
		chunk_size: chunk_size
		storage:    unsafe { &f }
		loaded:     true
		data:       s
	}
	for chunk in 0 .. lv.chunks() {
		start := chunk * chunk_size
		end := math.min(s.len, start + chunk_size)
		f.btree.add(new_page_object(large_value_key(table_id, lv.value_id, chunk),
			f.transaction_id, 0, s[start..end].bytes()))!
	}

	return lv
}

// expire_large_value expires the chunks of a value, so that they're removed
// with the version of the row that had it (see remove_expired).
fn (mut f Storage) expire_large_value(lv &LargeValue) ! {
	for object in f.raw_objects(large_value_key(lv.table_id, lv.value_id, 0), large_value_key(lv.table_id,
		lv.value_id, max_i32))! {
		if object.xid == 0 {
			f.btree.expire(object.key, object.tid, f.transaction_id)!
		}
	}
}

// store_large_values is the row to write for table t, where every string that
// is longer than the threshold is a reference to a large value. A value that
// was already a large value of the same column of old (the version of the row
// that it replaces, if any) keeps the same reference. Any other large value of
// old isn't used anymore, so it's expired.
fn (mut f Storage) store_large_values(r Row, t Table, old ?Row) !Row {
	threshold := large_value_threshold(f.btree.page_size)
	mut kept := map[u64]bool{}
	mut new_row := Row{
		...r
		data: r.data.clone()
	}
	for col in t.columns {
		if !col.typ.uses_string() {
			continue
		}

		name := col.name.sub_entity_name
		v := r.data.value(name)
		if v.is_null {
			continue
		}

		if v.is_large {
			lv := v.large_value()
			if old_row := old {
				old_value := old_row.data.value(name)
				if old_value.is_large && old_value.large_value().table_id == lv.table_id
					&& old_value.large_value().value_id == lv.value_id {
					kept[lv.value_id] = true
					continue
				}
			}
		}

		s := if v.is_large {
			mut lv := v.large_value()
			lv.load()!
		} else {
			v.string_value()
		}
		// A large value is always longer than the threshold. If the threshold
		// changes, a short one is still read the same way.
		if !v.is_large && s.len <= threshold {
			continue
		}

		characters := if col.typ.typ.is_string() { s.len_utf8() } else { s.len }
		lv := f.write_large_value(t.id, s, characters)!
		new_row.data.set(name, new_large_value(v.typ, lv))
	}

	if old_row := old {
		f.expire_large_values(old_row, kept)!
	}

	return new_row
}

// expire_large_values expires each large value of the row (a version that's
// being deleted or replaced), other than the ones that are kept.
fn (mut f Storage) expire_large_values(r Row, kept map[u64]bool) ! {
	for v in r.data.values {
		if v.is_large && !v.is_null && v.large_value().value_id !in kept {
			f.expire_large_value(v.large_value())!
		}
	}
}

// resolve_row lets the large values of a row that was read from the storage be
// read. A CHARACTER LARGE OBJECT or BINARY LARGE OBJECT is only read when it's
// needed, but any other string is read now, like a value in the row.
fn (mut f Storage) resolve_row(mut r Row) !Row {
	for v in r.data.values {
		if v.is_large && !v.is_null {
			mut lv := v.large_value()
			lv.storage = unsafe { &f }
			if v.typ.typ !in [.is_clob, .is_blob] {
				lv.load()!
			}
		}
	}

	return r
}

// octet_length is the length in octets of a character string or binary string,
// which doesn't read a large value.
fn (v Value) octet_length() int {
	if v.is_large {
		return v.large_value().octets
	}

	return v.string_value().len
}

// char_length is the length in characters of a character string, which
// doesn't read a large value.
fn (v Value) char_length() int {
	if v.is_large {
		return v.large_value().characters
	}

	return v.string_value().len_utf8()
}

// is_large_single_octet is true for a large value where every character is one
// octet (or a binary string), so the characters can be found by their octets
// without reading the rest of the value.
fn (v Value) is_large_single_octet() bool {
	return v.is_large && v.large_value().characters == v.large_value().octets
}

// octets is part of a character string or binary string, from the octet start
// to end (exclusive). Only the chunks of a large value that have them are read.
fn (v Value) octets(start int, end int) !string {
	if v.is_large {
		mut lv := v.large_value()
		mut buf := []u8{len: end - start}
		n := lv.read_at(start, mut buf)!

		return buf[..n].bytestr()
	}

	return v.string_value().substr(start, end)
}

// Lob reads a value of a CHARACTER LARGE OBJECT or BINARY LARGE OBJECT (or any
// other string) without reading all of it, see Row.get_lob. A value that's
// stored outside of its row is read until the row is changed by another
// transaction that commits, or the connection is closed.
pub struct Lob {
	value Value
}

// len is the length of the value in octets.
pub fn (l Lob) len() i64 {
	if l.value.is_null {
		return 0
	}
	if l.value.is_large {
		return l.value.large_value().octets
	}

	return l.value.string_value().len
}

// read_at reads the octets of the value from offset into buf, and returns how
// many were read, which is less than buf.len at the end of the value. Only the
// part of the value that's read is loaded.
pub fn (l Lob) read_at(offset i64, mut buf []u8) !int {
	if l.value.is_null {
		return 0
	}
	if l.value.is_large {
		mut lv := l.value.large_value()
		return lv.read_at(offset, mut buf)
	}

	s := l.value.string_value()
	if offset >= s.len {
		return 0
	}
	n := int(math.min(i64(buf.len), s.len - offset))
	for i in 0 .. n {
		buf[i] = s[int(offset) + i]
	}

	return n
}
