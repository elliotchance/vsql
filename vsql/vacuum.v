// vacuum.v contains VACUUM, which isn't part of the standard. It makes the
// database file smaller, without taking the database offline.

module vsql

import encoding.binary
import time

// VacuumMode is how VACUUM makes the file smaller, see VacuumStatement.
enum VacuumMode {
	compact
	full
	free_pages
}

enum VacuumOptionKind {
	compact
	full
	free_pages
	verbose
	timeout
}

fn (kind VacuumOptionKind) sql() string {
	return match kind {
		.compact { 'COMPACT' }
		.full { 'FULL' }
		.free_pages { 'FREE PAGES' }
		.verbose { 'VERBOSE' }
		.timeout { 'TIMEOUT' }
	}
}

// VacuumOption is one of the options of VACUUM, before they're checked (see
// new_vacuum_statement).
struct VacuumOption {
	kind    VacuumOptionKind
	timeout Value
}

// VACUUM [ COMPACT | FULL | FREE PAGES ] [ VERBOSE ] [ TIMEOUT seconds ]
//
// The options can be in any order, but each can only be given once.
struct VacuumStatement {
	mode        VacuumMode
	verbose     bool
	has_timeout bool
	timeout     time.Duration
}

// new_vacuum_statement checks that no option is given more than once, and that
// there's only one mode.
fn new_vacuum_statement(options []VacuumOption) !VacuumStatement {
	mut seen := []VacuumOptionKind{}
	mut mode := VacuumMode.compact
	mut has_mode := false
	mut verbose := false
	mut has_timeout := false
	mut timeout := time.Duration(0)
	for option in options {
		if option.kind in seen {
			return sqlstate_42601('VACUUM ${option.kind.sql()} is given more than once')
		}
		seen << option.kind

		match option.kind {
			.compact, .full, .free_pages {
				if has_mode {
					return sqlstate_42601('VACUUM can only have one of COMPACT, FULL and FREE PAGES')
				}
				has_mode = true
				mode = match option.kind {
					.full { VacuumMode.full }
					.free_pages { VacuumMode.free_pages }
					else { VacuumMode.compact }
				}
			}
			.verbose {
				verbose = true
			}
			.timeout {
				has_timeout = true
				timeout = time.Duration(i64(option.timeout.as_f64()! * f64(time.second)))
			}
		}
	}

	return VacuumStatement{
		mode:        mode
		verbose:     verbose
		has_timeout: has_timeout
		timeout:     timeout
	}
}

// vacuum_batch_pages is the most pages that COMPACT and FREE PAGES change
// before they're committed, so that other connections can use the database in
// between, and the changes don't need much memory. It's smaller for the SQL
// tests (see testing_d_vsqltest.v), so that they have more than one batch.
const vacuum_batch_pages = $if vsqltest ? { 4 } $else { 1000 }

// VacuumRun is what a VACUUM has done so far.
struct VacuumRun {
	stmt  VacuumStatement
	timer Timer
mut:
	// scanned is the number of pages that were read (and moved, for FREE
	// PAGES), see VacuumStatement.execute.
	scanned int
	// total_before and total_after are the pages of the file before the first
	// batch and after the last one.
	total_before int = -1
	total_after  int
	// packed is true once COMPACT has packed every leaf page, otherwise
	// pack_stop is the key that the next batch would have started at.
	packed    bool
	pack_stop []u8
	// shrunk is true once there are no free pages left before the end of the
	// file (or FULL has rebuilt it).
	shrunk bool
}

fn (run VacuumRun) timed_out() bool {
	return run.stmt.has_timeout && run.timer.elapsed() >= run.stmt.timeout
}

// observe keeps the number of pages of the file, once the write connection is
// open.
fn (mut run VacuumRun) observe(total_pages int) {
	if run.total_before < 0 {
		run.total_before = total_pages
	}
	run.total_after = total_pages
}

