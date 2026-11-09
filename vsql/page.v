// page.v contains the operations for manipulating a single page, such as adding
// and removing objects.

module vsql

import encoding.binary

// It would be nice to put this an an enum, but actually keeping it as a u8 (and
// not the required int is kind of fiddly). Also, there's almost no case where
// we need to deal with all cases because they are context specific. So let's
// just keep these as u8 for now.
const kind_leaf = 0 // page contains only objects.

const kind_not_leaf = 1 // page contains only links to other pages.

// page_object_prefix_length is the precalculated length that will be the
// combination of all fixed width meta for the page object.
const page_object_prefix_length = 23

// page_object_tid_at and page_object_xid_at are where the tid and xid are in an
// object, see PageObject.bytes.
const page_object_tid_at = 4

const page_object_xid_at = 12

pub struct PageObject {
	// The key is not required to be unique in the page. It becomes unique when
	// combined with tid. However, no more than two version of the same key can
	// exist in a page. See the caveats at the top of btree.v.
	key []u8
	// The value contains the serialized data for the object. The first byte of
	// key is used to both identify what type of object this is and also keep
	// objects within the same collection also within the same range.
	value []u8
	// When is_blob_ref is true, the value will be always be 5 bytes. See
	// blob_info().
	is_blob_ref bool
mut:
	// The tid is the transaction that created the object.
	tid u64
	// The xid is the transaciton that deleted the object, or zero if it has
	// never been deleted.
	xid u64
}

fn new_page_object(key []u8, tid u64, xid u64, value []u8) PageObject {
	return PageObject{key, value, false, tid, xid}
}

fn blob_object_key(key []u8, part int) []u8 {
	mut buf := new_empty_bytes()
	buf.write_u8(`B`)
	buf.write_u8s(key)
	buf.write_u8(`0`)
	buf.write_i32(part)

	return buf.bytes()
}

fn new_blob_object(key []u8, tid u64, xid u64, part int, value []u8) PageObject {
	return PageObject{blob_object_key(key, part), value, false, tid, xid}
}

fn fragment_object_key(key []u8) []u8 {
	mut buf := new_empty_bytes()
	buf.write_u8(`F`)
	buf.write_u8s(key)

	return buf.bytes()
}

fn new_fragment_object(key []u8, tid u64, xid u64, value []u8) PageObject {
	return PageObject{fragment_object_key(key), value, false, tid, xid}
}

fn new_reference_object(key []u8, tid u64, xid u64, blob_peices int, has_fragment bool) PageObject {
	mut buf := new_empty_bytes()
	buf.write_i32(blob_peices)
	buf.write_bool(has_fragment)

	return PageObject{key, buf.bytes(), true, tid, xid}
}

fn (o PageObject) length() int {
	return page_object_prefix_length + o.key.len + o.value.len
}

// blob_info only applies to blob objects.
fn (o PageObject) blob_info() (int, bool) {
	mut buf := new_bytes(o.value)
	blob_peices := buf.read_i32()
	has_fragment := buf.read_bool()

	return blob_peices, has_fragment
}

fn (o PageObject) bytes() []u8 {
	mut buf := new_empty_bytes()
	buf.write_i32(o.length())
	buf.write_u64(o.tid)
	buf.write_u64(o.xid)
	buf.write_i16(i16(o.key.len))
	buf.write_u8s(o.key)
	buf.write_bool(o.is_blob_ref)
	buf.write_u8s(o.value)

	return buf.bytes()
}

fn parse_page_object(data []u8) (int, PageObject) {
	// The key and value are copied by read_u8s, so data doesn't need to be.
	mut buf := Bytes{
		data: data
	}
	total_len := buf.read_i32()
	tid := buf.read_u64()
	xid := buf.read_u64()
	key_len := buf.read_i16()
	key := buf.read_u8s(key_len)
	is_blob_ref := buf.read_bool()
	value := buf.read_u8s(total_len - page_object_prefix_length - key_len)

	return total_len, PageObject{key, value, is_blob_ref, tid, xid}
}

// page_header_size is the number of reserved bytes at the start of the page
// that are not writable (because it contains metadata). See "Page" in the file
// format docs for the layout.
const page_header_size = 16

// max_page_size is the largest page possible, because Used in the page header
// is a u16.
const max_page_size = 65535

// check_page_size returns an error if a page can't be page_size bytes.
fn check_page_size(page_size int) ! {
	if page_size <= page_header_size || page_size > max_page_size {
		return sqlstate_54000('page size ${page_size} must be more than ${page_header_size} and at most ${max_page_size} bytes')
	}
}

