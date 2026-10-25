// btree.v implements the btree that stores all data on disk (or memory) as
// pages. The B-tree will allocate more pages as needed, but will also shrink
// as data is deleted.
//
// All objects (tables, rows, etc) exist in a single tree. Keys are not unique
// on their own but they become unique when combined with the tid (the
// transaction ID that created them.)
//
// Some important caveats to note:
//
// 1. When objects are larger than a single page, they will be moved to blob
// storage. In a nutshell this means the data is split into sequential
// page-sized objects using the 'B' prefixed and an optional 'F' (fragment)
// object. Then the original object is converted into a reference. See
// new_reference_object().
//
// 2. The combination of the key (which could be the PRIMARY KEY) and tid make
// up the true key in the file, it is expected that only 1 or 2 versions of the
// key may exist. Trying to add a third version of a key will result in an
// error. This is because under MVCC the in-flight version would block new
// versions from being created.

module vsql

struct Btree {
	page_size int
mut:
	pager Pager
	// written_pages contains every page number that has been stored or appended.
	// A split can move objects to a new page, so Storage uses this (rather
	// than the page numbers returned) to find all the pages a transaction
	// changed.
	written_pages map[int]bool
}

fn new_btree(pager Pager, page_size int) &Btree {
	return &Btree{
		pager:     pager
		page_size: page_size
	}
}

fn (mut p Btree) store_page(page_number int, page Page) ! {
	p.pager.store_page(page_number, page)!
	p.written_pages[page_number] = true
}

fn (mut p Btree) append_page(page Page) !int {
	page_number := p.pager.append_page(page)!
	p.written_pages[page_number] = true

	return page_number
}

// search_page returns the traversal path to the page that either contains the
// key, or would contain the key if it needed to be stored.
//
// If the key is out of bounds (before the first page or after the last page)
// then the first or last page is returned respectively.
//
// The first parameter returned is the path (with each page that needs to be
// visited and the last element being the only leaf page). The second parameter
// is the depth iterator at each non-leaf page (so it will have a len of the
// path - 1).
//
// The B-tree must have at least one page. It's only searched for an object that
// exists (to change or remove it), and add() and PageIterator check for an
// empty B-tree themselves.
fn (mut p Btree) search_page(key []u8) !([]int, []int) {
	mut path := []int{}
	mut depth_iterator := []int{}
	mut current_page := p.pager.root_page()
	for {
		path << current_page
		page := p.pager.fetch_page(current_page)!

		// Leaf node is the end of the line. The key may or may not exist, but
		// this is the page that would contain it. In the case of adding the
		// key, this page would be split.
		if page.kind == kind_leaf {
			break
		}

		// Continue to traverse through the next page. Since we need to find the
		// greatest key that is less than the searching key it's easiest to do
		// this backwards.
		objects := page.objects()
		depth_iterator << objects.len - 1
		mut found := false
		for depth_iterator[depth_iterator.len - 1] >= 0 {
			if compare_bytes(key, objects[depth_iterator[depth_iterator.len - 1]].key) >= 0 {
				mut buf := new_bytes(objects[depth_iterator[depth_iterator.len - 1]].value)
				current_page = buf.read_i32()
				found = true
				break
			}
			depth_iterator[depth_iterator.len - 1]--
		}

		// Not found means that the key must exist before the first page. We
		// return the first page but always choosing the 0th page until we hit a
		// leaf.
		if !found {
			depth_iterator[depth_iterator.len - 1] = 0
			mut buf := new_bytes(objects[0].value)
			current_page = buf.read_i32()
		}
	}

	return path, depth_iterator
}

// update replaces the version of the object with the same key that was created
// by obj.tid (the current transaction), or expires the visible version, and adds
// obj as the new version. The key never changes, because a row that gets a new
// PRIMARY KEY is deleted and added again (see UpdateStatementSearched).
fn (mut p Btree) update(obj PageObject) !int {
	// Find the page that would contain our old object (if it exists).
	mut path, _ := p.search_page(obj.key)!
	page_number := path[path.len - 1]
	mut page := p.pager.fetch_page(page_number)!

	// If there is a version created by this transaction, it's replaced (see
	// Page.update). Its blob must be removed before the new version is added,
	// because the blob objects of both versions would have the same keys and
	// tid.
	own_version := page.get(obj.key, obj.tid)
	page.update(obj, obj.tid)!
	p.store_page(page_number, page)!
	if own_version.is_blob_ref {
		p.remove_blob(own_version)!
	}

	p.add(obj)!

	path, _ = p.search_page(obj.key)!
	p.fix_parent_pages(path)!

	return page_number
}

