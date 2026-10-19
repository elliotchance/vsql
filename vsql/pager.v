// pager.v contains the interface and implementation for a pager that stores
// pages in memory or on disk.
//
// A new pager is created for each operation on the file. See btree.v.
//
// See https://github.com/elliotchance/vsql/issues/45.

module vsql

import os

interface Pager {
mut:
	fetch_page(page_number int) !Page
	store_page(page_number int, page Page) !
	append_page(page Page) !int
	truncate_all() !
	truncate_last_page() !
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

// Pages are copied in and out of the pager because the B-tree changes the
// data of a page in place before storing it.
fn (mut p MemoryPager) fetch_page(page_number int) !Page {
	if page := p.dirty[page_number] {
		return page.clone()
	}

	return p.pages[page_number].clone()
}

fn (mut p MemoryPager) store_page(page_number int, page Page) ! {
	p.dirty[page_number] = page.clone()
}

fn (mut p MemoryPager) total_pages() int {
	return p.total
}

fn (mut p MemoryPager) append_page(page Page) !int {
	p.dirty[p.total] = page.clone()
	p.total++

	return p.total - 1
}

fn (mut p MemoryPager) truncate_all() ! {
	p.total = 0
}

fn (mut p MemoryPager) truncate_last_page() ! {
	p.total--
}

fn (mut p MemoryPager) root_page() int {
	return p.root_page
}

fn (mut p MemoryPager) set_root_page(page_number int) ! {
	p.root_page = page_number
}

// commit keeps the pages changed by the current statement.
fn (mut p MemoryPager) commit() {
	mut pages := []Page{cap: p.total}
	for i in 0 .. p.total {
		pages << p.dirty[i] or { p.pages[i] }
	}

	p.pages = pages
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
}

// new_file_pager requires that the path already exists and has already been
// initialized as a new database.
fn new_file_pager(mut file os.File, page_size int, root_page int) !&FilePager {
	file.seek(0, .end) or { return error('unable seek end: ${err}') }

	file_len := file.tell() or { return error('unable to get file length: ${err}') }

	return &FilePager{
		file:        file
		page_size:   page_size
		root_page:   root_page
		// The first page is reserved for header information. We do not include
		// this in the pages.
		total_pages: int((file_len - header_size) / i64(page_size))
	}
}

fn (mut p FilePager) fetch_page(page_number int) !Page {
	if data := p.dirty[page_number] {
		return new_page_from_bytes(data)
	}

	// The first page is reserved for header information. We do not include this
	// in the pages.
	p.file.seek(int(header_size) + (p.page_size * page_number), .start) or {
		return error('unable to seek: ${err}')
	}

	mut buf := []u8{len: p.page_size}
	p.file.read(mut buf) or { return error('unable to read from file: ${err}') }

	return new_page_from_bytes(buf)
}

fn (page Page) clone() Page {
	return Page{
		kind: page.kind
		used: page.used
		data: page.data.clone()
	}
}

fn new_page_from_bytes(buf []u8) Page {
	mut b := new_bytes(buf)
	kind := b.read_u8()
	b.read_u8() // flags

	return Page{
		kind: kind
		used: b.read_u16()
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
}

fn (mut p FilePager) total_pages() int {
	return p.total_pages
}

fn (mut p FilePager) append_page(page Page) !int {
	// The first page is reserved for header information. We do not include this
	// in the pages.
	p.store_page(p.total_pages, page) or { return error('unable to store page: ${err}') }
	p.total_pages++

	return p.total_pages - 1
}

fn (mut p FilePager) truncate_all() ! {
	p.total_pages = 0
}

fn (mut p FilePager) truncate_last_page() ! {
	p.total_pages--
}

fn (mut p FilePager) root_page() int {
	return p.root_page
}

fn (mut p FilePager) set_root_page(page_number int) ! {
	p.root_page = page_number
}
