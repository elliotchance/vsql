module vsql

import os
import rand

// Rows that are deleted leave their pages empty (or less than a quarter full),
// which are put on the free list and used again (see Btree.store_leaf), so the
// file stops growing when the rows are deleted and others are added. That's
// true whether the new rows have the same keys as the deleted ones, keys that
// come after them, or keys in a random order, and when some of the old rows
// are kept.
fn test_page_reuse() ! {
	rows := 1000
	rounds := 12
	for pattern in ['same', 'sequential', 'random', 'kept'] {
		file_name := 'test_page_reuse_${pattern}.vsql'
		if os.exists(file_name) {
			os.rm(file_name)!
		}

		rand.seed([u32(1736), 1])
		mut db := open(file_name)!
		db.query('CREATE TABLE t (id INT PRIMARY KEY, round INT, body VARCHAR(200))')!
		mut sizes := []i64{}
		mut used := map[int]bool{}
		for round in 0 .. rounds {
			if pattern == 'kept' {
				// Every 10th row is kept, so the old pages are never empty.
				db.query('DELETE FROM t WHERE round < ${round} AND MOD(id, 10) <> 0')!
			} else {
				db.query('DELETE FROM t WHERE round < ${round}')!
			}

			mut values := []string{}
			for i in 0 .. rows {
				id := match pattern {
					'same' {
						i
					}
					'random' {
						mut id := rand.intn(1000000000)!
						for (id in used) {
							id = rand.intn(1000000000)!
						}
						used[id] = true
						id
					}
					else {
						round * rows + i
					}
				}
				values << "(${id}, ${round}, '${'x'.repeat(150)}')"
			}
			db.query('INSERT INTO t (id, round, body) VALUES ${values.join(', ')}')!
			sizes << os.file_size(file_name)
		}

		expected := if pattern == 'kept' { (rounds - 1) * rows / 10 + rows } else { rows }
		mut result := db.query('SELECT COUNT(*) FROM t')!
		count := result.next()?.get('COL1')!.int_value()
		assert count == expected, pattern
		db.close()

		// Keys in a random order split pages that aren't full, so the pages
		// are less full than the first rounds, until it settles (about 9% more
		// pages than the third round, from the 11th round to at least the
		// 40th).
		if pattern == 'kept' {
			// Only the kept rows (100 a round, about 5 pages) need more pages.
			assert sizes.last() - sizes[2] < (rounds - 3) * 10 * 4096, '${pattern}: ${sizes}'
		} else {
			assert sizes.last() <= sizes[2] * 11 / 10, '${pattern}: ${sizes}'
		}

		os.rm(file_name)!
	}
}

// A page that's freed is the next one that's added, in the order that they're
// freed (newest first), for the pages of a file or in memory.
fn test_free_page_list() ! {
	mut pager := new_memory_pager()
	for _ in 0 .. 3 {
		pager.append_page(new_page(kind_leaf, 256))!
	}
	pager.free_page(0)!
	pager.free_page(2)!
	assert pager.first_free_page() == 2
	assert pager.append_page(new_page(kind_leaf, 256))! == 2
	assert pager.first_free_page() == 0
	assert pager.append_page(new_page(kind_leaf, 256))! == 0
	assert pager.first_free_page() == -1
	assert pager.append_page(new_page(kind_leaf, 256))! == 3
}
