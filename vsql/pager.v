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
// must not be changed after that.
interface Pager {
mut:
	fetch_page(page_number int) !Page
	store_page(page_number int, page Page) !
	append_page(page Page) !int
	total_pages() int
	root_page() int
	set_root_page(page_number int) !
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
}

fn new_memory_pager() &MemoryPager {
	return &MemoryPager{}
}

// A page is copied by fetch_page because the B-tree changes the data of a page
// in place before storing it. It's not copied again by store_page and
// append_page, because the page that's stored isn't changed after that.
fn (mut p MemoryPager) fetch_page(page_number int) !Page {
	if page := p.dirty[page_number] {
		return page.clone()
	}

	return p.pages[page_number].clone()
}

fn (mut p MemoryPager) store_page(page_number int, page Page) ! {
	p.dirty[page_number] = page
}

fn (mut p MemoryPager) total_pages() int {
	return p.total
}

fn (mut p MemoryPager) append_page(page Page) !int {
	p.dirty[p.total] = page
	p.total++

	return p.total - 1
}

fn (mut p MemoryPager) root_page() int {
	return p.root_page
}

fn (mut p MemoryPager) set_root_page(page_number int) ! {
	p.root_page = page_number
}

// commit keeps the pages changed by the current statement.
fn (mut p MemoryPager) commit() {
	// Only the changed pages are replaced, rather than copying all of them,
	// since a page that's stored is never changed in place.
	for p.pages.len < p.total {
		p.pages << Page{}
	}
	for i, page in p.dirty {
		p.pages[i] = page
	}

	p.dirty = map[int]Page{}
	p.saved_root_page = p.root_page
}

fn (mut p MemoryPager) discard() {
	p.dirty = map[int]Page{}
	p.total = p.pages.len
	p.root_page = p.saved_root_page
}

struct FilePager {
	page_size int
mut:
	file        os.File
	total_pages int
	// dirty contains the pages that have been changed, which are only written
	// to the file at the end of the statement, see wal_commit.
	dirty map[int][]u8
	// root_page is the starting page for a traversal. The root page may change
	// as balancing happens on the tree.
	root_page int
	// cache keeps up to cache_size pages that were read from the file, so that
	// reading them again doesn't read the file. The pager is only used for one
	// statement, while the file is locked, so the file can't change underneath
	// it. cache_order is the page numbers in the order they were added (a ring
	// starting at cache_next) so that the oldest one is removed when it's full.
	cache_size  int
	cache       map[int][]u8
	cache_order []int
	cache_next  int
}

// new_file_pager requires that the path already exists and has already been
// initialized as a new database. cache_size is the number of pages to keep in
// memory (see ConnectionOptions.cache_size), or 0 for none.
fn new_file_pager(mut file os.File, page_size int, root_page int, cache_size int) !&FilePager {
	file.seek(0, .end) or { return sqlstate_58030('unable seek end: ${err}') }

	file_len := file.tell() or { return sqlstate_58030('unable to get file length: ${err}') }

	return &FilePager{
		file:        file
		page_size:   page_size
		root_page:   root_page
		// The first page is reserved for header information. We do not include
		// this in the pages.
		total_pages: int((file_len - header_size) / i64(page_size))
		cache_size:  cache_size
	}
}

fn (mut p FilePager) fetch_page(page_number int) !Page {
	if data := p.dirty[page_number] {
		return new_page_from_bytes(data)
	}

	// new_page_from_bytes copies the data, so a cached page can't be changed.
	if data := p.cache[page_number] {
		return new_page_from_bytes(data)
	}

	fault_point('read_page')!

	// The first page is reserved for header information. We do not include this
	// in the pages.
	p.file.seek(int(header_size) + (p.page_size * page_number), .start) or {
		return sqlstate_58030('unable to seek: ${err}')
	}

	mut buf := []u8{len: p.page_size}
	p.file.read(mut buf) or { return sqlstate_58030('unable to read from file: ${err}') }
	p.cache_page(page_number, buf)

	return new_page_from_bytes(buf)
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
		p.cache.delete(p.cache_order[p.cache_next])
		p.cache_order[p.cache_next] = page_number
		p.cache_next = (p.cache_next + 1) % p.cache_size
	}
	p.cache[page_number] = data
}

fn (page Page) clone() Page {
	return Page{
		kind: page.kind
		used: page.used
		data: page.data.clone()
	}
}

fn new_page_from_bytes(buf []u8) Page {
	return Page{
		kind: buf[0]
		used: binary.big_endian_u16_at(buf, 2)
		data: buf[page_header_size..].clone()
	}
}

fn (page Page) bytes() []u8 {
	mut b := new_empty_bytes()
	b.write_u8(page.kind)
	b.write_u8(0) // flags
	b.write_u16(page.used)
	// The checksum (u32) and log sequence number (u64) are not used yet.
	b.write_u8s([]u8{len: 12})
	b.write_u8s(page.data)

	return b.bytes()
}

fn (mut p FilePager) store_page(page_number int, page Page) ! {
	p.dirty[page_number] = page.bytes()
}

fn (mut p FilePager) discard() {
	p.dirty = map[int][]u8{}

	// A page that was committed before (see wal_commit) may be different to the
	// cached one, which was read before it was changed.
	p.cache = map[int][]u8{}
	p.cache_order = []int{}
	p.cache_next = 0
}

fn (mut p FilePager) total_pages() int {
	return p.total_pages
}

fn (mut p FilePager) append_page(page Page) !int {
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