// execute makes the file of the current catalog smaller. It can't be in a
// transaction (it's a 25001 error), because it changes pages, rather than
// rows, which can't be undone by a ROLLBACK. Another connection can have a
// transaction (see Storage.transaction_leaf_pages).
//
// COMPACT (the default) packs the objects of the leaf pages of the B-tree into
// as few pages as they fit in (see Btree.pack_leaves), and then shrinks the
// file (see Btree.shrink). Both are done in batches of vacuum_batch_pages,
// each of which is committed, so the file is unlocked in between. FREE PAGES
// only shrinks the file. FULL rebuilds the whole B-tree in one go (see
// Storage.vacuum).
//
// TIMEOUT stops it after the batch that's running when the time is up, keeping
// what was done (FULL is either done or not changed at all). That isn't an
// error.
//
// The result is "VACUUM scanned removed": the number of pages that were read
// (and moved), and how many pages were removed from the file (including free
// pages). VERBOSE returns a row for each object instead (see vacuum_rows).
fn (stmt VacuumStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	if conn.in_transaction() {
		return sqlstate_25001()
	}

	mut run := VacuumRun{
		stmt:  stmt
		timer: t
	}
	before := if stmt.verbose { vacuum_stats(mut conn)! } else { VacuumStats{} }

	match stmt.mode {
		.full {
			run.full(mut conn)!
		}
		.compact {
			run.pack(mut conn)!
			run.shrink(mut conn)!
		}
		.free_pages {
			run.packed = true
			run.shrink(mut conn)!
		}
	}

	if stmt.verbose {
		after := vacuum_stats(mut conn)!
		return new_result(vacuum_columns(), run.rows(before, after), elapsed_parse, t.elapsed())
	}

	removed := if run.total_before > run.total_after {
		run.total_before - run.total_after
	} else {
		0
	}

	return new_result_msg('VACUUM ${run.scanned} ${removed}', elapsed_parse, t.elapsed())
}

fn (stmt VacuumStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN VACUUM')
}

// full rebuilds the B-tree, see Storage.vacuum.
fn (mut run VacuumRun) full(mut conn Connection) ! {
	run.full_batch(mut conn)!
	conn.finish_write(true)!
}

fn (mut run VacuumRun) full_batch(mut conn Connection) ! {
	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut catalog := conn.catalog()
	run.observe(catalog.storage.btree.pager.total_pages())
	scanned, finished := catalog.storage.vacuum(run)!
	run.scanned += scanned
	run.packed = finished
	run.shrunk = finished
	run.observe(catalog.storage.btree.pager.total_pages())
}

// pack packs the leaf pages, one batch at a time, see Btree.pack_leaves.
fn (mut run VacuumRun) pack(mut conn Connection) ! {
	mut start := []u8{}
	for !run.timed_out() {
		done, next := run.pack_batch(mut conn, start)!
		conn.finish_write(true)!
		if done {
			run.packed = true
			return
		}
		start = next.clone()
	}
	run.pack_stop = start
}

fn (mut run VacuumRun) pack_batch(mut conn Connection, start []u8) !(bool, []u8) {
	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut catalog := conn.catalog()
	run.observe(catalog.storage.btree.pager.total_pages())
	read, done, next := catalog.storage.btree.pack_leaves(start, vacuum_batch_pages)!
	run.scanned += read
	run.observe(catalog.storage.btree.pager.total_pages())

	return done, next
}

// shrink moves pages from the end of the file into free pages, and makes the
// file shorter, one batch at a time, see Btree.shrink.
fn (mut run VacuumRun) shrink(mut conn Connection) ! {
	for !run.timed_out() {
		done := run.shrink_batch(mut conn)!
		conn.finish_write(true)!
		if done {
			run.shrunk = true
			return
		}
	}
}

fn (mut run VacuumRun) shrink_batch(mut conn Connection) !bool {
	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut catalog := conn.catalog()
	run.observe(catalog.storage.btree.pager.total_pages())
	moved, done := catalog.storage.btree.shrink(vacuum_batch_pages)!
	run.scanned += moved
	run.observe(catalog.storage.btree.pager.total_pages())

	return done
}

// vacuum rebuilds the B-tree, so that the file is as small as it can be. Every
// object is added to a new B-tree in order, which fills every page (see
// split_objects), and the new pages replace all of the pages of the file (see
// Pager.replace_pages). The file is made shorter when the statement is
// committed (see wal_checkpoint), and there are no free pages.
//
// A large value is put back together by the iterator (see read_blob), and is
// split again by Btree.add, so its blob and fragment objects aren't copied.
//
// Another connection can have a transaction that's still active. Every version
// of every object is copied, including the ones that a transaction created or
// expired and hasn't committed yet, so its rows look the same to it afterwards.
// The pages that it remembers changing are now other pages (or past the end of
// the file), but it also remembers each key that it changed, and COMMIT and
// ROLLBACK find the page that each key is on now (see
// Storage.transaction_page_numbers). The new B-tree is kept in memory until
// it's written, so it needs as much memory as the file (without its free
// space).
//
// It returns the number of pages of the B-tree that were read (free pages
// aren't read), and false if the TIMEOUT of the VACUUM ran out first, in which
// case nothing is changed. The file isn't changed either when the new B-tree
// wouldn't have fewer pages, which can happen when there's nothing to remove,
// because a large value is split into objects of half a page that can't be
// packed any closer.
fn (mut f Storage) vacuum(run VacuumRun) !(int, bool) {
	mut pager := new_memory_pager()
	mut btree := new_btree(pager, f.btree.page_size)
	mut iter := f.btree.new_range_iterator([u8(0)], [u8(255)])
	for {
		if run.timed_out() {
			return iter.pages_read, false
		}

		object := iter.next() or { break }
		if object.key[0] in [`B`, `F`] {
			continue
		}

		btree.add(PageObject{
			...object
			key:   object.key.clone()
			value: object.value.clone()
		})!
	}
	if err := iter.err {
		return err
	}

	pager.commit()
	if pager.pages.len < f.btree.pager.total_pages() {
		f.btree.pager.replace_pages(pager.pages, pager.root_page)!
	}

	return iter.pages_read, true
}

