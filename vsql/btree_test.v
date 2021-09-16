// btree_test.v provides exhustive testing for the B-tree on disk implementation
// that cannot be tested at this scale with the existing SQL tests.

module vsql

import os
import rand.util

fn test_btree_test() ? {
	// Note: When making changes to the btree (or anything that might affect
	// it). Please pick a higher value here for more exhustive testing. Use at
	// least 10 (ideally 100) before the final diff.
	times := 1

	for tt in 0 .. times {
		for size := 1; size <= 1000; size *= 10 {
			mut db_file := os.create('btree.vsql') ?
			db_file.write([]byte{len: 256}) ?
			db_file.close()
			mut file_pager := new_file_pager('btree.vsql', 256) ?

			run_btree_test(file_pager, size) ?

			memory_pager := new_memory_pager(256)
			run_btree_test(memory_pager, size) ?
		}
	}
}

fn run_btree_test(pager Pager, size int) ? {
	mut objs := []PageObject{len: size}
	for i in 0 .. objs.len {
		objs[i] = PageObject{'R${i:04d}'.bytes(), []byte{len: 48}}
	}

	util.shuffle(mut objs, 0)

	mut btree := new_btree(pager)
	mut expected_objects := 0
	for obj in objs {
		btree.add(obj) ?
		expected_objects++

		total_leaf_objects, _ := count(pager) ?
		assert total_leaf_objects == expected_objects
		validate(pager) ?
	}

	mut all := []string{}
	for object in btree.new_range_iterator('R'.bytes(), 'S'.bytes()) {
		all << string(object.key)
	}

	assert all.len == objs.len
	for i in 0 .. all.len {
		assert all[i] == 'R${i:04d}'
	}

	expected_objects = objs.len
	for obj in objs {
		btree.remove(obj.key) ?
		expected_objects--

		total_leaf_objects, _ := count(pager) ?
		assert total_leaf_objects == expected_objects
		validate(pager) ?
	}
}

fn visualize(p Pager) ? {
	println('\n=== VISUALIZE (root = $p.root_page()) ===')
	for i := 0; i < p.total_pages(); i++ {
		page := p.fetch_page(i) ?

		if page.kind == kind_leaf {
			println('$i (leaf, $page.used b used): ${strkeys(page)}')
		} else {
			println('$i (non-leaf, $page.used b used): ${strobjects(page)}')
		}
	}

	leaf_objects, non_leaf_objects := count(p) ?

	println('total: $leaf_objects leaf + $non_leaf_objects non-leaf \n')
}

// Validate ensures that the tree is valid.
fn validate(p Pager) ? {
	if p.total_pages() == 0 {
		return
	}

	validate_page(p, p.root_page()) ?

	// Also make sure none of the pages become orphaned.
	for i := 0; i < p.total_pages(); i++ {
		page := p.fetch_page(i) ?

		if page.is_empty() {
			panic('found empty page')
		}
	}
}

fn validate_page(p Pager, page_number int) ?([]byte, []byte) {
	page := p.fetch_page(page_number) ?
	objects := page.objects()

	// For any type of page the keys must be ordered.
	mut min := objects[0].key
	for object in objects[1..] {
		assert compare_bytes(object.key, min) > 0
		min = object.key
	}

	// For non-leafs we need to verify subpages are valid and consistent with
	// the pointers.
	if page.kind == kind_not_leaf {
		for object in objects {
			smallest, _ := validate_page(p, bytes_to_int(object.value)) ?

			// min and max have already been verified in the subpage, but the
			// min has to equal what our pointer says.
			if compare_bytes(smallest, object.key) != 0 {
				panic('${string(object.key)} in page $page_number points to ${bytes_to_int(object.value)}, but child page has head ${string(smallest)}')
				assert false
			}
		}
	}

	return objects[0].key.clone(), objects[objects.len - 1].key.clone()
}

fn count(p Pager) ?(int, int) {
	mut total_leaf_objects := 0
	mut total_non_leaf_objects := 0
	for i := 0; i < p.total_pages(); i++ {
		page := p.fetch_page(i) ?

		if page.kind == kind_leaf {
			total_leaf_objects += page.keys().len
		} else {
			total_non_leaf_objects += page.keys().len
		}
	}

	return total_leaf_objects, total_non_leaf_objects
}

fn strkeys(p Page) []string {
	mut keys := []string{}
	for object in p.objects() {
		keys << string(object.key)
	}

	return keys
}

fn strobjects(p Page) []string {
	mut keys := []string{}
	for object in p.objects() {
		keys << '${string(object.key)}:${bytes_to_int(object.value)}'
	}

	return keys
}
