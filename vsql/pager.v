// pager.v contains the interface and implementation for a pager that stores
// pages in memory or on disk.
//
// A new pager is created for each operation on the file. See btree.v.
//
// See https://github.com/elliotchance/vsql/issues/45.

module vsql

import encoding.binary
import os

// A page that's given to store_page or append_page belongs to the pager, so it
// must not be changed after that. So read_page can return the pager's own copy
// of a page, which is only for reading. fetch_page returns a copy that can be
// changed and stored again.
interface Pager {
mut:
	fetch_page(page_number int) !Page
	read_page(page_number int) !Page
	store_page(page_number int, page Page) !
	append_page(page Page) !int
	total_pages() int
	root_page() int
	set_root_page(page_number int) !
	// free_page puts a page that's no longer in the B-tree on the free list, so
	// that append_page can use it again instead of adding a page to the end.
	// The free list is a chain of kind_free pages, starting at first_free_page.
	free_page(page_number int) !
	first_free_page() int
	// set_first_free_page starts the free list at page_number (-1 for none),
	// once the free pages have been linked again. See Btree.shrink.
	set_first_free_page(page_number int)
	// truncate removes the pages from total_pages to the end of the file,
	// which must not be in the B-tree or on the free list. The file is made
	// shorter when the statement is committed. See Btree.shrink.
	truncate(total_pages int)
	// replace_pages replaces all of the pages with pages (which are numbered
	// from 0), and root as the root page. Any other pages are removed from the
	// end of the file, and there are no free pages. See Storage.vacuum.
	replace_pages(pages []Page, root int) !
	// discard forgets the pages changed by the current statement, because it
	// failed. See Storage.discard_statement.
	discard()
}

struct MemoryPager {
mut:
	// root_page is the starting page for a traversal. The root page may change
	// as balancing happens on the tree.
	root_page int
	pages     []Page
	// dirty contains the pages changed by the current statement, which are
	// only kept once the statement succeeds (see commit). total is the number
	// of pages including these changes.
	dirty           map[int]Page
	total           int
	saved_root_page int
	// free is the first free page (see Pager.free_page), or -1 for none.
	free       int = -1
	saved_free int = -1
}

fn new_memory_pager() &MemoryPager {
	return &MemoryPager{}
}

// A page is copied by fetch_page because the B-tree changes the data of a page
// in place before storing it. It's not copied again by store_page and
// append_page, because the page that's stored isn't changed after that.
fn (mut p MemoryPager) fetch_page(page_number int) !Page {
	return (p.read_page(page_number)!).clone()
}

fn (mut p MemoryPager) read_page(page_number int) !Page {
	page := if page_number in p.dirty {
		unsafe { &p.dirty[page_number] }
	} else {
		unsafe { &p.pages[page_number] }
	}

	// The page is a view of the pager's page (like FilePager's page_view), so
	// it isn't copied. Its data is a slice, which V never frees, so -autofree
	// can't free the pager's page through it
	// (https://github.com/vlang/v/issues/32937).
	return Page{
		kind: page.kind
		used: page.used
		data: unsafe { page.data[0..page.data.len] }
	}
}

// The pages that MemoryPager keeps are copies (see own_copy), because
// -autofree frees the page that's given, and the old pages when they're
// replaced (https://github.com/vlang/v/issues/32943).
fn (mut p MemoryPager) store_page(page_number int, page Page) ! {
	h := arena_pause()
	// page may be a view of the page it replaces (see read_page), so it's
	// copied before that one is freed.
	copy := page.clone()
	free_dirty_page(mut p.dirty, page_number)
	p.dirty[page_number] = copy
	arena_resume(h)
}

// free_dirty_page frees the page that the current statement already changed
// (it's the pager's own copy) before it's replaced or removed, since -autofree
// doesn't free a map value that's replaced
// (https://github.com/vlang/v/issues/32943).
@[manualfree]
fn free_dirty_page(mut dirty map[int]Page, page_number int) {
	$if autofree {
		if page_number in dirty {
			mut page := unsafe { &dirty[page_number] }
			unsafe { page.data.free() }
		}
	}
}