// pack_leaves packs the leaf pages of the B-tree, starting at the leaf page
// that start would be in. The objects of each page are moved into the page
// before it with the same parent while they fit (see move_objects). A page
// that's left empty is removed from the B-tree (see free_path), so its keys are
// found in the page before it. Otherwise, the pointer to it in the parent is
// changed to its new first key (it's the lower bound of the keys that are
// searched for in the page), which isn't the first pointer of the parent, so
// the pages above it don't change. The pages of different parents aren't
// packed together.
//
// It stops after reading about max_pages leaf pages, and returns the number of
// leaf pages that it read, true if it reached the last leaf page, or otherwise
// the key that the next batch starts at.
fn (mut p Btree) pack_leaves(start []u8, max_pages int) !(int, bool, []u8) {
	mut read := 0
	mut key := start.clone()
	for read < max_pages {
		path, positions := p.search_page(key)!
		if path.len < 2 {
			// The root is the only page.
			return read + 1, true, []u8{}
		}

		parent_path := path[..path.len - 1].clone()
		parent := (p.pager.read_page(parent_path.last())!).objects()
		mut left_number := path.last()
		mut left := p.pager.fetch_page(left_number)!
		mut changed := false
		mut stopped := false
		mut split := false
		read++
		for i in positions.last() + 1 .. parent.len {
			if read >= max_pages {
				stopped = true
				break
			}

			right_number := page_pointer(parent[i])
			objects := (p.pager.read_page(right_number)!).objects()
			read++
			moved := p.move_objects(mut left, objects)!
			changed = changed || moved > 0
			if moved == objects.len {
				mut right_path := parent_path.clone()
				right_path << right_number
				p.free_path(right_path)!
				continue
			}

			if changed {
				p.store_page(left_number, left)!
			}
			left_number = right_number
			left = new_page(kind_leaf, p.page_size)
			for object in objects[moved..] {
				left.add(object)!
			}
			changed = false
			if moved > 0 {
				p.store_page(left_number, left)!
				mut parent_page := p.pager.fetch_page(parent_path.last())!
				if p.replace_pointer(parent_path, mut parent_page, parent[i].key, new_page_object(objects[moved].key,
					0, 0, parent[i].value))! {
					// The parent was split (the new key is longer), so the
					// pointers have changed. It carries on from this page.
					split = true
					break
				}
			}
		}
		if changed {
			p.store_page(left_number, left)!
		}

		if stopped {
			return read, false, left.object_key(0).clone()
		}
		if split {
			key = left.object_key(0).clone()
			continue
		}

		key = p.next_subtree(path, positions)!
		if key.len == 0 {
			return read, true, []u8{}
		}
	}

	return read, false, key
}

// move_objects moves the objects (from the start of the next page) into page
// while they fit, and returns how many were moved. The versions of a key are
// kept together (like split_objects), so they're moved together or not at all.
fn (mut p Btree) move_objects(mut page Page, objects []PageObject) !int {
	mut moved := 0
	for moved < objects.len {
		mut end := moved + 1
		mut size := objects[moved].length()
		for end < objects.len && objects[end].key == objects[moved].key {
			size += objects[end].length()
			end++
		}
		if int(page.used) + size > p.page_size {
			break
		}

		for object in objects[moved..end] {
			page.add(object)!
		}
		moved = end
	}

	return moved
}

// next_subtree returns the key of the pointer after the parent of the leaf page
// at the end of path (from search_page), which is the lower bound of the next
// leaf page with a different parent, or an empty key if there isn't one.
fn (mut p Btree) next_subtree(path []int, positions []int) ![]u8 {
	for level := path.len - 3; level >= 0; level-- {
		pointers := (p.pager.read_page(path[level])!).objects()
		if positions[level] + 1 < pointers.len {
			return pointers[positions[level] + 1].key.clone()
		}
	}

	return []u8{}
}

