// walk.v contains the iterator that is able to walk through ranges of the
// B-tree.

module vsql

struct PageIterator {
	// min and max are inclusive.
	min []u8
	max []u8
mut:
	btree Btree
	// objects is just for performance so we dont need to parse the objects in
	// the page several times while we iterate that page.
	objects []PageObject
	// path describes the depth. At each depth is an iterator for that page.
	path           []int
	depth_iterator []int
	// parents are the objects of the pages of path before the leaf, kept so that
	// moving to the next leaf doesn't read them again. They are read when they
	// are first needed (see parent), so there may be fewer than path.
	parents [][]PageObject
	// err is set if a page can't be read, which also ends the iteration. V
	// iterators can't return an error, so the caller must check it after the
	// loop.
	err ?IError
}

// parent returns the objects of the page at depth in path, which isn't a leaf,
// reading it (and any parents before it that haven't been read) if needed.
fn (mut iter PageIterator) parent(depth int) ![]PageObject {
	for iter.parents.len <= depth {
		mut objects := []PageObject{}
		(iter.btree.pager.read_page(iter.path[iter.parents.len])!).objects_in_place(mut objects)
		iter.parents << objects
	}

	return iter.parents[depth]
}

// fail ends the iteration because of err, see PageIterator.err.
fn (mut iter PageIterator) fail(err IError) ?PageObject {
	iter.err = err
	return none
}

fn (mut iter PageIterator) next() ?PageObject {
	// Special case for no data.
	if iter.btree.pager.total_pages() == 0 {
		return none
	}

	// On the first iteration we fast-forward to the starting page.
	if iter.path.len == 0 {
		iter.path, iter.depth_iterator = iter.btree.search_page(iter.min) or { return iter.fail(err) }

		// search_page does not include the last depth_iterator becuase that
		// belongs to the leaf not which is does not search.
		iter.depth_iterator << 0

		// Load all the objects for this leaf. Making sure to skip over any keys
		// that are out of bounds.
		(iter.btree.pager.read_page(iter.path[iter.path.len - 1]) or { return iter.fail(err) }).objects_in_place(mut iter.objects)
		for object in iter.objects {
			if compare_bytes(object.key, iter.min) < 0 {
				iter.depth_iterator[iter.depth_iterator.len - 1]++
			}
		}
	}

	// If this page is done, roll up to the parent and continue to traverse
	// down. This repeats because leaf pages may be empty after objects are
	// removed by COMMIT, ROLLBACK or isolation_end, since those don't remove
	// empty pages from the B-tree.
	for iter.depth_iterator[iter.depth_iterator.len - 1] >= iter.objects.len {
		for {
			if iter.path.len == 1 {
				return none
			}

			iter.path = iter.path[..iter.path.len - 1]
			iter.depth_iterator = iter.depth_iterator[..iter.depth_iterator.len - 1]
			if iter.parents.len > iter.path.len {
				iter.parents = iter.parents[..iter.path.len]
			}
			iter.depth_iterator[iter.depth_iterator.len - 1]++

			if iter.depth_iterator[iter.depth_iterator.len - 1] < (iter.parent(iter.path.len - 1) or {
				return iter.fail(err)
			}).len {
				break
			}
		}

		// Go down to the next leaf. A page that's one of the parents is known to
		// not be a leaf, so it doesn't need to be read again.
		for {
			depth := iter.path.len - 1
			if depth >= iter.parents.len {
				page := iter.btree.pager.read_page(iter.path[depth]) or { return iter.fail(err) }
				if page.kind != kind_not_leaf {
					// The page is only used by the iterator, so its objects don't
					// need to be copied.
					page.objects_in_place(mut iter.objects)
					break
				}
				mut objects := []PageObject{}
				page.objects_in_place(mut objects)
				iter.parents << objects
			}

			mut buf := new_bytes(iter.parents[depth][iter.depth_iterator[depth]].value)
			iter.path << buf.read_i32()
			iter.depth_iterator << 0
		}
	}

	o := iter.objects[iter.depth_iterator[iter.depth_iterator.len - 1]]
	iter.depth_iterator[iter.depth_iterator.len - 1]++

	// We also need to bail out if we encounter a value greater the upper bound.
	if compare_bytes(o.key, iter.max) > 0 {
		return none
	}

	if o.is_blob_ref {
		return iter.btree.read_blob(o) or { return iter.fail(err) }
	}

	return o
}