// get returns the object with the key that was created by tid.
fn (mut p Btree) get(key []u8, tid u64) !PageObject {
	path, _ := p.search_page(key)!
	page := p.pager.fetch_page(path[path.len - 1])!
	obj := page.get(key, tid)
	if obj.key.len == 0 {
		return sqlstate_xx001('object does not exist: ${key.bytestr()}')
	}

	return obj
}

// read_blob puts back together the object that was moved to blob storage
// because it's larger than half a page (see add). ref is the blob reference,
// so the returned object has its tid and xid.
fn (mut p Btree) read_blob(ref PageObject) !PageObject {
	blob_peices, has_fragment := ref.blob_info()
	mut data := []u8{}
	for part in 0 .. blob_peices {
		data << (p.get(blob_object_key(ref.key, part), ref.tid)!).value
	}

	if has_fragment {
		data << (p.get(fragment_object_key(ref.key), ref.tid)!).value
	}

	_, obj := parse_page_object(data)

	return PageObject{obj.key, obj.value, false, ref.tid, ref.xid}
}

// remove_blob removes the blob and fragment objects of a blob reference. The
// reference itself must be removed separately.
//
// Like COMMIT and ROLLBACK, the objects are removed from their pages without
// removing pages that become empty.
fn (mut p Btree) remove_blob(ref PageObject) ! {
	blob_peices, has_fragment := ref.blob_info()
	mut keys := [][]u8{}
	for part in 0 .. blob_peices {
		keys << blob_object_key(ref.key, part)
	}

	if has_fragment {
		keys << fragment_object_key(ref.key)
	}

	for key in keys {
		path, _ := p.search_page(key)!
		page_number := path[path.len - 1]
		mut page := p.pager.fetch_page(page_number)!
		if page.delete(key, ref.tid) {
			p.store_page(page_number, page)!
		}
	}
}

// add returns the page number that the object was added to.
fn (mut p Btree) add(object PageObject) !int {
	mut obj := object

	// If the object is larger than half a page it needs to be moved to blob
	// storage first. Half, rather than a whole page, because two versions of the
	// same key (see the caveats at the top of the file) must fit on one page,
	// and that includes the blob objects.
	maximum_size := p.max_allowed_in_page() / 2
	obj_bytes := obj.bytes()
	if obj_bytes.len > maximum_size {
		// One important consideration is that the actual bytes of the page
		// object contains the key and the value. Since we're going to be
		// splitting it up into smaller peices each with their own key we cannot
		// simply divide the obj.bytes() into a fixed size.
		//
		// Formula derived from PageObject.length() and using 5 bytes for the
		// blob value size.
		mut blob_size := maximum_size - page_object_prefix_length -
			blob_object_key(obj.key, 0).len - 5

		// The key is in every part, so it must leave room for the value. This is
		// only possible with a small page and a long name, see
		// max_identifier_length.
		if blob_size < 1 {
			return sqlstate_54000('the key of an object (${obj.key.len} bytes) is too long for a page of ${p.page_size} bytes')
		}
		mut part_number := 0
		mut remaining := obj_bytes.len
		for remaining >= blob_size {
			blob_object := new_blob_object(obj.key, obj.tid, obj.xid, part_number, obj_bytes[obj_bytes.len - remaining..obj_bytes.len - remaining + blob_size])
			part_number++
			remaining -= blob_size
			p.add(blob_object)!
		}

		// With the remaining amount (if any) create a blob fragement page.
		has_fragment := remaining > 0
		if has_fragment {
			fragment_object := new_fragment_object(obj.key, obj.tid, obj.xid,
				obj_bytes[obj_bytes.len - remaining..])
			p.add(fragment_object)!
		}

		// Rather than fall through, we need to call add() again with the proper
		// object.
		obj = new_reference_object(obj.key, obj.tid, obj.xid, part_number, has_fragment)

		return p.add(obj)
	}

	// First page is a special condition.
	if p.pager.total_pages() == 0 {
		mut page := new_page(kind_leaf, p.page_size)
		page.add(obj)!

		// Just because there was no pages previously, doesn't mean that the
		// object will get put into the 0th page. We need to be careful to set
		// the root page to whatever the destination is now.
		page_number := p.append_page(page)!
		p.pager.set_root_page(page_number)!

		return page_number
	}

	// Find the page that is suitable for our insertion.
	mut path, _ := p.search_page(obj.key)!
	left_page_number := path[path.len - 1]

	// If we add to the page and the key is less than the page has we also
	// need to update the parent(s). In the case of a split the minimum key will
	// still appear in the left (same page).
	mut page := p.pager.fetch_page(left_page_number)!

	// Does it fit into the desired page?
	if page.used + obj.length() < p.page_size {
		page.add(obj)!
		p.store_page(left_page_number, page)!
	} else {
		p.split_page(path, page, obj, kind_leaf)!
	}

	// The key may not be inserted into the existing page (if there was a
	// split). So be careful to refetch the actual page.
	//
	// TODO(elliotchance): This can be improved to avoid the extra search().
	path, _ = p.search_page(obj.key)!
	p.fix_parent_pages(path)!

	return left_page_number
}

