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
	timeout
}

fn (kind VacuumOptionKind) sql() string {
	return match kind {
		.compact { 'COMPACT' }
		.full { 'FULL' }
		.free_pages { 'FREE PAGES' }
		.timeout { 'TIMEOUT' }
	}
}

// VacuumOption is one of the options of VACUUM, before they're checked (see
// new_vacuum_statement).
struct VacuumOption {
	kind    VacuumOptionKind
	timeout Value
}

enum VacuumObjectKind {
	all
	catalog
	schema
	table
	index
}

// VacuumObject is one of the objects of VACUUM, before it's resolved (see
// VacuumStatement.targets).
struct VacuumObject {
	kind          VacuumObjectKind
	name          Identifier
	indexes       bool = true
	large_objects bool = true
}

// VacuumTableClause is WITH or WITHOUT INDEXES (or LARGE OBJECTS) of a TABLE.
struct VacuumTableClause {
	large_objects bool
	with          bool
}

// new_vacuum_table checks that INDEXES and LARGE OBJECTS are each only given
// once.
fn new_vacuum_table(name Identifier, clauses []VacuumTableClause) !VacuumObject {
	mut seen := []bool{}
	mut indexes := true
	mut large_objects := true
	for clause in clauses {
		if clause.large_objects in seen {
			what := if clause.large_objects { 'LARGE OBJECTS' } else { 'INDEXES' }
			return sqlstate_42601('VACUUM TABLE can only have one of WITH ${what} and WITHOUT ${what}')
		}
		seen << clause.large_objects
		if clause.large_objects {
			large_objects = clause.with
		} else {
			indexes = clause.with
		}
	}

	return VacuumObject{
		kind:          .table
		name:          name
		indexes:       indexes
		large_objects: large_objects
	}
}

// new_vacuum_catalog is the name of a catalog, which is an identifier on its
// own (it may need to be delimited, such as "my-db").
fn new_vacuum_catalog(s string) !VacuumObject {
	parts := split_identifier_parts(s)!
	if parts.len != 1 {
		return sqlstate_42602('invalid catalog name: ${s}')
	}

	return VacuumObject{
		kind: .catalog
		name: Identifier{
			catalog_name: parts[0]
		}
	}
}

// VACUUM [ ON object ... ] [ COMPACT | FULL | FREE PAGES ] [ TIMEOUT seconds ]
//
// object is ALL (the default), CATALOG name, SCHEMA name, TABLE name [ { WITH
// | WITHOUT } INDEXES ] [ { WITH | WITHOUT } LARGE OBJECTS ] or INDEX name. The
// options can be in any order, but each can only be given once.
struct VacuumStatement {
	objects     []VacuumObject
	mode        VacuumMode
	has_timeout bool
	timeout     time.Duration
}

// new_vacuum_statement checks that no option is given more than once, that
// there's only one mode, that ALL is on its own, and that FULL is only for
// whole catalogs.
fn new_vacuum_statement(objects []VacuumObject, options []VacuumOption) !VacuumStatement {
	if objects.len > 1 && objects.any(it.kind == .all) {
		return sqlstate_42601('VACUUM ALL can only be on its own')
	}

	mut seen := []VacuumOptionKind{}
	mut mode := VacuumMode.compact
	mut has_mode := false
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
			.timeout {
				has_timeout = true
				timeout = time.Duration(i64(option.timeout.as_f64()! * f64(time.second)))
			}
		}
	}

	if mode == .full && objects.any(it.kind !in [.all, .catalog]) {
		return sqlstate_42601('VACUUM FULL can only be used for ALL or a CATALOG')
	}

	return VacuumStatement{
		objects:     objects
		mode:        mode
		has_timeout: has_timeout
		timeout:     timeout
	}
}

// vacuum_batch_pages is the most pages that COMPACT and FREE PAGES change
// before they're committed, so that other connections can use the database in
// between, and the changes don't need much memory. It's smaller for the SQL
// tests, so that they have more than one batch.
const vacuum_batch_pages = $if vsqltest ? { 4 } $else { 1000 }

// VacuumRange is the keys from start up to (but not including) end, of one of
// the objects (see vacuum_object).
struct VacuumRange {
	start []u8
	end   []u8
	id    string
}