// free_dirty_pages frees every page the current statement changed (see
// free_dirty_page) and empties dirty.
@[manualfree]
fn free_dirty_pages(mut dirty map[int]Page) {
	$if autofree {
		for page_number, _ in dirty {
			free_dirty_page(mut dirty, page_number)
		}
		// -autofree also makes free() create a new empty map (see free_map).
		unsafe { dirty.free() }
	} $else {
		dirty = map[int]Page{}
	}
}

fn (mut p MemoryPager) total_pages() int {
	return p.total
}

fn (mut p MemoryPager) append_page(page Page) !int {
	if p.free >= 0 {
		page_number := p.free
		p.free = next_free_page(p.read_page(page_number)!)
		h := arena_pause()
		p.dirty[page_number] = page.clone()
		arena_resume(h)
		return page_number
	}

	h := arena_pause()
	p.dirty[p.total] = page.clone()
	arena_resume(h)
	p.total++

	return p.total - 1
}

fn (mut p MemoryPager) root_page() int {
	return p.root_page
}

fn (mut p MemoryPager) set_root_page(page_number int) ! {
	p.root_page = page_number
}

fn (mut p MemoryPager) free_page(page_number int) ! {
	p.store_page(page_number, new_free_page(p.free, p.read_page(page_number)!.page_size()))!
	p.free = page_number
}

fn (mut p MemoryPager) first_free_page() int {
	return p.free
}

fn (mut p MemoryPager) set_first_free_page(page_number int) {
	p.free = page_number
}

fn (mut p MemoryPager) truncate(total_pages int) {
	for page_number, _ in p.dirty {
		if page_number >= total_pages {
			free_dirty_page(mut p.dirty, page_number)
			p.dirty.delete(page_number)
		}
	}
	p.total = total_pages
}

fn (mut p MemoryPager) replace_pages(pages []Page, root int) ! {
	// The pager outlives the statement (see arena_pause).
	h := arena_pause()
	defer {
		arena_resume(h)
	}
	free_dirty_pages(mut p.dirty)
	for i, page in pages {
		p.dirty[i] = page.clone()
	}
	p.total = pages.len
	p.root_page = root
	p.free = -1
}

// commit keeps the pages changed by the current statement. They're moved
// rather than copied, and the pages they replace are freed (-autofree doesn't
// free an array element that's replaced).
@[manualfree]
fn (mut p MemoryPager) commit() {
	// The pager outlives the statement (see arena_pause).
	h := arena_pause()
	defer {
		arena_resume(h)
	}
	// Only the changed pages are replaced, rather than copying all of them,
	// since a page that's stored is never changed in place.
	for p.pages.len < p.total {
		p.pages << Page{}
	}
	p.pages.trim(p.total)
	for i, _ in p.dirty {
		$if autofree {
			unsafe { p.pages[i].data.free() }
		}
		// The page is moved with vmemcpy, since -autofree clones a page that's
		// assigned (with Page.clone), even from a pointer.
		mut page := unsafe { &p.dirty[i] }
		unsafe { vmemcpy(&p.pages[i], page, int(sizeof(Page))) }
		// The page was moved, so freeing the map below mustn't free it.
		page.data.flags |= .nofree
	}

	$if autofree {
		// -autofree also makes free() create a new empty map (see free_map).
		unsafe { p.dirty.free() }
	} $else {
		p.dirty = map[int]Page{}
	}
	p.saved_root_page = p.root_page
	p.saved_free = p.free
}

fn (mut p MemoryPager) discard() {
	// The pager outlives the statement (see arena_pause).
	h := arena_pause()
	defer {
		arena_resume(h)
	}
	free_dirty_pages(mut p.dirty)
	p.total = p.pages.len
	p.root_page = p.saved_root_page
	p.free = p.saved_free
}