struct Page {
	kind u8 // 0 = leaf, 1 = non-leaf, see constants at the top of the file.
mut:
	used u16  // number of bytes used by this page including the header.
	data []u8 // len = page size - page_header_size
}

fn new_page(kind u8, page_size int) &Page {
	return &Page{
		kind: kind
		used: page_header_size // includes kind and self
		data: []u8{len: page_size - page_header_size}
	}
}

fn (p Page) page_size() int {
	return p.data.len + page_header_size
}

fn (mut p Page) update(old PageObject, tid u64) ! {
	old_versions := p.versions(old.key)
	match old_versions.len {
		1 {
			// A record created by this transaction is replaced. Otherwise, there
			// would be two versions with the same tid, and removing the expired
			// one (see page.delete) would remove both.
			if old_versions[0] == tid {
				p.delete(old.key, tid)
			} else {
				// Expire the existing record.
				p.expire(old.key, old_versions[0], tid)!
			}
		}
		2 {
			// Attempt to delete the version for the current in-flight
			// transaction only. If this works, the add() should also work. This
			// handles the case of allowing a record to be updated by the same
			// transaction that still holds it.
			//
			// However, if the version is held not by our transaction the delete
			// will do nothing and the subsequent add() will fail appropriately
			// with SQLSTATE 40001 serialization failure.
			p.delete(old.key, tid)
		}
		else {
			// This would be 0. Nothing to do here. Falldown to the add() below.
		}
	}
}

// object_len returns the length of the object at offset.
fn (p Page) object_len(offset int) int {
	return int(binary.big_endian_u32_at(p.data, offset))
}

// object_tid returns the tid of the object at offset.
fn (p Page) object_tid(offset int) u64 {
	return binary.big_endian_u64_at(p.data, offset + page_object_tid_at)
}

// object_key returns the key of the object at offset, without copying it. It
// must not be kept after the page is changed.
fn (p Page) object_key(offset int) []u8 {
	return p.data[offset + page_object_prefix_length - 1..page_object_value_at(p.data, offset) - 1]
}

// versions returns all versions of a record. The result will have 0, 1 or 2
// elements.
fn (p Page) versions(key []u8) []u64 {
	mut versions := []u64{}
	end := int(p.used) - page_header_size
	mut offset := 0
	for offset < end {
		if compare_bytes(p.object_key(offset), key) == 0 {
			versions << p.object_tid(offset)
		}
		offset += p.object_len(offset)
	}

	return versions
}

// add will append the object (in order of key) or return an error if either the
// object cannot fit or if their already exists two versions of the key - which
// should be interpreted by the client as a try again. See description below.
fn (mut p Page) add(obj PageObject) ! {
	if p.used + obj.length() > p.page_size() {
		panic('page cannot fit object of ${obj.length()} b in page using ${p.used} b')
	}

	// If there are two versions, there must be one version that is
	// frozen (visible to all transactions) and one version that is
	// in-flight for a transaction (and hence only visible to that
	// transaction).
	//
	// We should not let any other transactions create a new version
	// because this would cause a conflict when the COMMIT occurs.
	//
	// We return a SQLSTATE 40001 to let the client know it should retry the
	// entire transaction again.
	mut objects := p.objects()
	if p.versions(obj.key).len >= 2 {
		return sqlstate_40001('avoiding concurrent write on individual row')
	}

	// Make sure the object is added in sorted order. This is not the most
	// efficient way to do this. It will have to do for now.
	objects << obj

	objects.sort_with_compare(fn (a &PageObject, b &PageObject) int {
		return compare_bytes(a.key, b.key)
	})

	mut offset := 0
	for object in objects {
		s := object.bytes()
		for i in 0 .. s.len {
			p.data[offset] = s[i]
			offset++
		}
	}

	p.used += u16(obj.length())
}

// delete will remove a key from a page if it exists, otherwise no action will
// be taken. The removed object will be returned, or an object with an empty key
// if the object did not exist.
fn (mut p Page) delete(key []u8, tid u64) bool {
	mut offset := 0
	mut did_delete := false
	for object in p.objects() {
		if compare_bytes(key, object.key) == 0 && object.tid == tid {
			p.used -= u16(object.length())
			did_delete = true
			continue
		}

		s := object.bytes()
		for i in 0 .. s.len {
			p.data[offset] = s[i]
			offset++
		}
	}

	return did_delete
}