// VacuumTarget is a catalog that VACUUM makes smaller, and what it has done so
// far.
@[heap]
struct VacuumTarget {
	catalog string
mut:
	// whole is true for every page of the B-tree (ALL or CATALOG), otherwise
	// only the pages of ranges are packed, which are the objects of ids.
	whole  bool
	ranges []VacuumRange
	ids    []string
	// total_before and total_after are the pages of the file before the first
	// batch and after the last one.
	total_before int = -1
	total_after  int
	// packed is true once every page has been packed. Otherwise, for a whole
	// catalog, pack_stop is the key that the next batch would have started at,
	// or the objects in unfinished weren't packed.
	packed     bool
	pack_stop  []u8
	unfinished map[string]bool
	// shrunk is true once there are no free pages left before the end of the
	// file (or FULL has rebuilt it).
	shrunk bool
	// objects are the pages that were packed, for each object (see
	// vacuum_object), and file_pages_read is the pages that were moved by
	// shrink (or read by FULL).
	objects         map[string]VacuumObjectCounts
	file_pages_read int
}

// VacuumObjectCounts is the leaf pages of an object (see vacuum_object) that
// were read and freed by Btree.pack_leaves.
struct VacuumObjectCounts {
mut:
	pages_read  int
	pages_freed int
	// last_key is the first key of the last page that was read.
	last_key []u8
}

// count_read counts a leaf page that was read for the object that's being
// packed (owner), or otherwise the object of its first key.
fn (mut objects map[string]VacuumObjectCounts) count_read(owner string, key []u8) {
	id := if owner != '' { owner } else { vacuum_object(key) }
	if id == '' {
		return
	}
	mut object := objects[id] or { VacuumObjectCounts{} }
	object.pages_read++
	object.last_key = key.clone()
	objects[id] = object
}

// count_freed counts a leaf page that was freed, like count_read.
fn (mut objects map[string]VacuumObjectCounts) count_freed(owner string, key []u8) {
	id := if owner != '' { owner } else { vacuum_object(key) }
	if id == '' {
		return
	}
	mut object := objects[id] or { VacuumObjectCounts{} }
	object.pages_freed++
	objects[id] = object
}

// observe keeps the number of pages of the file, once the write connection is
// open.
fn (mut target VacuumTarget) observe(total_pages int) {
	if target.total_before < 0 {
		target.total_before = total_pages
	}
	target.total_after = total_pages
}

// add_range adds the range of the keys of an object, which start with prefix and
// then the ID as a u64, along with the blob and fragment objects of a large
// value of the object (see blob_object_key and fragment_object_key).
fn (mut target VacuumTarget) add_range(prefix u8, id u64, object string) {
	if object !in target.ids {
		target.ids << object
	}
	for parts in [[prefix], [u8(`B`), prefix], [u8(`F`), prefix]] {
		mut start := new_empty_bytes()
		start.write_u8s(parts)
		start.write_u64(id)
		mut end := new_empty_bytes()
		end.write_u8s(parts)
		end.write_u64(id + 1)
		if !target.ranges.any(it.start == start.bytes()) {
			target.ranges << VacuumRange{start.bytes(), end.bytes(), object}
		}
	}
}

// add_table adds the rows of a table, and its indexes and large objects.
fn (mut target VacuumTarget) add_table(storage Storage, table Table, indexes bool, large_objects bool) {
	target.add_range(`R`, table.id, 'TABLE ${table.id}')
	if large_objects {
		target.add_range(`L`, table.id, 'LARGE OBJECTS ${table.id}')
	}
	if indexes {
		for _, index in storage.indexes {
			if index.table_id == table.id {
				target.add_range(`X`, index.id, 'INDEX ${index.id}')
			}
		}
	}
}

// targets resolves the objects into the catalogs that they're in (in order of
// their names), with the files locked for reading. A table must exist (42P01),
// and an index (42704), schema (3F000) or catalog (3D000).
fn (stmt VacuumStatement) targets(mut conn Connection) ![]&VacuumTarget {
	conn.open_read_connection()!
	defer {
		conn.release_read_connection()
	}

	mut targets := map[string]&VacuumTarget{}
	objects := if stmt.objects.len > 0 { stmt.objects } else { [VacuumObject{}] }
	for object in objects {
		match object.kind {
			.all {
				for name, _ in conn.catalogs {
					vacuum_target(mut targets, name).whole = true
				}
			}
			.catalog {
				name := conn.resolve_catalog_identifier(object.name)!
				vacuum_target(mut targets, name.catalog_name).whole = true
			}
			.schema {
				name := conn.resolve_schema_identifier(object.name)!
				catalog := conn.catalog_for(name)
				mut target := vacuum_target(mut targets, name.catalog_name)
				for _, table in catalog.storage.tables {
					if table.name.schema_name == name.schema_name {
						target.add_table(catalog.storage, table, true, true)
					}
				}
			}
			.table {
				name := conn.resolve_table_identifier(object.name, false)!
				catalog := conn.catalog_for(name)
				mut target := vacuum_target(mut targets, name.catalog_name)
				target.add_table(catalog.storage, catalog.storage.table(name.storage_id()),
					object.indexes, object.large_objects)
			}
			.index {
				name := conn.resolve_schema_identifier(object.name)!
				catalog := conn.catalog_for(name)
				index := catalog.storage.indexes[name.storage_id()] or {
					return sqlstate_42704('index', name.str())
				}
				vacuum_target(mut targets, name.catalog_name).add_range(`X`, index.id,
					'INDEX ${index.id}')
			}
		}
	}

	mut names := targets.keys()
	names.sort()
	mut sorted := []&VacuumTarget{}
	for name in names {
		mut target := targets[name] or { continue }
		target.ranges.sort_with_compare(fn (a &VacuumRange, b &VacuumRange) int {
			return compare_bytes(a.start, b.start)
		})
		sorted << target
	}

	return sorted
}