// shrink makes the file shorter by moving the pages at the end of the file
// into the free pages before them (see move_page), lowest first, and removing
// the free pages that are left at the end. It moves up to max_pages pages, and
// returns how many it moved, and true if there are no free pages left. The free
// pages that are left are linked again in order, so the next batch uses the
// lowest ones first as well.
fn (mut p Btree) shrink(max_pages int) !(int, bool) {
	mut free := []int{}
	mut page_number := p.pager.first_free_page()
	for page_number >= 0 {
		free << page_number
		page_number = next_free_page(p.pager.read_page(page_number)!)
	}
	free.sort()

	mut total := p.pager.total_pages()
	mut lowest := 0
	mut highest := free.len - 1
	mut moved := 0
	for {
		for highest >= lowest && free[highest] == total - 1 {
			total--
			highest--
		}
		if highest < lowest || moved >= max_pages {
			break
		}

		p.move_page(total - 1, free[lowest])!
		lowest++
		total--
		moved++
	}

	left := free[lowest..highest + 1]
	for i, number in left {
		next := if i + 1 < left.len { left[i + 1] } else { -1 }
		if next_free_page(p.pager.read_page(number)!) != next {
			p.store_page(number, new_free_page(next, p.page_size))!
		}
	}
	p.pager.set_first_free_page(if left.len > 0 { left[0] } else { -1 })
	p.pager.truncate(total)

	return moved, left.len == 0
}

// move_page copies the page from one page number to another (a free page), and
// changes the pointer to it in its parent, which is found by searching for the
// first key of the page (or the root page in the header). No other page refers
// to a page by its number. The page that it was in must then be removed.
fn (mut p Btree) move_page(from int, to int) ! {
	page := p.pager.fetch_page(from)!
	p.store_page(to, page)!
	if from == p.pager.root_page() {
		return p.pager.set_root_page(to)
	}

	path, _ := p.search_page(page.object_key(0))!
	parent_number := path[path.index(from) - 1]
	mut parent := p.pager.fetch_page(parent_number)!
	for object in parent.objects() {
		if page_pointer(object) == from {
			mut pointer := new_empty_bytes()
			pointer.write_i32(to)
			parent.delete(object.key, 0)
			parent.add(new_page_object(object.key, 0, 0, pointer.bytes()))!
			break
		}
	}
	p.store_page(parent_number, parent)!
}

// VacuumObjectStats is the leaf pages of a table, an index, or the large
// objects of a table, see vacuum_stats.
struct VacuumObjectStats {
mut:
	pages int
	used  i64
	// last_key is the first key of the last leaf page.
	last_key []u8
}

// VacuumStats is the leaf pages of each object (see vacuum_object), the pages
// of the file, and how many bytes of the pages of the B-tree are used.
struct VacuumStats {
mut:
	objects     map[string]VacuumObjectStats
	total_pages int
	used        i64
	catalog     string
	page_size   int
	// names has the catalog, schema and name of each object, the name of its
	// table (to sort by) and its kind, for every table and index, whether it
	// has pages or not.
	names map[string][]string
}

// vacuum_stats reads every page of the B-tree of the current catalog, with the
// file locked for reading.
fn vacuum_stats(mut conn Connection) !VacuumStats {
	conn.open_read_connection()!
	defer {
		conn.release_read_connection()
	}

	mut catalog := conn.catalog()
	mut stats := VacuumStats{
		total_pages: catalog.storage.btree.pager.total_pages()
		catalog:     conn.current_catalog
		page_size:   catalog.storage.btree.page_size
	}
	for _, table in catalog.storage.tables {
		catalog_name := table.name.catalog_name
		schema_name := table.name.schema_name
		name := table.name.entity_name
		stats.names['TABLE ${table.id}'] = [catalog_name, schema_name, name, name, '1 TABLE']
		stats.names['LARGE OBJECTS ${table.id}'] = [catalog_name, schema_name, name, name,
			'3 LARGE OBJECTS']
	}
	for _, index in catalog.storage.indexes {
		stats.names['INDEX ${index.id}'] = [index.name.catalog_name, index.name.schema_name,
			index.name.entity_name, index.table_name.entity_name, '2 INDEX']
	}
	catalog.storage.btree.vacuum_stats(catalog.storage.btree.pager.root_page(), mut stats)!

	return stats
}