fn (p Page) get(key []u8, tid u64) PageObject {
	end := int(p.used) - page_header_size
	mut offset := 0
	for offset < end {
		if p.object_tid(offset) == tid && compare_bytes(key, p.object_key(offset)) == 0 {
			_, object := parse_page_object(p.data[offset..])

			return object
		}
		offset += p.object_len(offset)
	}

	return PageObject{}
}

// expire will set the expiry transaction ID on an existing object. True is
// returned if the page was modified.
//
// An object that has already been expired by another transaction cannot be
// expired again, because rolling back either transaction resets the xid to 0
// and undoes the other one's delete. Instead, this returns a SQLSTATE 40001 so
// that the client retries the transaction, the same as concurrent writes in
// add(). An xid of 0 always succeeds, which is how a rollback or recovery makes
// the object visible again.
fn (mut p Page) expire(key []u8, tid u64, xid u64) !bool {
	end := int(p.used) - page_header_size
	mut offset := 0
	mut modified := false
	for offset < end {
		if p.object_tid(offset) == tid && compare_bytes(key, p.object_key(offset)) == 0 {
			object_xid := binary.big_endian_u64_at(p.data, offset + page_object_xid_at)
			if xid != 0 && object_xid != 0 && object_xid != xid {
				return sqlstate_40001('avoiding concurrent write on individual row')
			}
			binary.big_endian_put_u64_at(mut p.data, xid, offset + page_object_xid_at)
			modified = true
		}
		offset += p.object_len(offset)
	}

	return modified
}

// objects_in_place sets objects to the objects of the page, reusing its
// memory. Unlike objects, the key and value of each object are part of the page
// rather than copies, so the page must not be changed while they are used. See
// PageObject.bytes for the layout.
fn (p Page) objects_in_place(mut objects []PageObject) {
	objects.clear()
	end := int(p.used) - page_header_size

	// The objects are counted first so that objects only has to grow once,
	// rather than doubling for each new iterator.
	mut count := 0
	mut offset := 0
	for offset < end {
		count++
		offset += int(binary.big_endian_u32_at(p.data, offset))
	}
	if objects.cap < count {
		objects = []PageObject{cap: count}
	}

	offset = 0
	for offset < end {
		total_len := int(binary.big_endian_u32_at(p.data, offset))
		key_len := int(binary.big_endian_u16_at(p.data, offset + 20))
		key_at := offset + page_object_prefix_length - 1
		value_at := key_at + key_len + 1
		objects << PageObject{
			key:         p.data[key_at..value_at - 1]
			value:       p.data[value_at..offset + total_len]
			is_blob_ref: p.data[value_at - 1] != 0
			tid:         binary.big_endian_u64_at(p.data, offset + 4)
			xid:         binary.big_endian_u64_at(p.data, offset + 12)
		}
		offset += total_len
	}
}

fn (p Page) objects() []PageObject {
	mut objects := []PageObject{}
	mut n := 0

	for n < p.used - page_header_size {
		m, object := parse_page_object(p.data[n..])
		objects << object
		n += m
	}

	return objects
}

// page_object_value_at returns where the value starts of the object at offset,
// using the layout in PageObject.bytes.
fn page_object_value_at(data []u8, offset int) int {
	key_at := offset + page_object_prefix_length - 1
	key_len := int(binary.big_endian_u16_at(data, key_at - 2))

	return key_at + key_len + 1
}

// find_pointer returns the index and page number of the last pointer in a
// non-leaf page with a key that's not greater than key. If there isn't one, the
// key must exist before the first page, so it's the first pointer. The objects
// are read in place because this is called for each page of every search.
fn (p Page) find_pointer(key []u8) (int, int) {
	end := int(p.used) - page_header_size
	mut offset := 0
	mut index := 0
	mut pointer_at := page_object_value_at(p.data, 0)
	for i := 0; offset < end; i++ {
		value_at := page_object_value_at(p.data, offset)
		key_at := offset + page_object_prefix_length - 1
		if compare_bytes(key, p.data[key_at..value_at - 1]) < 0 {
			break
		}

		index = i
		pointer_at = value_at
		offset += int(binary.big_endian_u32_at(p.data, offset))
	}

	return index, int(i32(binary.big_endian_u32_at(p.data, pointer_at)))
}

// head returns the first object in the page, but it must only be used for
// read only (so we can avoid the extra memory copies).
fn (p Page) head() PageObject {
	_, object := parse_page_object(p.data)

	return object
}
