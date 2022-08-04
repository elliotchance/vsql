// btree_test.v provides exhustive testing for the B-tree on disk implementation
// that cannot be tested at this scale with the existing SQL tests.

module vsql

import os
import rand
import rand.config

// Note: When making changes to the btree (or anything that might affect it).
// Please pick a higher value here for more exhustive testing. Use at least 10
// (ideally 100) before the final diff.
const times = 1

fn test_btree_test() ? {
	// This test runs on different pagers (file vs memory), blob sizes (below)
	// and tree size to generate a test matrix of lots of different scenarios.
	blob_sizes := [
		// 48 means all objects will fit in pages (and several per page) and
		// never have to use blob storage.
		48
		// 148 is larger than half a page so we always end up with one object
		// per page, but no need to use blob storage, yet.
		148
		// 348 is larger than a page so all items must go into blob storage.
		348,
	]

	page_size := 256
	file_name := 'btree.vsql'

	for tt in 0 .. vsql.times {
		for size := 1; size <= 1000; size *= 10 {
			for blob_size in blob_sizes {
				if os.exists(file_name) {
					os.rm(file_name)?
				}

				init_database_file(file_name, page_size)?

				mut db_file := os.open_file('btree.vsql', 'r+')?
				mut file_pager := new_file_pager(mut db_file, page_size, 0)?
				run_btree_test(mut file_pager, size, blob_size, page_size, true, true)?
				db_file.close()

				mut memory_pager := new_memory_pager()
				run_btree_test(mut memory_pager, size, blob_size, page_size, true, true)?
			}
		}
	}
}

fn run_btree_test(mut pager Pager, size int, object_size int, page_size int, randomize bool, run_validate bool) ? {
	transaction_id := 123

	mut objs := []PageObject{len: size}
	for i in 0 .. objs.len {
		objs[i] = new_page_object('R${i:07d}'.bytes(), transaction_id, 0, []u8{len: object_size})
	}

	if randomize {
		rand.shuffle(mut objs, config.ShuffleConfigStruct{})?
	}

	mut btree := new_btree(pager, page_size)
	mut expected_objects := 0
	for obj in objs {
		btree.add(obj)?
		expected_objects++

		if run_validate {
			total_found_objects := validate(mut pager)?
			assert total_found_objects == expected_objects
		}
	}

	mut all := []string{}
	for object in btree.new_range_iterator('R'.bytes(), 'S'.bytes()) {
		all << object.key.bytestr()
	}

	assert all.len == objs.len
	for i in 0 .. all.len {
		assert all[i] == 'R${i:07d}'
	}

	expected_objects = objs.len
	for obj in objs {
		btree.remove(obj.key, transaction_id, true)?
		expected_objects--

		if run_validate {
			total_found_objects := validate(mut pager)?
			assert total_found_objects == expected_objects
		}
	}
}

fn visualize(mut p Pager) ? {
	println('\n=== VISUALIZE (root = $p.root_page()) ===')
	for i := 0; i < p.total_pages(); i++ {
		page := p.fetch_page(i)?

		match page.kind {
			kind_leaf {
				println('$i (leaf, $page.used b used): ${strkeys(page)}')
			}
			kind_not_leaf {
				println('$i (non-leaf, $page.used b used): ${strobjects(page)}')
			}
			else {
				panic(page.kind)
			}
		}
	}

	leaf_objects, non_leaf_objects := count(mut p)?

	println('total: $leaf_objects leaf objects + $non_leaf_objects non-leaf objects\n')
}

// Validate ensures that the tree is valid.
fn validate(mut p Pager) ?int {
	if p.total_pages() == 0 {
		return 0
	}

	_, _, total_objects := validate_page(mut p, p.root_page())?

	// Also make sure none of the pages become orphaned.
	for i := 0; i < p.total_pages(); i++ {
		page := p.fetch_page(i)?

		if page.is_empty() {
			panic('found empty page')
		}
	}

	return total_objects
}

fn validate_page(mut p Pager, page_number int) ?([]u8, []u8, int) {
	page := p.fetch_page(page_number)?
	objects := page.objects()
	mut total_objects := 0

	// For any type of page the keys must be ordered.
	mut min := objects[0].key
	for object in objects[1..] {
		assert compare_bytes(object.key, min) >= 0
		min = object.key
	}

	// For non-leafs we need to verify subpages are valid and consistent with
	// the pointers.
	if page.kind == kind_not_leaf {
		for object in objects {
			mut buf := new_bytes(object.value)
			object_value := buf.read_i32()
			smallest, _, new_objects := validate_page(mut p, object_value)?
			total_objects += new_objects

			// min and max have already been verified in the subpage, but the
			// min has to equal what our pointer says.
			if compare_bytes(smallest, object.key) != 0 {
				panic('$object.key.bytestr() in page $page_number points to $object_value, but child page has head $smallest.bytestr()')
			}
		}
	} else {
		for obj in objects {
			// Ignore blob and fragment objects.
			if obj.key[0] == `B` || obj.key[0] == `F` {
				continue
			}

			total_objects++
		}
	}

	return objects[0].key.clone(), objects[objects.len - 1].key.clone(), total_objects
}