fn vacuum_target(mut targets map[string]&VacuumTarget, catalog string) &VacuumTarget {
	if catalog !in targets {
		targets[catalog] = &VacuumTarget{
			catalog: catalog
		}
	}

	return targets[catalog] or { panic(catalog) }
}

// VacuumRun is a VACUUM that's running.
struct VacuumRun {
	stmt  VacuumStatement
	timer Timer
mut:
	// scanned is the number of pages that were read (and moved), see
	// VacuumStatement.execute.
	scanned int
}

fn (run VacuumRun) timed_out() bool {
	return run.stmt.has_timeout && run.timer.elapsed() >= run.stmt.timeout
}

// execute makes the files of the catalogs of the objects smaller (every
// catalog, without any objects). It can't be in a transaction (it's a 25001
// error), because it changes pages, rather than rows, which can't be undone by
// a ROLLBACK. Another connection can have a transaction (see
// Storage.transaction_leaf_pages).
//
// COMPACT (the default) packs the objects of the leaf pages of the B-tree (or
// only the pages of the objects, see VacuumTarget) into as few pages as they
// fit in (see Btree.pack_leaves), and then shrinks the file (see Btree.shrink).
// Both are done in batches of vacuum_batch_pages, each of which is committed,
// so the file is unlocked in between. FREE PAGES only shrinks the files of
// the objects. FULL rebuilds the whole B-tree in one go (see Storage.vacuum).
//
// TIMEOUT stops it after the batch that's running when the time is up, keeping
// what was done (FULL is either done or not changed at all). That isn't an
// error.
//
// The result is "VACUUM scanned removed": the number of pages that were read
// (and moved), and how many pages were removed from the files (including free
// pages). The rows of VSQL.LAST_VACUUM (see Connection.last_vacuum) have the
// same numbers for each object and file. They're cleared first, so they're
// empty if VACUUM fails.
fn (stmt VacuumStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	if conn.in_transaction() {
		return sqlstate_25001()
	}
	conn.last_vacuum = [][]Value{}

	mut run := VacuumRun{
		stmt:  stmt
		timer: t
	}
	mut targets := stmt.targets(mut conn)!

	for mut target in targets {
		match stmt.mode {
			.full {
				run.full(mut conn, mut target)!
			}
			.compact {
				run.pack(mut conn, mut target)!
				run.shrink(mut conn, mut target)!
			}
			.free_pages {
				target.packed = true
				run.shrink(mut conn, mut target)!
			}
		}
	}

	mut removed := 0
	mut rows := [][]Value{}
	for target in targets {
		removed += target.pages_removed()
		rows << target.rows(vacuum_names(mut conn, target.catalog)!)
	}
	conn.last_vacuum = rows

	return new_result_msg('VACUUM ${run.scanned} ${removed}', elapsed_parse, t.elapsed())
}

fn (stmt VacuumStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN VACUUM')
}

// full rebuilds the B-tree, see Storage.vacuum.
fn (mut run VacuumRun) full(mut conn Connection, mut target VacuumTarget) ! {
	run.full_batch(mut conn, mut target)!
	conn.finish_write(true)!
}

fn (mut run VacuumRun) full_batch(mut conn Connection, mut target VacuumTarget) ! {
	mut catalog := conn.catalog_for(Identifier{ catalog_name: target.catalog })
	catalog.open_write_connection()!
	defer {
		catalog.release_write_connection()
	}

	target.observe(catalog.storage.btree.pager.total_pages())
	scanned, finished := catalog.storage.vacuum(run)!
	run.scanned += scanned
	target.file_pages_read += scanned
	target.packed = finished
	target.shrunk = finished
	target.observe(catalog.storage.btree.pager.total_pages())
}

