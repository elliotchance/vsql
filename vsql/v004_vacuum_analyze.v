// v004_vacuum_analyze.v contains VACUUM ANALYZE, which isn't part of the standard.
// It finds out how much of the database files the objects take, and what each
// mode of VACUUM would make them, without changing anything.

module vsql

import time

// AnalyzeCounts are the leaf pages and objects of one object (see
// vacuum_object), or of every leaf page of the file.
struct AnalyzeCounts {
mut:
	pages            int
	used_bytes       i64
	versions         int
	expired_versions int
	// pages_freed are the pages that COMPACT would leave empty, and
	// pages_after_full are the leaf pages that FULL would put the objects in.
	pages_freed      int
	pages_after_full int
	// last_key is the first key of the last page of the object that was read.
	last_key []u8
}

// AnalyzeLevel is one level of the B-tree that FULL would build (the leaves are
// level 0), and its last page so far.
struct AnalyzeLevel {
mut:
	pages     int
	first_key []u8
	consumed  int
	count     int
	last_key  []u8
	last_len  int
}

// AnalyzeFill is the B-tree that FULL would build (see Storage.vacuum), without
// building it. Every object is added in order, which fills each page before the
// next (see fill_objects), and each new page adds a pointer to the level above
// it, once a level has more than one page.
struct AnalyzeFill {
mut:
	max    int
	levels []AnalyzeLevel
}

// add adds an object (or a pointer, above level 0), and returns true if it
// starts a new page. Like fill_objects, two versions of the same key are kept
// on the same page when they fit.
fn (mut f AnalyzeFill) add(level int, key []u8, length int) bool {
	for f.levels.len <= level {
		f.levels << AnalyzeLevel{}
	}

	mut l := f.levels[level]
	mut new_page := l.count == 0
	if !new_page && l.consumed + length > f.max {
		new_page = true
		if l.count > 1 && l.last_key == key && l.last_len + length <= f.max {
			l.consumed = l.last_len
			l.count = 1
		} else {
			l.consumed = 0
			l.count = 0
		}
	}
	if new_page {
		l.pages++
		if l.pages == 1 {
			l.first_key = key.clone()
		}
	}
	l.consumed += length
	l.count++
	l.last_key = key.clone()
	l.last_len = length
	f.levels[level] = l

	if new_page && l.pages > 1 {
		if l.pages == 2 {
			f.add(level + 1, l.first_key, analyze_pointer_length(l.first_key))
		}
		f.add(level + 1, key, analyze_pointer_length(key))
	}

	return new_page
}

// total is every page of the B-tree.
fn (f AnalyzeFill) total() int {
	mut total := 0
	for level in f.levels {
		total += level.pages
	}

	return total
}

fn analyze_pointer_length(key []u8) int {
	return new_page_object(key, 0, 0, []u8{len: 4}).length()
}

// VacuumAnalysis is what VACUUM ANALYZE has found in one catalog.
struct VacuumAnalysis {
	// whole is every leaf page of the B-tree, otherwise only the pages of the
	// objects in ids (see VacuumTarget).
	whole bool
	ids   []string
mut:
	page_size   int
	total_pages int
	free_pages  int
	active      TransactionIDs
	objects     map[string]AnalyzeCounts
	file        AnalyzeCounts
	fill        AnalyzeFill
	// seen are the leaf pages that were counted, since the ranges of two
	// objects can start and end in the same page. It's only needed for ranges.
	seen map[int]bool
	// pages_read is the leaf pages that were read. finished is true once every
	// page was read, otherwise stop is the key that the next batch would have
	// started at, or the objects in unfinished weren't read.
	pages_read int
	finished   bool
	stop       []u8
	unfinished map[string]bool
}

// counts is true for an object that has a row.
fn (a VacuumAnalysis) counts(id string) bool {
	return id != '' && (a.whole || id in a.ids)
}

// leaf counts the objects of a leaf page, and the page for the object of its
// first key. It returns false if the page was already counted.
fn (mut a VacuumAnalysis) leaf(number int, objects []PageObject) bool {
	if !a.whole {
		if number in a.seen {
			return false
		}
		a.seen[number] = true
	}

	a.file.pages++
	if objects.len > 0 {
		id := vacuum_object(objects[0].key)
		if a.counts(id) {
			mut c := a.objects[id] or { AnalyzeCounts{} }
			c.pages++
			c.last_key = objects[0].key.clone()
			a.objects[id] = c
		}
	}

	for object in objects {
		id := vacuum_object(object.key)
		length := object.length()
		expired := object.xid != 0 && !a.active.exists(object.xid)
		a.file.used_bytes += length
		a.file.versions++
		if expired {
			a.file.expired_versions++
		}
		new_page := a.whole && a.fill.add(0, object.key, length)
		if a.counts(id) {
			mut c := a.objects[id] or { AnalyzeCounts{} }
			c.used_bytes += length
			c.versions++
			if expired {
				c.expired_versions++
			}
			if new_page {
				c.pages_after_full++
			}
			a.objects[id] = c
		}
	}

	return true
}

