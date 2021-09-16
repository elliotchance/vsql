// btree.v implements the btree that stores all data on disk (or memory) as
// pages. The B-tree will allocate more pages as needed, but will also shrink
// as data is deleted.

module vsql

struct Btree {
mut:
	pager Pager
}

fn new_btree(pager Pager) &Btree {
	return &Btree{
		pager: pager
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
fn (p Btree) search_page(key []byte) ?([]int, []int) {
	// Special condition if there are no pages.
	if p.pager.total_pages() == 0 {
		return []int{}, []int{}
	}

	mut path := []int{}
	mut depth_iterator := []int{}
	mut current_page := p.pager.root_page()
	for {
		path << current_page
		page := p.pager.fetch_page(current_page) ?

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
				current_page = bytes_to_int(objects[depth_iterator[depth_iterator.len - 1]].value)
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
			current_page = bytes_to_int(objects[0].value)
		}
	}

	return path, depth_iterator
}

fn (mut p Btree) add(obj PageObject) ? {
	// First page is a special condition.
	if p.pager.total_pages() == 0 {
		mut page := new_page(0, p.pager.page_size())
		page.add(obj)
		p.pager.append_page(page) ?
		return
	}

	// Find the page that is suitable for our insertion.
	mut path, _ := p.search_page(obj.key) ?
	left_page_number := path[path.len - 1]

	// If we add to the page and the key is less than the page has we also
	// need to update the parent(s). In the case of a split the minimum key will
	// still appear in the left (same page).
	mut page := p.pager.fetch_page(left_page_number) ?
	previous_page_head := page.head().key.clone()
	previous_root_page := p.pager.root_page()

	// Does it fit into the desired page?
	if page.used + obj.length() < p.pager.page_size() {
		page.add(obj)
		p.pager.store_page(left_page_number, page) ?
	} else {
		p.split_page(path, &page, obj, kind_leaf) ?
	}

	// Make sure we correct the minimum bound up the tree, if needed.
	if compare_bytes(obj.key, previous_page_head) < 0 {
		for path_index in 0 .. path.len - 1 {
			mut t := p.pager.fetch_page(path[path_index]) ?
			t.delete(previous_page_head)
			new_object := new_page_object(obj.key.clone(), int_to_bytes(path[path_index + 1]))
			t.add(new_object)
			p.pager.store_page(path[path_index], t) ?
		}

		if previous_root_page != p.pager.root_page() {
			mut new_root_page := new_page(kind_not_leaf, p.pager.page_size())
			mut previous_objs := (p.pager.fetch_page(p.pager.root_page()) ?).objects()
			previous_objs[0] = new_page_object(obj.key.clone(), int_to_bytes(previous_root_page))
			new_root_page.add(previous_objs[0])
			new_root_page.add(previous_objs[1])
			p.pager.store_page(p.pager.root_page(), new_root_page) ?
		}
	}
}

fn (mut p Btree) split_page(path []int, page &Page, obj PageObject, kind byte) ? {
	// TODO(elliotchance): We do this by dividing the number of entities, this
	//  isn't the best since it can result in pages that aren't evenly split.
	objects := page.objects()
	left := objects[..objects.len / 2]

	mut page1 := new_page(kind, p.pager.page_size())
	for o in left {
		page1.add(o)
	}

	mut page2 := new_page(kind, p.pager.page_size())
	for o in objects[left.len..] {
		page2.add(o)
	}

	// To maintain the sort order we need to make sure we place the new object
	// into the correct page. That is, if the new objects key is less then the
	// first item in the second page it must go into the first page.
	//
	// TODO(elliotchance): What if it doesn't fit in the page still? See
	//  https://github.com/elliotchance/vsql/issues/43.
	if compare_bytes(obj.key, left[left.len - 1].key) < 0 {
		page1.add(obj)
	} else {
		page2.add(obj)
	}

	left_page_number := path[path.len - 1]
	p.pager.store_page(left_page_number, page1) ?

	right_page_number := p.pager.total_pages()
	p.pager.append_page(page2) ?

	// Important: The object is inserted in sorted order, so we cannot rely on
	// the existing split values. We need to read the head object from each
	// (potentially new) page.
	head1 := page1.head()
	head2 := page2.head()

	p1 := new_page_object(head1.key.clone(), int_to_bytes(left_page_number))
	p2 := new_page_object(head2.key.clone(), int_to_bytes(right_page_number))

	// Try to register the new page with the parent of the left page.
	if path.len > 1 {
		mut page3 := p.pager.fetch_page(path[path.len - 2]) ?

		// 30 is the length of p1 + p2.
		if page3.used >= p.pager.page_size() - 30 {
			mut new_path := path[..path.len - 1]
			p.split_page(new_path, &page3, p2, kind_not_leaf) ?
		} else {
			page3.add(p2)
			p.pager.store_page(path[path.len - 2], page3) ?
		}
	} else {
		// Otherwise, we're going to need to create a new root.
		mut page3 := new_page(kind_not_leaf, p.pager.page_size())
		p.pager.append_page(page3) ?
		p.pager.set_root_page(p.pager.total_pages() - 1) ?

		page3.add(p1)
		page3.add(p2)

		p.pager.store_page(p.pager.root_page(), page3) ?
	}
}

fn (p Btree) new_range_iterator(min []byte, max []byte) PageIterator {
	return PageIterator{
		btree: p
		min: min
		max: max
	}
}

fn (mut p Btree) remove(key []byte) ? {
	// Find the page that will contain the key, if it exists.
	mut path, _ := p.search_page(key) ?
	page_number := path[path.len - 1]
	mut empty_pages := []int{}

	mut page := p.pager.fetch_page(page_number) ?
	page.delete(key)
	p.pager.store_page(page_number, page) ?

	if page.is_empty() {
		// If the root page becomes empty we need to truncate the file.
		if page_number == p.pager.root_page() {
			p.pager.truncate_all() ?
			return
		}

		empty_pages << page_number
	}

	// Update the lower boundary of all the ancestors.
	if path.len > 1 {
		for path_index := path.len - 2; path_index >= 0; path_index-- {
			mut t := p.pager.fetch_page(path[path_index]) ?
			did_delete := t.delete(key)

			if !(p.pager.fetch_page(path[path_index + 1]) ?).is_empty() && did_delete {
				lower_bound := (p.pager.fetch_page(path[path_index + 1]) ?).head().key
				obj := new_page_object(lower_bound.clone(), int_to_bytes(path[path_index + 1]))
				t.add(obj)
			}

			p.pager.store_page(path[path_index], t) ?

			if (p.pager.fetch_page(path[path_index]) ?).is_empty() {
				// If the root page becomes empty we need to truncate the file.
				if path[path_index] == p.pager.root_page() {
					p.pager.truncate_all() ?
					return
				}

				empty_pages << path[path_index]
			}
		}
	}

	// I'm not sure why, but we must backfill pages starting with the last page
	// first. Without sorting descending the b-tree stress will always crash
	// with a handful or more size=100 trees.
	empty_pages.sort(a > b)

	// If there were any pages that are now empty we swap out the gap with the
	// last page. This allows the file to shrink as records are deleted.
	//
	// TOOD(elliotchance): We might want to consider setting a threshold for
	//  pages that become close to empty so that they can be merged with another
	//  page. This will help the file shrink if there are a lot of scattered
	//  deletes.
	for empty_page in empty_pages {
		last_page_key := (p.pager.fetch_page(p.pager.total_pages() - 1) ?).head().key
		mut path_to_last_page, _ := p.search_page(last_page_key) ?

		// The last page will be referred to somewhere in the path. We need to
		// replace that elemenet and its immediate child.
		for path_index in 0 .. path_to_last_page.len - 1 {
			if path_to_last_page[path_index + 1] == p.pager.total_pages() - 1 {
				mut ancestor := p.pager.fetch_page(path_to_last_page[path_index]) ?
				ancestor.delete(last_page_key)
				new_object := new_page_object(last_page_key.clone(), int_to_bytes(empty_page))
				ancestor.add(new_object)
				p.pager.store_page(path_to_last_page[path_index], ancestor) ?
			}
		}

		p.pager.store_page(empty_page, p.pager.fetch_page(p.pager.total_pages() - 1) ?) ?

		// Finally, truncate the last page.
		p.pager.truncate_last_page() ?

		// Be careful of moving the root page.
		if p.pager.root_page() == p.pager.total_pages() {
			p.pager.set_root_page(empty_page) ?
		}
	}

	// If the root page becomes empty we need to truncate the file.
	if (p.pager.fetch_page(p.pager.root_page()) ?).is_empty() {
		p.pager.truncate_all() ?
	}
}

fn (mut b Btree) close() {
	b.pager.close()
}

fn (mut b Btree) flush() {
	b.pager.flush()
}
