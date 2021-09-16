// page.v contains the operations for manipulating a single page, such as adding
// and removing objects.

module vsql

const (
	kind_leaf     = 0 // page contains Objects.
	kind_not_leaf = 1 // page contains links to other pages.
)

struct PageObject {
	key   []byte
	value []byte
}

fn new_page_object(key []byte, value []byte) PageObject {
	return PageObject{key, value}
}

fn (o PageObject) length() int {
	return 6 + o.key.len + o.value.len
}

fn (o PageObject) serialize() []byte {
	mut buf := new_bytes([]byte{})
	buf.write_int(o.length())
	buf.write_i16(i16(o.key.len))
	buf.write_bytes(o.key)
	buf.write_bytes(o.value)

	return buf.bytes()
}

fn parse_page_object(data []byte) (int, PageObject) {
	mut buf := new_bytes(data)
	total_len := buf.read_int()
	key_len := buf.read_i16()

	return total_len, new_page_object(data[6..key_len + 6].clone(), data[6 + key_len..total_len].clone())
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

fn (mut p Page) add(obj PageObject) {
	// Make sure the object is added in sorted order. This is not the most
	// efficient way to do this. It will have to do for now.
	mut objects := p.objects()
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
fn (mut p Page) delete(key []byte) bool {
	mut offset := 0
	mut did_delete := false
	for object in p.objects() {
		if compare_bytes(key, object.key) == 0 {
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

// replace will perform a delete and add operation. If the key does not exist it
// will be created.
fn (mut p Page) replace(key []byte, value []byte) {
	p.delete(key)
	obj := new_page_object(key.clone(), value)
	p.add(obj)
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