struct FilePager {
	page_size int
mut:
	file        os.File
	total_pages int
	// dirty contains the pages that have been changed, which are only written
	// to the file at the end of the statement, see wal_prepare.
	dirty map[int][]u8
	// root_page is the starting page for a traversal. The root page may change
	// as balancing happens on the tree.
	root_page int
	// cache keeps up to cache_size pages that were read from the file, so that
	// reading them again doesn't read the file. The pager is only used while
	// the file is locked, so the file can't change underneath it, and it's only
	// used again by the next statement if no other connection changed the file
	// in between (see Storage.open). cache_order is the page numbers in the order they were added (a ring
	// starting at cache_next) so that the oldest one is removed when it's full.
	cache_size  int
	cache       map[int][]u8
	cache_order []int
	cache_next  int
	// retired is the data of the pages removed from the cache by this
	// statement (with -autofree). They're freed by the next statement (see
	// begin), because a page that was read is a view of the cached data (see
	// page_view) that the statement may still use.
	retired []voidptr
	// undo has each page that the current statement changed as it was before
	// the statement (or is in undo_new if it wasn't dirty), and the total
	// pages and root page before it, so that discard can put back what was
	// there before the statement. That's only more than nothing when a
	// transaction keeps its pages until it ends, see Storage.prepare_commit.
	undo             map[int][]u8
	undo_new         map[int]bool
	undo_total_pages int
	undo_root_page   int
	undo_free_page   int
	// free is the first free page (see Pager.free_page), or -1 for none.
	free int = -1
	// file_total_pages is the number of pages in the file, which is less than
	// total_pages while new pages haven't been written yet.
	file_total_pages int
}

// new_file_pager requires that the path already exists and has already been
// initialized as a new database. cache_size is the number of pages to keep in
// memory (see ConnectionOptions.cache_size), or 0 for none.
fn new_file_pager(mut file os.File, page_size int, root_page int, cache_size int) !&FilePager {
	file.seek(0, .end) or { return sqlstate_58030('unable seek end: ${err}') }

	file_len := file.tell() or { return sqlstate_58030('unable to get file length: ${err}') }

	return &FilePager{
		file:             file
		page_size:        page_size
		root_page:        root_page
		// The first page is reserved for header information. We do not include
		// this in the pages.
		total_pages:      int((file_len - header_size) / i64(page_size))
		file_total_pages: int((file_len - header_size) / i64(page_size))
		cache_size:       cache_size
	}
}

fn (mut p FilePager) fetch_page(page_number int) !Page {
	return (p.read_page(page_number)!).clone()
}

fn (mut p FilePager) read_page(page_number int) !Page {
	// Any read can fail, even of a page that's in memory, so that a test can
	// fail a read wherever the page is.
	fault_point('read_page')!

	if data := p.dirty[page_number] {
		return page_view(data)
	}

	if data := p.cache[page_number] {
		return page_view(data)
	}

	// The first page is reserved for header information. We do not include this
	// in the pages.
	p.file.seek(int(header_size) + (p.page_size * page_number), .start) or {
		return sqlstate_58030('unable to seek: ${err}')
	}

	// The page is kept in the cache, which outlives the statement (see
	// arena_pause).
	h := arena_pause()
	mut buf := []u8{len: p.page_size}
	p.file.read(mut buf) or {
		arena_resume(h)
		return sqlstate_58030('unable to read from file: ${err}')
	}
	p.cache_page(page_number, buf)
	arena_resume(h)

	return page_view(buf)
}

// cache_page keeps data (that was just read from the file) in the cache,
// removing the oldest page if it's full.
fn (mut p FilePager) cache_page(page_number int, data []u8) {
	if p.cache_size <= 0 {
		return
	}

	if p.cache_order.len < p.cache_size {
		p.cache_order << page_number
	} else {
		$if autofree {
			p.retire_cached(p.cache_order[p.cache_next])
		}
		p.cache.delete(p.cache_order[p.cache_next])
		p.cache_order[p.cache_next] = page_number
		p.cache_next = (p.cache_next + 1) % p.cache_size
	}
	p.cache[page_number] = data
}

