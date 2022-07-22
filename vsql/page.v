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

// TODO(elliotchance): This does not need to be public. It was required for a
//  bug at the time with V not being able to pass this to the shuffle function.
//  At some point in the future remove the pub and see if it works.
pub struct PageObject {
	// The key is not required to be unique in the page. It becomes unique when
	// combined with tid. However, no more than two version of the same key can
	// exist in a page. See the caveats at the top of btree.v.
	key []u8
	// The value contains the serialized data for the object. The first byte of
	// key is used to both identify what type of object this is and also keep
	// objects within the same collection also within the same range.
	value []u8
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

fn new_page_object(key []u8, tid int, xid int, value []u8) PageObject {
	return PageObject{key, value, tid, xid}
}

fn (o PageObject) length() int {
	return vsql.page_object_prefix_length + o.key.len + o.value.len
}

fn (o PageObject) serialize() []u8 {
	mut buf := new_empty_bytes()
	buf.write_i32(o.length())
	buf.write_i32(o.tid)
	buf.write_i32(o.xid)
	buf.write_i16(i16(o.key.len))
	buf.write_u8s(o.key)
	buf.write_u8s(o.value)

	return buf.bytes()
}

fn parse_page_object(data []u8) (int, PageObject) {
	mut buf := new_bytes(data)
	total_len := buf.read_i32()
	tid := buf.read_i32()
	xid := buf.read_i32()
	key_len := buf.read_i16()

	return total_len, new_page_object(data[vsql.page_object_prefix_length..key_len +
		vsql.page_object_prefix_length].clone(), tid, xid, data[vsql.page_object_prefix_length +
		key_len..total_len].clone())
}

struct Page {
	kind u8 // 0 = leaf, 1 = non-leaf, see constants at the top of the file.
mut:
	used u16  // number of bytes used by this page including 3 bytes for header.
	data []u8 // len = page size - 3
}

fn new_page(kind u8, page_size int) &Page {
	return &Page{
		kind: kind
		used: 3 // includes kind and self
		data: []u8{len: page_size - 3}
	}
}

fn (p Page) is_empty() bool {
	return p.used == 3
}

fn (p Page) page_size() int {
	return p.data.len + 3
}

// TODO(elliotchance): This really isn't the most efficient way to do this. Make
//  me faster. Especially since the calls down will recount versions again, etc.
fn (mut p Page) update(old PageObject, new PageObject, tid int) ? {
	mut objects := p.objects()
	old_versions := p.versions(old.key, objects)
	match old_versions.len {
		1 {
			// Expire the existing record.
			p.expire(old.key, old_versions[0], tid)
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

// versions returns all versions of a record. The result will have 0, 1 or 2
// elements. versions accepts the objects to prevent callers from needing to
// call objects again themselves.
fn (p Page) versions(key []u8, objects []PageObject) []int {
	mut versions := []int{}
	for object in objects {
		if compare_bytes(object.key, key) == 0 {
			// TODO(elliotchance): As long as the database has not become
			//  corrupt, we can stop here at 2. However, I'm going to leave the
			//  full scan in place until the underlying storage is more mature.
			versions << object.tid
		}
	}

	return versions
}

// add will append the object (in order of key) or return an error if either the
// object cannot fit or if their already exists two versions of the key - which
// should be interpreted by the client as a try again. See description below.
fn (mut p Page) add(obj PageObject) ? {
	if p.used + obj.length() > p.page_size() {
		panic('page cannot fit object of $obj.length() b in page using $p.used b')
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
	if p.versions(obj.key, objects).len >= 2 {
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
fn (mut p Page) delete(key []u8, tid int) bool {
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
fn (mut p Page) expire(key []u8, tid int, xid int) bool {
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
fn (mut p Page) replace(key []u8, tid int, value []u8) ? {
	p.delete(key, tid)
	obj := new_page_object(key.clone(), tid, 0, value)
	p.add(obj)?
}

fn (p Page) keys() [][]u8 {
	mut keys := [][]u8{}
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
