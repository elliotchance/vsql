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
}

fn new_btree(pager Pager, page_size int) &Btree {
	return &Btree{
		pager:     pager
		page_size: page_size
	}
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
fn (mut p Btree) search_page(key []u8) !([]int, []int) {
	// Special condition if there are no pages.
	if p.pager.total_pages() == 0 {
		return []int{}, []int{}
	}

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

// The old and new must be provided separately because the key may change if the
// PRIMARY KEY value has changed.
fn (mut p Btree) update(old PageObject, new PageObject, tid int) ![]int {
	if p.pager.total_pages() == 0 {
		// The object does not exist to update.
		return []int{}
	}

	// If the pages are the same and we're updating an in-flight row we need to
	// actually delete the existing row.
	if compare_bytes(old.key, new.key) == 0 {
		page_number := p.update_single(new, tid)!

		return [page_number]
	}

	// Otherwise we have to deal with two pages, but we're dealing with them
	// differently because the operations and not symmetrical.
	old_page_number := p.expire(old.key, old.tid, tid)!
	new_page_number := p.add(new)!

	mut page_numbers := [new_page_number]
	if old_page_number >= 0 && old_page_number != new_page_number {
		page_numbers << old_page_number
	}

	return page_numbers
}

fn (mut p Btree) update_single(obj PageObject, tid int) !int {
	if p.pager.total_pages() == 0 {
		// The object does not exist to update.
		return 0
	}

	// Find the page that would contain our old object (if it exists).
	mut path, _ := p.search_page(obj.key)!
	page_number := path[path.len - 1]
	mut page := p.pager.fetch_page(page_number)!

	page.update(obj, obj, obj.tid)!
	p.pager.store_page(page_number, page)!

	p.add(obj)!

	p.fix_parent_pages(path)!

	return page_number
}

// add returns the page number that the object was added to.
fn (mut p Btree) add(object PageObject) !int {
	mut obj := object

	// If the object does not fit into a single page it needs to be moved to
	// blob storage first.
	maximum_size := p.max_allowed_in_page()
	obj_bytes := obj.bytes()
	if obj_bytes.len > maximum_size {
		// One important consideration is that the actual bytes of the page
		// object contains the key and the value. Since we're going to be
		// splitting it up into smaller peices each with their own key we cannot
		// simply divide the obj.bytes() into a fixed size.
		//
		// Formula derived from PageObject.length() and using 5 bytes for the
		// blob value size.
		mut blob_size := maximum_size - page_object_prefix_length - blob_object_key(obj.key,
			0).len - 5
		mut part_number := 0
		mut remaining := obj_bytes.len
		for remaining >= blob_size {
			blob_object := new_blob_object(obj.key, obj.tid, obj.xid, part_number, obj_bytes[obj_bytes.len - remaining..
				obj_bytes.len - remaining + blob_size])
			part_number++
			remaining -= blob_size
			p.add(blob_object)!
		}

		// With the remaining amount (if any) create a blob fragement page.
		has_fragment := remaining > 0
		if has_fragment {
			fragment_object := new_fragment_object(obj.key, obj.tid, obj.xid, obj_bytes[obj_bytes.len - remaining..])
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
		page_number := p.pager.append_page(page)!
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
		p.pager.store_page(left_page_number, page)!
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
			t.delete(t_head.key, 0)

			new_object := new_page_object(min_key.clone(), 0, 0, t_head.value.clone())
			t.add(new_object)!
		}

		p.pager.store_page(path[path_index], t)!
	}
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
	// need to insert sort the object and divide the pages by size with a heavy
	// bias towards loading the left page.
	//
	// We prefer the left page to be a full as possible because the keys are
	// sequential, so in the case of lots of sequential inserts it can pack the
	// data more tightly. However, if the inserts are not sequential we will get
	// a lot of semi-full pages that hopefully become full over time.
	mut objects := page.objects()
	original_head := objects[0].key.clone()
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

	mut consumed := 0
	mut objects_in_left_page := 0
	mut max_allowed_in_page := p.max_allowed_in_page()

	// Load the left page.
	mut page1 := new_page(kind, p.page_size)
	for object in objects {
		object_size := object.length()
		if consumed + object_size > max_allowed_in_page {
			break
		}

		consumed += object_size
		objects_in_left_page++
		page1.add(object)!

		// It's possible that when we split a page that all of the objects fit
		// into the left page. This would be bad as the right page would be left
		// empty (pun, see what I did there) and the code below would fail. This
		// isn't a bug, it happens when we're splitting non-leaf pages to make
		// room for the new page pointer object. So at the time of the split the
		// page contains many objects but they are not larger than a single
		// page.
		if objects_in_left_page == objects.len - 1 {
			break
		}
	}

	// Whatever is remaining goes into the right page.
	mut page2 := new_page(kind, p.page_size)
	mut stored_in_right := 0
	for i in objects_in_left_page .. objects.len {
		page2.add(objects[i])!
		stored_in_right++
	}

	left_page_number := path[path.len - 1]
	p.pager.store_page(left_page_number, page1)!

	right_page_number := p.pager.append_page(page2)!

	// Important: The object is inserted in sorted order, so we cannot rely on
	// the existing split values. We need to read the head object from each
	// (potentially new) page.
	head1 := page1.head()
	head2 := page2.head()

	// The tids are zero here because non-leaf pages do not have transaction
	// visibility for their nodes.
	mut buf1 := new_empty_bytes()
	buf1.write_i32(left_page_number)
	p1 := new_page_object(head1.key.clone(), 0, 0, buf1.bytes())

	mut buf2 := new_empty_bytes()
	buf2.write_i32(right_page_number)
	p2 := new_page_object(head2.key.clone(), 0, 0, buf2.bytes())

	// Try to register the new page with the parent of the left page.
	if path.len > 1 {
		mut page3 := p.pager.fetch_page(path[path.len - 2])!

		// Update the page head, if the object was inserted at the start of the
		// left page. It doesn't matter if it was inserted at the start of the
		// right page because that's always added to the parent non-leaf page.
		//
		// TODO(elliotchance): I'm not certain that this will work if the head
		//  object changes to something very large. This code should panic on
		//  add(). We need a test suite for very long keys.
		if inserted_at == 0 {
			page3.delete(original_head, 0)
			page3.add(p1)!
		}

		// The non-leaf pages only contain page pointers, so the objects are
		// usually quite small. However, they are not a fixed size because the
		// keys can be variable length.
		if page3.used > p.page_size - p2.length() {
			mut new_path := path[..path.len - 1].clone()
			p.split_page(new_path, page3, p2, kind_not_leaf)!
		} else {
			page3.add(p2)!

			p.pager.store_page(path[path.len - 2], page3)!
		}
	} else {
		// Otherwise, we're going to need to create a new root.
		mut page3 := new_page(kind_not_leaf, p.page_size)
		page3.add(p1)!
		page3.add(p2)!

		new_root_page := p.pager.append_page(page3)!
		p.pager.set_root_page(new_root_page)!
	}
}

fn (p Btree) new_range_iterator(min []u8, max []u8) PageIterator {
	return PageIterator{
		btree: p
		min:   min
		max:   max
	}
}

fn (mut p Btree) remove(key []u8, tid int, handle_blob bool) ! {
	// Find the page that will contain the key, if it exists.
	mut path, _ := p.search_page(key)!
	page_number := path[path.len - 1]
	mut empty_pages := []int{}

	mut page := p.pager.fetch_page(page_number)!
	object_to_delete := page.get(key, tid)
	if handle_blob && object_to_delete.is_blob_ref {
		// Remove the associated blob.
		blob_peices, has_fragment := object_to_delete.blob_info()

		for part in 0 .. blob_peices {
			p.remove(blob_object_key(key, part), tid, false)!
		}

		if has_fragment {
			p.remove(fragment_object_key(key), tid, false)!
		}

		// There's an important edge case where the original key might be in one
		// of the pages we just modified OR the pages have been moved around so
		// that the page we deleted from is no longer valid.
		//
		// We handle this by calling remove again. Probably not the most ideal,
		// but it will do for now.
		return p.remove(key, tid, false)
	}

	// The object does not use blob storage, or it has already been cleared out.
	page.delete(key, tid)
	p.pager.store_page(page_number, page)!

	if page.is_empty() {
		// If the root page becomes empty we need to truncate the file.
		if page_number == p.pager.root_page() {
			p.pager.truncate_all()!
			return
		}

		empty_pages << page_number
	}

	// Update the lower boundary of all the ancestors.
	if path.len > 1 {
		for path_index := path.len - 2; path_index >= 0; path_index-- {
			mut t := p.pager.fetch_page(path[path_index])!
			did_delete := t.delete(key, 0)

			lower_page := p.pager.fetch_page(path[path_index + 1])!
			if !lower_page.is_empty() && did_delete {
				lower_bound := lower_page.head().key

				// The tids are zero here because non-leaf pages do not have
				// transaction visibility for their nodes.
				mut buf := new_empty_bytes()
				buf.write_i32(path[path_index + 1])
				obj := new_page_object(lower_bound.clone(), 0, 0, buf.bytes())

				t.add(obj)!
			}

			p.pager.store_page(path[path_index], t)!

			if t.is_empty() {
				// If the root page becomes empty we need to truncate the file.
				if path[path_index] == p.pager.root_page() {
					p.pager.truncate_all()!
					return
				}

				empty_pages << path[path_index]
			}
		}
	}

	p.fill_empty_pages(mut empty_pages)!
}

fn (mut p Btree) fill_empty_pages(mut empty_pages []int) ! {
	// I'm not sure why, but we must backfill pages starting with the last page
	// first. Without sorting descending the B-tree stress test will always
	// crash with a handful or more size=100 trees.
	empty_pages.sort(a > b)

	// If there were any pages that are now empty we swap out the gap with the
	// last page. This allows the file to shrink as records are deleted.
	//
	// TOOD(elliotchance): We might want to consider setting a threshold for
	//  pages that become close to empty so that they can be merged with another
	//  page. This will help the file shrink if there are a lot of scattered
	//  deletes.
	for empty_page in empty_pages {
		last_page := p.pager.fetch_page(p.pager.total_pages() - 1)!
		last_page_key := last_page.head().key
		mut path_to_last_page, _ := p.search_page(last_page_key)!

		// The last page will be referred to somewhere in the path. We need
		// to replace that element and its immediate child.
		for path_index in 0 .. path_to_last_page.len - 1 {
			if path_to_last_page[path_index + 1] == p.pager.total_pages() - 1 {
				mut ancestor := p.pager.fetch_page(path_to_last_page[path_index])!

				// All tids are zero here because non-leaf pages do not have
				// transaction visibility for their nodes.
				ancestor.delete(last_page_key, 0)

				mut buf := new_empty_bytes()
				buf.write_i32(empty_page)
				new_object := new_page_object(last_page_key.clone(), 0, 0, buf.bytes())

				ancestor.add(new_object)!
				p.pager.store_page(path_to_last_page[path_index], ancestor)!
			}
		}

		p.pager.store_page(empty_page, last_page)!

		// Be careful of moving the root page.
		if p.pager.root_page() == p.pager.total_pages() - 1 {
			p.pager.set_root_page(empty_page)!
		}

		// Finally, truncate the last page.
		p.pager.truncate_last_page()!
	}

	// If the root page becomes empty we need to truncate the file.
	if (p.pager.fetch_page(p.pager.root_page())!).is_empty() {
		p.pager.truncate_all()!
	}
}

// expire will set the deleted transaction ID for the key, effectively making
// the object invisible to the current transaction. The page modified will be
// returned, or -1 if the object does not exist.
fn (mut p Btree) expire(key []u8, tid int, xid int) !int {
	// Find the page that will contain the key, if it exists.
	mut path, _ := p.search_page(key)!
	page_number := path[path.len - 1]

	mut page := p.pager.fetch_page(page_number)!

	if page.expire(key, tid, xid) {
		p.pager.store_page(page_number, page)!
		return page_number
	}

	return -1
}