// retire_cached keeps the data of a cached page until the next statement (see
// FilePager.retired), so removing it from the cache doesn't free it.
@[manualfree]
fn (mut p FilePager) retire_cached(page_number int) {
	if page_number in p.cache {
		// The array is moved into a header of its own (an array's data can't be
		// freed directly, see array.free), and the one in the map doesn't free
		// it when it's deleted.
		mut data := unsafe { &p.cache[page_number] }
		retired := unsafe { &[]u8(C.malloc(sizeof([]u8))) }
		unsafe { vmemcpy(retired, data, int(sizeof([]u8))) }
		data.flags.set(.nofree)
		p.retired << voidptr(retired)
	}
}

// free_retired frees the pages that were removed from the cache (see
// FilePager.retired).
@[manualfree]
fn (mut p FilePager) free_retired() {
	for ptr in p.retired {
		unsafe {
			mut retired := &[]u8(ptr)
			retired.free()
			C.free(ptr)
		}
	}
	p.retired.clear()
}

// The receiver is a pointer, so that it isn't copied to the heap (and leaked).
fn (page &Page) clone() Page {
	return Page{
		kind: page.kind
		used: page.used
		data: page.data.clone()
	}
}

// page_view is the page in buf (see Page.bytes), which shares its memory, so
// buf must not be changed while the page is used.
fn page_view(buf []u8) Page {
	return Page{
		kind: buf[0]
		used: binary.big_endian_u16_at(buf, 2)
		// unsafe stops V from copying the slice.
		data: unsafe { buf[page_header_size..] }
	}
}

fn (page Page) bytes() []u8 {
	mut b := new_bytes_with_capacity(page_header_size + page.data.len)
	b.write_u8(page.kind)
	b.write_u8(0) // flags
	b.write_u16(page.used)
	// The checksum (u32) and log sequence number (u64) are not used yet.
	b.write_u8s([]u8{len: 12})
	b.write_u8s(page.data)

	return b.bytes()
}

fn (mut p FilePager) store_page(page_number int, page Page) ! {
	// What this changes outlives the statement (see arena_pause).
	arena_h := arena_pause()
	defer {
		arena_resume(arena_h)
	}
	if page_number !in p.undo && page_number !in p.undo_new {
		if data := p.dirty[page_number] {
			// -autofree frees the page in dirty when it's replaced below, so
			// undo needs its own copy.
			$if autofree {
				p.undo[page_number] = data.clone()
			} $else {
				p.undo[page_number] = data
			}
		} else {
			p.undo_new[page_number] = true
		}
	}
	p.dirty[page_number] = page.bytes()
}

// begin must be called at the start of each statement that changes the
// database, so that discard knows what to put back.
fn (mut p FilePager) begin() {
	// What this changes outlives the statement (see arena_pause).
	arena_h := arena_pause()
	defer {
		arena_resume(arena_h)
	}
	p.undo.clear()
	p.undo_new.clear()
	p.free_retired()
	p.undo_total_pages = p.total_pages
	p.undo_root_page = p.root_page
	p.undo_free_page = p.free
}

// discard forgets the changes of the current statement. The pages that earlier
// statements of the transaction changed are kept, see begin.
fn (mut p FilePager) discard() {
	// What this changes outlives the statement (see arena_pause).
	arena_h := arena_pause()
	defer {
		arena_resume(arena_h)
	}
	for page_number, _ in p.undo_new {
		p.dirty.delete(page_number)
	}
	for page_number, data in p.undo {
		p.dirty[page_number] = data
	}
	p.total_pages = p.undo_total_pages
	p.root_page = p.undo_root_page
	p.free = p.undo_free_page
	p.begin()

	// A page that was committed before (see wal_prepare) may be different to the
	// cached one, which was read before it was changed.
	// -autofree also makes free() create a new empty map (see free_map).
	$if autofree {
		unsafe { p.cache.free() }
		p.cache_order.clear()
	} $else {
		p.cache = map[int][]u8{}
		p.cache_order = []int{}
	}
	p.cache_next = 0
}