// pack packs the leaf pages (of the whole B-tree, or each range), one batch at
// a time, see Btree.pack_leaves.
fn (mut run VacuumRun) pack(mut conn Connection, mut target VacuumTarget) ! {
	if target.whole {
		mut start := []u8{}
		for !run.timed_out() {
			done, next := run.pack_batch(mut conn, mut target, start, []u8{}, '')!
			if done {
				target.packed = true
				return
			}
			start = next.clone()
		}
		target.pack_stop = start
		return
	}

	for i, range in target.ranges {
		// A range without any keys (such as the large objects of a table that
		// doesn't have any) isn't packed, or counted.
		if !run.has_keys(mut conn, target, range)! {
			continue
		}

		mut start := range.start.clone()
		for {
			if run.timed_out() {
				for unfinished in target.ranges[i..] {
					target.unfinished[unfinished.id] = true
				}
				return
			}

			done, next := run.pack_batch(mut conn, mut target, start, range.end, range.id)!
			if done {
				break
			}
			start = next.clone()
		}
	}
	target.packed = true
}

// has_keys is true if there's an object in the range.
fn (run VacuumRun) has_keys(mut conn Connection, target VacuumTarget, range VacuumRange) !bool {
	mut catalog := conn.catalog_for(Identifier{ catalog_name: target.catalog })
	catalog.open_read_connection()!
	defer {
		catalog.release_read_connection()
	}

	// The end isn't a key itself, since a key always has more after the ID.
	mut iter := catalog.storage.btree.new_range_iterator(range.start, range.end)
	if _ := iter.next() {
		return true
	}
	if err := iter.err {
		return err
	}

	return false
}

fn (mut run VacuumRun) pack_batch(mut conn Connection, mut target VacuumTarget, start []u8, end []u8, owner string) !(bool, []u8) {
	done, next := run.pack_pages(mut conn, mut target, start, end, owner)!
	conn.finish_write(true)!

	return done, next
}

fn (mut run VacuumRun) pack_pages(mut conn Connection, mut target VacuumTarget, start []u8, end []u8, owner string) !(bool, []u8) {
	mut catalog := conn.catalog_for(Identifier{ catalog_name: target.catalog })
	catalog.open_write_connection()!
	defer {
		catalog.release_write_connection()
	}

	target.observe(catalog.storage.btree.pager.total_pages())
	read, done, next := catalog.storage.btree.pack_leaves(start, end, vacuum_batch_pages, owner, mut
		target.objects)!
	run.scanned += read
	target.observe(catalog.storage.btree.pager.total_pages())

	return done, next
}

// shrink moves pages from the end of the file into free pages, and makes the
// file shorter, one batch at a time, see Btree.shrink.
fn (mut run VacuumRun) shrink(mut conn Connection, mut target VacuumTarget) ! {
	for !run.timed_out() {
		done := run.shrink_batch(mut conn, mut target)!
		conn.finish_write(true)!
		if done {
			target.shrunk = true
			return
		}
	}
}