fn (mut p Btree) fix_parent_pages(path []int) ! {
	// Make sure we correct the minimum bound up the tree, if needed.
	if path.len < 2 {
		return
	}

	mut leaf_page := p.pager.fetch_page(path[path.len - 1])!
	min_key := leaf_page.head().key
	for path_index in 0 .. path.len - 1 {
		mut t := p.pager.fetch_page(path[path_index])!

		t_head := t.head()
		if compare_bytes(min_key, t_head.key) < 0 {
			new_object := new_page_object(min_key.clone(), 0, 0, t_head.value.clone())
			if p.replace_pointer(path[..path_index + 1], mut t, t_head.key, new_object)! {
				// The page was split, so the rest of the path has changed.
				new_path, _ := p.search_page(min_key)!
				return p.fix_parent_pages(new_path)
			}
		}
	}
}

// replace_pointer replaces the pointer with old_key (if any) in the non-leaf
// page at the end of path. The new key may be longer than the old one, so the
// page is split if it no longer fits. It returns true if the page was split.
fn (mut p Btree) replace_pointer(path []int, mut page Page, old_key []u8, pointer PageObject) !bool {
	if old_key.len > 0 {
		page.delete(old_key, 0)
	}

	if page.used + pointer.length() > p.page_size {
		p.split_page(path, page, pointer, kind_not_leaf)!
		return true
	}

	page.add(pointer)!
	p.store_page(path[path.len - 1], page)!

	return false
}

// max_allowed_in_page returns the maximum bytes a page can hold of data. That
// is, not including the space required for the page metadata.
fn (p Btree) max_allowed_in_page() int {
	return p.page_size - page_header_size
}

fn (mut p Btree) split_page(path []int, page Page, obj PageObject, kind u8) ! {
	// A simple (but unsuccessful) way to split a page is to put half of the
	// objects into each page. This doesn't work because the new object might be
	// larger than the remaining space on the left or right page. Instead we
	// need to insert sort the object and divide the pages by size, see
	// split_objects.
	mut objects := page.objects()
	mut inserted_at := -1
	for pos, object in objects {
		if compare_bytes(obj.key, object.key) <= 0 {
			mut new_objects := objects[..pos].clone()
			new_objects << obj
			new_objects << objects[pos..]
			objects = new_objects.clone()
			inserted_at = pos
			break
		}
	}

	if inserted_at == -1 {
		objects << obj
	}

	groups := p.split_objects(objects)

	// The first group stays in the page being split, and the others go into
	// new pages.
	left_page_number := path[path.len - 1]
	mut page_numbers := []int{}
	for i, group in groups {
		mut split := new_page(kind, p.page_size)
		for object in group {
			split.add(object)!
		}

		if i == 0 {
			p.store_page(left_page_number, split)!
			page_numbers << left_page_number
		} else {
			page_numbers << p.append_page(split)!
		}
	}

	// Important: The object is inserted in sorted order, so we cannot rely on
	// the existing split values. We need to read the head object from each
	// (potentially new) page.
	//
	// The tids are zero here because non-leaf pages do not have transaction
	// visibility for their nodes.
	mut pointers := []PageObject{}
	for i, group in groups {
		mut buf := new_empty_bytes()
		buf.write_i32(page_numbers[i])
		pointers << new_page_object(group[0].key.clone(), 0, 0, buf.bytes())
	}

	// If this was the root, we're going to need to create a new root.
	if path.len == 1 {
		mut root := new_page(kind_not_leaf, p.page_size)
		for pointer in pointers {
			root.add(pointer)!
		}

		new_root_page := p.append_page(root)!
		p.pager.set_root_page(new_root_page)!

		return
	}

	// Update the page head, if the object was inserted at the start of the
	// left page. It doesn't matter if it was inserted at the start of another
	// page because those are always added to the parent non-leaf page.
	//
	// TODO(elliotchance): I'm not certain that this will work if the head
	//  object changes to something very large. This code should panic on
	//  add(). We need a test suite for very long keys.
	//
	// The parent's key for the left page may be older than the head of the
	// page, because removing objects from a page (see isolation_end) does not
	// update the parent. So we find it by the page number instead.
	mut parent_split := false
	if inserted_at == 0 {
		mut parent := p.pager.fetch_page(path[path.len - 2])!
		mut old_key := []u8{}
		for parent_object in parent.objects() {
			mut buf := new_bytes(parent_object.value)
			if buf.read_i32() == left_page_number {
				old_key = parent_object.key.clone()
				break
			}
		}
		parent_split = p.replace_pointer(path[..path.len - 1], mut parent, old_key,
			pointers[0])!
	}

	// Register each new page with the parent of the page before it. Adding a
	// page (or replacing the pointer above) can split the parent, so the path
	// to the page before it has to be found again.
	mut previous_path := path.clone()
	for i in 1 .. pointers.len {
		if i > 1 || parent_split {
			search_path, _ := p.search_page(pointers[i - 1].key)!
			index := search_path.index(page_numbers[i - 1])
			if index < 1 {
				return sqlstate_xx001('cannot find page ${page_numbers[i - 1]} after split')
			}
			previous_path = search_path[..index + 1].clone()
		}

		p.add_page_pointer(previous_path, pointers[i])!
	}
}

