// page.v contains the operations for manipulating a single page, such as adding
// and removing objects.

module vsql

const (
	kind_leaf     = 0 // page contains only objects.
	kind_not_leaf = 1 // page contains only links to other pages.
)

// page_object_prefix_length is the precalculated length that will be the
// combination of all fixed width meta for the page object.
const page_object_prefix_length = 14

struct PageObject {
	// The key is not required to be unique in the page. It becomes unique when
	// combined with tid. However, no more than two version of the same key can
	// exist in a page. See the caveats at the top of btree.v.
	key []byte
	// The value contains the serialized data for the object. The first byte of
	// key is used to both identify what type of object this is and also keep
	// objects within the same collection also within the same range.
	value []byte
mut:
	// The tid is the transaction that created the object.
	//
	// TODO(elliotchance): It makes more sense to construct a new PageObject
	//  when changing the tid and xid.
	tid int
	// The xid is the transaciton that deleted the object, or zero if it has
	// never been deleted.
	xid int
}

fn new_page_object(key []byte, tid int, xid int, value []byte) PageObject {
	return PageObject{key, value, tid, xid}
}

fn (o PageObject) length() int {
	return vsql.page_object_prefix_length + o.key.len + o.value.len
}

fn (o PageObject) serialize() []byte {
	mut buf := new_bytes([]byte{})
	buf.write_int(o.length())
	buf.write_int(o.tid)
	buf.write_int(o.xid)
	buf.write_i16(i16(o.key.len))
	buf.write_bytes(o.key)
	buf.write_bytes(o.value)

	return buf.bytes()
}

fn parse_page_object(data []byte) (int, PageObject) {
	mut buf := new_bytes(data)
	total_len := buf.read_int()
	tid := buf.read_int()
	xid := buf.read_int()
	key_len := buf.read_i16()

	return total_len, new_page_object(data[vsql.page_object_prefix_length..key_len +
		vsql.page_object_prefix_length].clone(), tid, xid, data[vsql.page_object_prefix_length +
		key_len..total_len].clone())
}

struct Page {
	kind byte // 0 = leaf, 1 = non-leaf, see constants at the top of the file.
mut:
	used u16    // number of bytes used by this page including 3 bytes for header.
	data []byte // len = page size - 3
}

fn new_page(kind byte, page_size int) &Page {
	return &Page{
		kind: kind
		used: 3 // includes kind and self
		data: []byte{len: page_size - 3}
	}
}

fn (p Page) is_empty() bool {
	return p.used == 3
}

fn (p Page) page_size() int {
	return p.data.len + 3
}

// add will append the object (in order of key) or return an error if either the
// object cannot fit or there already exists two versions of the key.
fn (mut p Page) add(obj PageObject) ? {
	if p.used + obj.length() > p.page_size() {
		return error('page cannot fit object')
	}

	// TODO(elliotchance): Checking for existence is just a safety measure for
	//  now and should be wasted CPU. The MVCC logic that creates the extra
	//  version should prevent more than two versions from being created anyway.
	//  Try removing this in the future when transaction are well tested and
	//  stable.
	mut objects := p.objects()
	mut versions := 0
	for object in objects {
		if compare_bytes(object.key, obj.key) == 0 {
			versions++

			// Check for two (since we're about to add a third).
			if versions == 2 {
				return error('more than two versions is not allowed')
			}
		}
	}

	// Make sure the object is added in sorted order. This is not the most
	// efficient way to do this. It will have to do for now.
	objects << obj

	objects.sort_with_compare(fn (a &PageObject, b &PageObject) int {
		return compare_bytes(a.key, b.key)
	})

	mut offset := 0
	for object in objects {
		s := object.serialize()
		for i in 0 .. s.len {
			p.data[offset] = s[i]
			offset++
		}
	}

	p.used += u16(obj.length())
}

// delete will remove a key from a page if it exists, otherwise no action will
// be taken. The index of the deleted object is returned or -1.
fn (mut p Page) delete(key []byte, tid int) bool {
	mut offset := 0
	mut did_delete := false
	for object in p.objects() {
		if compare_bytes(key, object.key) == 0 && object.tid == tid {
			p.used -= u16(object.length())
			did_delete = true
			continue
		}

		s := object.serialize()
		for i in 0 .. s.len {
			p.data[offset] = s[i]
			offset++
		}
	}

	return did_delete
}

// expire will set the expiry transaction ID on an existing object. True is
// returned if the page was modified.
fn (mut p Page) expire(key []byte, tid int, xid int) bool {
	mut offset := 0
	mut modified := false
	for mut object in p.objects() {
		if compare_bytes(key, object.key) == 0 && object.tid == tid {
			object.xid = xid
			modified = true
		}

		s := object.serialize()
		for i in 0 .. s.len {
			p.data[offset] = s[i]
			offset++
		}
	}

	return modified
}

// replace will perform a delete and add operation. If the key does not exist it
// will be created.
fn (mut p Page) replace(key []byte, tid int, value []byte) ? {
	p.delete(key, tid)
	obj := new_page_object(key.clone(), tid, 0, value)
	p.add(obj) ?
}

fn (p Page) keys() [][]byte {
	mut keys := [][]byte{}
	for object in p.objects() {
		keys << object.key
	}

	return keys
}

fn (p Page) objects() []PageObject {
	mut objects := []PageObject{}
	mut n := 0

	for n < p.used - 3 {
		// Be careful to clone the size as the underlying data might get moved
		// around.
		m, object := parse_page_object(p.data[n..].clone())
		objects << object
		n += m
	}

	return objects
}

// head returns the first object in the page, but it must only be used for
// read only (so we can avoid the extra memory copies).
fn (p Page) head() PageObject {
	_, object := parse_page_object(p.data)

	return object
}