// freed counts a leaf page that COMPACT would leave empty.
fn (mut a VacuumAnalysis) freed(key []u8) {
	a.file.pages_freed++
	id := vacuum_object(key)
	if a.counts(id) {
		mut c := a.objects[id] or { AnalyzeCounts{} }
		c.pages_freed++
		a.objects[id] = c
	}
}

// analyze finds out how many pages the objects (every object, without any)
// take in the files of their catalogs, and how many each mode of VACUUM would
// leave, without changing anything. It's read-only, so it can be in a
// transaction, and it only reads the B-tree in batches (vacuum_batch_pages), so
// other connections can change the database in between (and the numbers may not
// add up exactly). TIMEOUT stops it after the batch that it's in.
//
// The result is "VACUUM ANALYZE pages", the number of leaf pages that were
// read. The rows of VSQL.LAST_VACUUM_ANALYZE (see
// Connection.last_vacuum_analyze) are cleared first, so they're empty if it
// fails.
fn (stmt VacuumStatement) analyze(mut conn Connection, elapsed_parse time.Duration) !Result {
	t := start_timer()
	conn.last_vacuum_analyze = [][]Value{}

	run := VacuumRun{
		stmt:  stmt
		timer: t
	}
	targets := stmt.targets(mut conn)!

	mut read := 0
	mut rows := [][]Value{}
	for target in targets {
		mut a := VacuumAnalysis{
			whole: target.whole
			ids:   target.ids
		}
		a.file_pages(mut conn, target.catalog)!
		a.read(mut conn, run, target)!
		read += a.pages_read
		rows << a.rows(target.catalog, vacuum_names(mut conn, target.catalog)!)
	}
	conn.last_vacuum_analyze = rows

	return new_result_msg('VACUUM ANALYZE ${read}', elapsed_parse, t.elapsed())
}

// file_pages finds the size of the pages, and how many pages (and free pages)
// the file has.
fn (mut a VacuumAnalysis) file_pages(mut conn Connection, catalog_name string) ! {
	mut catalog := conn.catalog_for(Identifier{ catalog_name: catalog_name })
	catalog.open_read_connection()!
	defer {
		catalog.release_read_connection()
	}

	a.page_size = catalog.storage.btree.page_size
	a.fill.max = a.page_size - page_header_size
	a.total_pages = catalog.storage.btree.pager.total_pages()
	a.free_pages = catalog.storage.btree.free_pages()!
}

// read reads the leaf pages of the B-tree (or of each range), one batch at a
// time, see Btree.analyze_leaves.
fn (mut a VacuumAnalysis) read(mut conn Connection, run VacuumRun, target VacuumTarget) ! {
	if target.whole {
		mut start := []u8{}
		for !run.timed_out() {
			done, next := a.batch(mut conn, target.catalog, start, []u8{})!
			if done {
				a.finished = true
				return
			}
			start = next.clone()
		}
		a.stop = start
		return
	}

	for i, range in target.ranges {
		mut start := range.start.clone()
		for {
			if run.timed_out() {
				for unfinished in target.ranges[i..] {
					a.unfinished[unfinished.id] = true
				}
				return
			}

			done, next := a.batch(mut conn, target.catalog, start, range.end)!
			if done {
				break
			}
			start = next.clone()
		}
	}
	a.finished = true
}

fn (mut a VacuumAnalysis) batch(mut conn Connection, catalog_name string, start []u8, end []u8) !(bool, []u8) {
	mut catalog := conn.catalog_for(Identifier{ catalog_name: catalog_name })
	catalog.open_read_connection()!
	defer {
		catalog.release_read_connection()
	}

	a.active = catalog.storage.header.active_transaction_ids
	read, done, next := catalog.storage.btree.analyze_leaves(start, end, vacuum_batch_pages, mut
		a)!
	a.pages_read += read

	return done, next
}

// free_pages is the number of free pages in the file.
fn (mut p Btree) free_pages() !int {
	mut count := 0
	mut page_number := p.pager.first_free_page()
	for page_number >= 0 {
		count++
		page_number = next_free_page(p.pager.read_page(page_number)!)
	}

	return count
}

