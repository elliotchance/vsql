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
}

struct MemoryPager {
mut:
	// root_page is the starting page for a traversal. The root page may change
	// as balancing happens on the tree.
	root_page int
	pages     []Page
}

fn new_memory_pager() &MemoryPager {
	return &MemoryPager{}
}

fn (mut p MemoryPager) fetch_page(page_number int) !Page {
	return p.pages[page_number]
}

fn (mut p MemoryPager) store_page(page_number int, page Page) ! {
	p.pages[page_number] = page
}

fn (mut p MemoryPager) total_pages() int {
	return p.pages.len
}

fn (mut p MemoryPager) append_page(page Page) !int {
	p.pages << page

	return p.pages.len - 1
}

fn (mut p MemoryPager) truncate_all() ! {
	p.pages = []Page{}
}

fn (mut p MemoryPager) truncate_last_page() ! {
	p.pages = p.pages[..p.pages.len - 1]
}

fn (mut p MemoryPager) root_page() int {
	return p.root_page
}

fn (mut p MemoryPager) set_root_page(page_number int) ! {
	p.root_page = page_number
}

struct FilePager {
	page_size int
mut:
	file        os.File
	total_pages int
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
		file: file
		page_size: page_size
		root_page: root_page
		// The first page is reserved for header information. We do not include
		// this in the pages.
		total_pages: int((file_len - sizeof(Header)) / i64(page_size))
	}
}

fn (mut p FilePager) fetch_page(page_number int) !Page {
	// The first page is reserved for header information. We do not include this
	// in the pages.
	p.file.seek(int(sizeof(Header)) + (p.page_size * page_number), .start) or {
		return error('unable to seek: ${err}')
	}

	mut buf := []u8{len: p.page_size}
	p.file.read(mut buf) or { return error('unable to read from file: ${err}') }

	mut b := new_bytes(buf)

	return Page{
		kind: b.read_u8()
		used: b.read_u16()
		data: buf[page_header_size..]
	}
}

fn (mut p FilePager) store_page(page_number int, page Page) ! {
	// The first page is reserved for header information. We do not include this
	// in the pages.
	p.file.seek(int(sizeof(Header)) + (p.page_size * page_number), .start) or {
		return error('unable to seek: ${err}')
	}

	mut b := new_empty_bytes()
	b.write_u8(page.kind)
	b.write_u16(page.used)
	b.write_u8s(page.data)

	p.file.write(b.bytes()) or { return error('unable to write to file: ${err}') }
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