fn (mut run VacuumRun) shrink_batch(mut conn Connection, mut target VacuumTarget) !bool {
	mut catalog := conn.catalog_for(Identifier{ catalog_name: target.catalog })
	catalog.open_write_connection()!
	defer {
		catalog.release_write_connection()
	}

	target.observe(catalog.storage.btree.pager.total_pages())
	moved, done := catalog.storage.btree.shrink(vacuum_batch_pages)!
	run.scanned += moved
	target.file_pages_read += moved
	target.observe(catalog.storage.btree.pager.total_pages())

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
// It stops at the first page with a key that's not less than end (unless end is
// empty), or after reading about max_pages leaf pages. It returns the number of
// leaf pages that it read, true if it reached the end, or otherwise the key
// that the next batch starts at. Each page that's read (and freed) is counted in
// objects, for owner (the object of the range, if any), see count_read.
fn (mut p Btree) pack_leaves(start []u8, end []u8, max_pages int, owner string, mut objects map[string]VacuumObjectCounts) !(int, bool, []u8) {
	mut read := 0
	mut key := start.clone()
	for read < max_pages {
		path, positions := p.search_page(key)!
		if path.len < 2 {
			// The root is the only page.
			root := p.pager.read_page(path.last())!
			if root.used > page_header_size {
				objects.count_read(owner, root.object_key(0))
			}
			return read + 1, true, []u8{}
		}

		parent_path := path[..path.len - 1].clone()
		parent := (p.pager.read_page(parent_path.last())!).objects()
		mut left_number := path.last()
		mut left := p.pager.fetch_page(left_number)!
		mut changed := false
		mut stopped := false
		mut split := false
		mut reached_end := false
		read++
		objects.count_read(owner, left.object_key(0))
		for i in positions.last() + 1 .. parent.len {
			if read >= max_pages {
				stopped = true
				break
			}

			right_number := page_pointer(parent[i])
			right := (p.pager.read_page(right_number)!).objects()
			read++
			objects.count_read(owner, right[0].key)
			if end.len > 0 && compare_bytes(right[0].key, end) >= 0 {
				reached_end = true
				break
			}
			moved := p.move_objects(mut left, right)!
			changed = changed || moved > 0
			if moved == right.len {
				objects.count_freed(owner, right[0].key)
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
			for object in right[moved..] {
				left.add(object)!
			}
			changed = false
			if moved > 0 {
				p.store_page(left_number, left)!
				mut parent_page := p.pager.fetch_page(parent_path.last())!
				if p.replace_pointer(parent_path, mut parent_page, parent[i].key, new_page_object(right[moved].key,
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
		if reached_end {
			return read, true, []u8{}
		}
		if split {
			key = left.object_key(0).clone()
			continue
		}

		key = p.next_subtree(path, positions)!
		if key.len == 0 || (end.len > 0 && compare_bytes(key, end) >= 0) {
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

// vacuum_names has the schema and name of each object of a catalog (see
// vacuum_object), the name of its table (to sort by) and its type, for every
// table and index.
fn vacuum_names(mut conn Connection, catalog_name string) !map[string][]string {
	mut catalog := conn.catalog_for(Identifier{ catalog_name: catalog_name })
	catalog.open_read_connection()!
	defer {
		catalog.release_read_connection()
	}

	mut names := map[string][]string{}
	for _, table in catalog.storage.tables {
		schema_name := table.name.schema_name
		name := table.name.entity_name
		names['TABLE ${table.id}'] = [schema_name, name, name, '1 TABLE']
		names['LARGE OBJECTS ${table.id}'] = [schema_name, name, name, '3 LARGE OBJECTS']
	}
	for _, index in catalog.storage.indexes {
		names['INDEX ${index.id}'] = [index.name.schema_name, index.name.entity_name,
			index.table_name.entity_name, '2 INDEX']
	}

	return names
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

// pages_removed is the number of pages that the file is shorter by.
fn (target VacuumTarget) pages_removed() int {
	return if target.total_before > target.total_after {
		target.total_before - target.total_after
	} else {
		0
	}
}

// rows are the rows of VSQL.LAST_VACUUM for the catalog (see
// register_vsql_schema): one for each table, index and the large objects of a
// table that had pages packed (or that wasn't finished), in order of their
// names, and then one for the file. For a whole catalog, a page is counted for
// the object of its first key (a page with only definitions isn't counted for
// any). Otherwise, each page that was read to pack an object is counted for it,
// including the pages at its start and end that it shares with another object.
// An object is finished when all of its pages were packed before the TIMEOUT. The file has
// the pages that were moved (or read by FULL) and removed, and is finished when
// there are no free pages left.
fn (target VacuumTarget) rows(names map[string][]string) [][]Value {
	// The objects are sorted by their schema, table name, type and name, which
	// are followed by the ID so that it can be found again. An object that was
	// created or dropped since the VACUUM started has no name, so it's left out.
	mut ids := target.objects.keys()
	for id, _ in target.unfinished {
		if id !in target.objects {
			ids << id
		}
	}
	mut sorted := []string{}
	for id in ids {
		name := names[id] or { continue }
		sorted << '${name[0]}\x00${name[2]}\x00${name[3]}\x00${name[1]}\x01${id}'
	}
	sorted.sort()

	mut rows := [][]Value{}
	for key in sorted {
		id := key.all_after('\x01')
		name := names[id] or { continue }
		object := target.objects[id] or { VacuumObjectCounts{} }
		finished := if target.whole {
			target.packed || compare_bytes(object.last_key, target.pack_stop) < 0
		} else {
			id !in target.unfinished
		}
		rows << [
			new_varchar_value(target.catalog),
			new_varchar_value(name[0]),
			new_varchar_value(name[1]),
			new_varchar_value(name[3][2..]),
			new_integer_value(object.pages_read),
			new_integer_value(object.pages_freed),
			yes_or_no(finished),
		]
	}
	rows << [
		new_varchar_value(target.catalog),
		new_null_value(.is_varchar),
		new_null_value(.is_varchar),
		new_varchar_value('FILE'),
		new_integer_value(target.file_pages_read),
		new_integer_value(target.pages_removed()),
		yes_or_no(target.shrunk),
	]

	return rows
}