// analyze_leaves reads the leaf pages of the B-tree like pack_leaves, but
// without changing them. Each page is counted (see VacuumAnalysis.leaf), and
// the objects of each page are moved into the page before it with the same
// parent while they fit (see objects_that_fit), to find the pages that COMPACT
// would leave empty.
//
// It stops at the first page with a key that's not less than end (unless end is
// empty), or once it's read at least max_pages leaf pages, after the last page
// of a parent. It returns the number of leaf pages that it read, true if it
// reached the end, or otherwise the key that the next batch starts at.
fn (mut p Btree) analyze_leaves(start []u8, end []u8, max_pages int, mut a VacuumAnalysis) !(int, bool, []u8) {
	mut read := 0
	mut key := start.clone()
	for read < max_pages {
		path, positions := p.search_page(key)!
		if path.len < 2 {
			// The root is the only page.
			root := p.pager.read_page(path.last())!
			a.leaf(path.last(), root.objects())
			return read + 1, true, []u8{}
		}

		parent := (p.pager.read_page(path[path.len - 2])!).objects()
		mut used := 0
		for i in positions.last() .. parent.len {
			number := page_pointer(parent[i])
			page := p.pager.read_page(number)!
			objects := page.objects()
			read++
			if i == positions.last() {
				a.leaf(number, objects)
				used = int(page.used)
				continue
			}
			if end.len > 0 && compare_bytes(objects[0].key, end) >= 0 {
				return read, true, []u8{}
			}

			counted := a.leaf(number, objects)
			moved, size := objects_that_fit(used, objects, p.page_size)
			if moved == objects.len {
				used += size
				if counted {
					a.freed(objects[0].key)
				}
				continue
			}
			used = int(page.used) - size
		}

		key = p.next_subtree(path, positions)!
		if key.len == 0 || (end.len > 0 && compare_bytes(key, end) >= 0) {
			return read, true, []u8{}
		}
	}

	return read, false, key
}

// rows are the rows of VSQL.LAST_VACUUM_ANALYZE for the catalog (see
// register_vsql_schema): one for each table and index (and the large objects of
// a table that has any), in order of their names, and then one for the file.
// Without objects, that's every table and index of the catalog.
//
// A page is counted for the object of its first key, so an object that only
// has some of the objects of a page can have USED_BYTES without any PAGES. For
// ranges, the columns of the file that need every leaf page are NULL, and so is
// PAGES_AFTER_FULL, since FULL can't be used for them.
fn (a VacuumAnalysis) rows(catalog string, names map[string][]string) [][]Value {
	mut sorted := []string{}
	for id, name in names {
		if a.counts(id) && (!id.starts_with('LARGE OBJECTS ') || id in a.objects) {
			sorted << '${name[0]}\x00${name[2]}\x00${name[3]}\x00${name[1]}\x01${id}'
		}
	}
	sorted.sort()

	null_integer := new_null_value(.is_integer)
	null_bigint := new_null_value(.is_bigint)
	mut rows := [][]Value{}
	for key in sorted {
		id := key.all_after('\x01')
		name := names[id] or { continue }
		c := a.objects[id] or { AnalyzeCounts{} }
		finished := if a.whole {
			a.finished || (c.last_key.len > 0 && vacuum_object(a.stop) != id
				&& compare_bytes(c.last_key, a.stop) < 0)
		} else {
			id !in a.unfinished
		}
		after_compact := c.pages - c.pages_freed
		rows << [
			new_varchar_value(catalog),
			new_varchar_value(name[0]),
			new_varchar_value(name[1]),
			new_varchar_value(name[3][2..]),
			new_integer_value(a.page_size),
			new_integer_value(c.pages),
			a.bytes(c.pages),
			new_bigint_value(c.used_bytes),
			new_integer_value(c.versions),
			new_integer_value(c.expired_versions),
			null_integer,
			null_integer,
			new_integer_value(after_compact),
			if a.whole { new_integer_value(c.pages_after_full) } else { null_integer },
			new_integer_value(c.pages),
			a.bytes(after_compact),
			if a.whole { a.bytes(c.pages_after_full) } else { null_bigint },
			a.bytes(c.pages),
			yes_or_no(finished),
		]
	}

	after_free_pages := a.total_pages - a.free_pages
	after_compact := after_free_pages - a.file.pages_freed
	after_full := if a.fill.total() < a.total_pages { a.fill.total() } else { a.total_pages }
	rows << [
		new_varchar_value(catalog),
		new_null_value(.is_varchar),
		new_null_value(.is_varchar),
		new_varchar_value('FILE'),
		new_integer_value(a.page_size),
		new_integer_value(a.total_pages),
		a.bytes(a.total_pages),
		if a.whole { new_bigint_value(a.file.used_bytes) } else { null_bigint },
		if a.whole { new_integer_value(a.file.versions) } else { null_integer },
		if a.whole { new_integer_value(a.file.expired_versions) } else { null_integer },
		if a.whole { new_integer_value(after_free_pages - a.file.pages) } else { null_integer },
		new_integer_value(a.free_pages),
		new_integer_value(after_compact),
		if a.whole { new_integer_value(after_full) } else { null_integer },
		new_integer_value(after_free_pages),
		a.bytes(after_compact),
		if a.whole { a.bytes(after_full) } else { null_bigint },
		a.bytes(after_free_pages),
		yes_or_no(a.finished),
	]

	return rows
}

fn (a VacuumAnalysis) bytes(pages int) Value {
	return new_bigint_value(i64(pages) * a.page_size)
}