fn (mut p Btree) vacuum_stats(page_number int, mut stats VacuumStats) ! {
	page := p.pager.read_page(page_number)!
	stats.used += page.used
	if page.kind == kind_not_leaf {
		for pointer in page.objects() {
			p.vacuum_stats(page_pointer(pointer), mut stats)!
		}
		return
	}

	// Only the root page can be empty.
	key := if page.used > page_header_size { page.object_key(0) } else { []u8{} }
	id := vacuum_object(key)
	if id == '' {
		return
	}

	mut object := stats.objects[id] or { VacuumObjectStats{} }
	object.pages++
	object.used += page.used
	object.last_key = key.clone()
	stats.objects[id] = object
}

// vacuum_object is the object that a key belongs to: "TABLE id" for a row,
// "INDEX id" for an index entry, "LARGE OBJECTS id" for part of a large value
// (where id is the table ID), or empty for anything else (such as a table
// definition). A blob or fragment object belongs to the object it's part of.
fn vacuum_object(key []u8) string {
	if key.len < 9 {
		return ''
	}

	id := binary.big_endian_u64(key[1..9])
	return match key[0] {
		`B`, `F` { vacuum_object(key[1..]) }
		`R` { 'TABLE ${id}' }
		`X` { 'INDEX ${id}' }
		`L` { 'LARGE OBJECTS ${id}' }
		else { '' }
	}
}

fn vacuum_columns() Columns {
	mut columns := []Column{}
	for name in ['CATALOG', 'SCHEMA', 'NAME', 'KIND'] {
		columns << Column{
			name: Identifier{
				sub_entity_name: name
			}
			typ:  new_type('VARCHAR', 0, 0)
		}
	}
	for name in ['PAGES', 'FILL', 'PAGES_AFTER'] {
		columns << Column{
			name:     Identifier{
				sub_entity_name: name
			}
			typ:      new_type('INTEGER', 0, 0)
			not_null: true
		}
	}
	columns << Column{
		name:     Identifier{
			sub_entity_name: 'FINISHED'
		}
		typ:      new_type('BOOLEAN', 0, 0)
		not_null: true
	}

	return columns
}

// rows are the rows of VERBOSE: one for each table, index and the large
// objects of each table (that have pages), in order of their names, and then
// one for the file. PAGES is the leaf pages before, FILL is how full they were
// (as a percentage of their bytes), and PAGES_AFTER is the leaf pages after.
// FINISHED is false when the TIMEOUT ran out before the object was packed. For
// the file, PAGES is every page of the file (including free pages), and
// FINISHED is false if there are still free pages that could be removed.
fn (run VacuumRun) rows(before VacuumStats, after VacuumStats) []Row {
	// The objects are sorted by their catalog, schema, table name, kind and
	// name, which are followed by the ID so that it can be found again.
	mut sorted := []string{}
	for id, name in before.names {
		if id in before.objects || id in after.objects {
			sorted << '${name[0]}\x00${name[1]}\x00${name[3]}\x00${name[4]}\x00${name[2]}\x01${id}'
		}
	}
	sorted.sort()

	mut rows := []Row{}
	for key in sorted {
		id := key.all_after('\x01')
		name := before.names[id]
		object := before.objects[id] or { VacuumObjectStats{} }
		object_after := after.objects[id] or { VacuumObjectStats{} }
		finished := run.packed || compare_bytes(object.last_key, run.pack_stop) < 0
		rows << new_row({
			'CATALOG':     new_varchar_value(name[0])
			'SCHEMA':      new_varchar_value(name[1])
			'NAME':        new_varchar_value(name[2])
			'KIND':        new_varchar_value(name[4][2..])
			'PAGES':       new_integer_value(object.pages)
			'FILL':        new_integer_value(vacuum_fill(object.used, object.pages, before.page_size))
			'PAGES_AFTER': new_integer_value(object_after.pages)
			'FINISHED':    new_boolean_value(finished)
		})
	}
	rows << new_row({
		'CATALOG':     new_varchar_value(before.catalog)
		'SCHEMA':      new_null_value(.is_varchar)
		'NAME':        new_null_value(.is_varchar)
		'KIND':        new_varchar_value('FILE')
		'PAGES':       new_integer_value(before.total_pages)
		'FILL':        new_integer_value(vacuum_fill(before.used, before.total_pages, before.page_size))
		'PAGES_AFTER': new_integer_value(after.total_pages)
		'FINISHED':    new_boolean_value(run.shrunk)
	})

	return rows
}

fn vacuum_fill(used i64, pages int, page_size int) int {
	size := i64(if pages > 0 { pages } else { 1 }) * page_size

	return int((used * 100 + size / 2) / size)
}