// split_objects divides the objects (which are in order) into as few pages as
// possible, with a heavy bias towards filling the earlier pages.
//
// We prefer the left page to be a full as possible because the keys are
// sequential, so in the case of lots of sequential inserts it can pack the
// data more tightly. However, if the inserts are not sequential we will get a
// lot of semi-full pages that hopefully become full over time.
//
// Usually this is two pages, but it can be three. Two versions of the same key
// must be on the same page, so when they don't fit with the objects before
// them they start a new page, and the objects after them may need another.
fn (p Btree) split_objects(objects []PageObject) [][]PageObject {
	max_allowed_in_page := p.max_allowed_in_page()
	mut groups := [][]PageObject{}
	mut group := []PageObject{}
	mut consumed := 0
	for object in objects {
		object_size := object.length()
		if group.len > 0 && consumed + object_size > max_allowed_in_page {
			// Two versions of the same key (see the caveats at the top of the
			// file) must stay on the same page. Otherwise, once the expired
			// version is removed, the parent's key for the next page is a key
			// that is still in the previous page and searching for it finds the
			// wrong page.
			last := group.last()
			if group.len > 1 && compare_bytes(last.key, object.key) == 0
				&& last.length() + object_size <= max_allowed_in_page {
				groups << group[..group.len - 1]
				group = [last]
				consumed = last.length()
			} else {
				groups << group
				group = []PageObject{}
				consumed = 0
			}
		}

		group << object
		consumed += object_size
	}
	groups << group

	// It's possible that when we split a page that all of the objects fit into
	// one page. This isn't a bug, it happens when we're splitting non-leaf
	// pages to make room for the new page pointer object. There must always be
	// at least two pages, so the last object goes into its own page.
	if groups.len == 1 && objects.len > 1 {
		groups = [objects[..objects.len - 1], [objects.last()]]
	}

	return groups
}

// add_page_pointer adds the pointer to a new page to the parent of the last
// page in path (the page before the new one), splitting the parent if needed.
// The page before must not be the root.
fn (mut p Btree) add_page_pointer(path []int, pointer PageObject) ! {
	// The non-leaf pages only contain page pointers, so the objects are
	// usually quite small. However, they are not a fixed size because the
	// keys can be variable length.
	mut parent := p.pager.fetch_page(path[path.len - 2])!
	if parent.used > p.page_size - pointer.length() {
		p.split_page(path[..path.len - 1].clone(), parent, pointer, kind_not_leaf)!
	} else {
		parent.add(pointer)!
		p.store_page(path[path.len - 2], parent)!
	}
}

fn (p Btree) new_range_iterator(min []u8, max []u8) PageIterator {
	return PageIterator{
		btree: p
		min:   min
		max:   max
	}
}

// expire will set the deleted transaction ID for the key, effectively making
// the object invisible to the current transaction. The page modified will be
// returned, or -1 if the object does not exist.
fn (mut p Btree) expire(key []u8, tid u64, xid u64) !int {
	// Find the page that will contain the key, if it exists.
	mut path, _ := p.search_page(key)!
	page_number := path[path.len - 1]

	mut page := p.pager.fetch_page(page_number)!

	if page.expire(key, tid, xid)! {
		p.store_page(page_number, page)!
		return page_number
	}

	return -1
}

// replace_value changes the value of an existing object, without changing its
// tid or xid. The new value must be the same size, so that it fits in the page.
fn (mut p Btree) replace_value(obj PageObject, value []u8) ! {
	path, _ := p.search_page(obj.key)!
	page_number := path[path.len - 1]
	mut page := p.pager.fetch_page(page_number)!
	if !page.delete(obj.key, obj.tid) {
		return sqlstate_xx001('object does not exist: ${obj.key.bytestr()}')
	}

	page.add(PageObject{obj.key, value, false, obj.tid, obj.xid})!
	p.store_page(page_number, page)!
}
