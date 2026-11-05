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
	// err is set if a page can't be read, which also ends the iteration. V
	// iterators can't return an error, so the caller must check it after the
	// loop.
	err ?IError
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
		iter.objects =
			(iter.btree.pager.fetch_page(iter.path[iter.path.len - 1]) or { return iter.fail(err) }).objects()
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
			iter.depth_iterator[iter.depth_iterator.len - 1]++

			if iter.depth_iterator[iter.depth_iterator.len - 1] < (iter.btree.pager.fetch_page(iter.path[iter.path.len - 1]) or {
				return iter.fail(err)
			}).objects().len {
				break
			}
		}

		for (iter.btree.pager.fetch_page(iter.path[iter.path.len - 1]) or { return iter.fail(err) }).kind == kind_not_leaf {
			objects :=
				(iter.btree.pager.fetch_page(iter.path[iter.path.len - 1]) or { return iter.fail(err) }).objects()

			mut buf := new_bytes(objects[iter.depth_iterator[iter.depth_iterator.len - 1]].value)
			iter.path << buf.read_i32()
			iter.depth_iterator << 0
		}

		iter.objects =
			(iter.btree.pager.fetch_page(iter.path[iter.path.len - 1]) or { return iter.fail(err) }).objects()
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