// committed is called once the dirty pages are in the file, so they're cached
// as they are now.
fn (mut p FilePager) committed() {
	// What this changes outlives the statement (see arena_pause).
	arena_h := arena_pause()
	defer {
		arena_resume(arena_h)
	}
	for page_number, data in p.dirty {
		if page_number in p.cache {
			p.cache[page_number] = data
		} else {
			p.cache_page(page_number, data)
		}
	}
	// The cache has its own copies (with -autofree, clear frees the pages).
	p.dirty.clear()
	p.file_total_pages = p.total_pages
}

// drop_dirty forgets every page that hasn't been written to the file, so it's
// read from the file again, see Storage.drop_kept_pages. They're put back if
// the statement fails, like any other change (see discard).
fn (mut p FilePager) drop_dirty(root_page int, free_page int) {
	// What this changes outlives the statement (see arena_pause).
	arena_h := arena_pause()
	defer {
		arena_resume(arena_h)
	}
	for page_number, data in p.dirty {
		if page_number !in p.undo && page_number !in p.undo_new {
			p.undo[page_number] = data
		}
	}
	p.dirty = map[int][]u8{}
	p.total_pages = p.file_total_pages
	p.root_page = root_page
	p.free = free_page
}

fn (mut p FilePager) total_pages() int {
	return p.total_pages
}

fn (mut p FilePager) append_page(page Page) !int {
	// What this changes outlives the statement (see arena_pause).
	arena_h := arena_pause()
	defer {
		arena_resume(arena_h)
	}
	if p.free >= 0 {
		page_number := p.free
		p.free = next_free_page(p.read_page(page_number)!)
		p.store_page(page_number, page)!
		return page_number
	}

	// The first page is reserved for header information. We do not include this
	// in the pages.
	p.store_page(p.total_pages, page) or { return sqlstate_58030('unable to store page: ${err}') }
	p.total_pages++

	return p.total_pages - 1
}

fn (mut p FilePager) root_page() int {
	return p.root_page
}

fn (mut p FilePager) set_root_page(page_number int) ! {
	p.root_page = page_number
}

fn (mut p FilePager) free_page(page_number int) ! {
	// What this changes outlives the statement (see arena_pause).
	arena_h := arena_pause()
	defer {
		arena_resume(arena_h)
	}
	p.store_page(page_number, new_free_page(p.free, p.page_size))!
	p.free = page_number
}

fn (mut p FilePager) first_free_page() int {
	return p.free
}

// replace_pages only changes the pages in memory. The file is made shorter when
// they're written, see wal_checkpoint.
fn (mut p FilePager) set_first_free_page(page_number int) {
	// What this changes outlives the statement (see arena_pause).
	arena_h := arena_pause()
	defer {
		arena_resume(arena_h)
	}
	p.free = page_number
}

// truncate only changes the number of pages: the pages past it aren't written
// (see wal_prepare), and the file is cut to it by wal_checkpoint. A page that's
// cached past the end is forgotten, so a page added there later is read again.
fn (mut p FilePager) truncate(total_pages int) {
	// What this changes outlives the statement (see arena_pause).
	arena_h := arena_pause()
	defer {
		arena_resume(arena_h)
	}
	for page_number, _ in p.cache {
		if page_number >= total_pages {
			p.cache.delete(page_number)
		}
	}
	p.total_pages = total_pages
}

fn (mut p FilePager) replace_pages(pages []Page, root int) ! {
	// What this changes outlives the statement (see arena_pause).
	arena_h := arena_pause()
	defer {
		arena_resume(arena_h)
	}
	for i, page in pages {
		p.store_page(i, page)!
	}
	p.total_pages = pages.len
	p.root_page = root
	p.free = -1
}

// new_free_page is a kind_free page that's followed on the free list by next
// (-1 for none).
fn new_free_page(next int, page_size int) Page {
	mut page := new_page(kind_free, page_size)
	binary.big_endian_put_u32(mut page.data, u32(next))

	return page
}

// next_free_page is the page after a free page on the free list, or -1.
fn next_free_page(page Page) int {
	return int(i32(binary.big_endian_u32(page.data)))
}