fn count(mut p Pager) ?(int, int) {
	mut total_leaf_objects := 0
	mut total_non_leaf_objects := 0
	for i := 0; i < p.total_pages(); i++ {
		page := p.fetch_page(i)?

		match page.kind {
			kind_leaf {
				total_leaf_objects += page.keys().len
			}
			kind_not_leaf {
				total_non_leaf_objects += page.keys().len
			}
			else {
				panic(page.kind)
			}
		}
	}

	return total_leaf_objects, total_non_leaf_objects
}

fn strkeys(p Page) []string {
	mut keys := []string{}
	for object in p.objects() {
		if object.tid == 0 && object.xid == 0 {
			keys << object.key.bytestr()
		} else {
			keys << object.tid.str() + '/' + object.xid.str() + '-' + object.key.bytestr()
		}
	}

	return keys
}

fn strobjects(p Page) []string {
	mut keys := []string{}
	for object in p.objects() {
		mut buf := new_bytes(object.value)
		keys << '$object.key.bytestr():$buf.read_i32()'
	}

	return keys
}

// The expire test doesn't need to be as thorough as the add/remove test because
// no keys are being removed. In fact, the usage of the pages isn't changing at
// all.
//
// We can start a decent sized tree then create two versions of every object
// (effectively an UPDATE on all rows) and make sure the objects and their tid
// integrity is maintained.
fn test_btree_expire_test() ? {
	tid1 := 123 // the first transaction to create the initial data
	tid2 := 456 // the second transaction that will expire half the data
	tid3 := 789 // the third transaction that will update (other) half the data

	page_size := 256
	file_name := 'btree.vsql'
	size := 1000

	if os.exists(file_name) {
		os.rm(file_name)?
	}

	init_database_file(file_name, page_size)?

	mut db_file := os.open_file('btree.vsql', 'r+')?
	mut file_pager := new_file_pager(mut db_file, page_size, 0)?
	mut btree := new_btree(file_pager, page_size)

	// 1. Insert a bunch of keys. We don't need to scrutinize this part becauase
	// it's well covered in the add/remove test.
	mut objs := []PageObject{len: size}
	for i in 0 .. objs.len {
		objs[i] = new_page_object('R${i:07d}'.bytes(), tid1, 0, []u8{len: 48})
	}
	rand.shuffle(mut objs, config.ShuffleConfigStruct{})?

	for obj in objs {
		btree.add(obj)?
	}

	// 2. Half the objects are going to be expired. Randomly chosen and in
	// random order.
	for obj in objs[..objs.len / 2] {
		btree.expire(obj.key, tid1, tid2)?
	}

	// The number of objects remains the same. We'll be checking their actual
	// status later.
	mut total_leaf_objects, _ := count(mut file_pager)?
	assert total_leaf_objects == size
	validate(mut file_pager)?

	// 3. Add updated versions of all the other half (applied in random order).
	for mut obj in objs[objs.len / 2..] {
		btree.expire(obj.key, tid1, tid3)?

		obj.tid = tid3
		btree.add(obj)?
	}

	// The number of objects is raised by 50%.
	total_leaf_objects, _ = count(mut file_pager)?
	assert total_leaf_objects == size + (size / 2)
	validate(mut file_pager)?

	// Finally, validate all the tid state.
	mut created_by_tid1 := 0
	mut deleted_by_tid2 := 0
	mut created_by_tid3 := 0
	for object in btree.new_range_iterator('R'.bytes(), 'S'.bytes()) {
		if object.tid == tid1 {
			created_by_tid1++
		}
		if object.xid == tid2 {
			deleted_by_tid2++
		}
		if object.tid == tid3 {
			created_by_tid3++
		}
	}

	assert created_by_tid1 == size
	assert deleted_by_tid2 == size / 2
	assert created_by_tid3 == size / 2

	db_file.close()
}

fn test_big_btree_test() ? {
	page_size := 1024
	file_name := 'btree.vsql'

	if os.exists(file_name) {
		os.rm(file_name)?
	}

	init_database_file(file_name, page_size)?

	mut db_file := os.open_file('btree.vsql', 'r+')?
	mut file_pager := new_file_pager(mut db_file, page_size, 0)?
	run_btree_test(mut file_pager, 100000, 48, page_size, false, false)?

	mut total_found_objects := validate(mut file_pager)?
	assert total_found_objects == 0

	db_file.close()

	mut memory_pager := new_memory_pager()
	run_btree_test(mut memory_pager, 100000, 48, page_size, false, false)?

	total_found_objects = validate(mut memory_pager)?
	assert total_found_objects == 0
}
