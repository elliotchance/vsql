// header.v contains the logic to read and write the page header of a file.

module vsql

import os

// header_size is the number of bytes reserved for the header at the start of
// the file. The header is always this size, regardless of the page size.
const header_size = 4096

// header_magic identifies a vsql database file. It's always the first 8 bytes
// of the file. The \r\n, \x1a and \n catch files that have been damaged by
// line ending conversion or read as text.
const header_magic = 'vsql\r\n\x1a\n'.bytes()

// current_version is the version of the file format. It's incremented whenever
// the format changes in a way that older versions cannot read. Sorry if you had
// a database in a previous version, you'll need to recreate it.
const current_version = u16(14)

// The Header contains important metadata about the database and always occupies
// the first header_size bytes of the database. It's encoded by write_header and
// decoded by read_header, see "File Format" in the docs for the layout.
struct Header {
	// version must be current_version.
	version u16
mut:
	// The schema_version is incremented whenever there is a change to the
	// schema, such as creating or removing a table. This is an optimisation
	// that prevents connections (even if there is only one) from needing to
	// reread the schema if it has not changed.
	schema_version int
	// The page_size is always set to 4kb (4096 bytes). It's possible we can
	// make this configurable in the future, but for now changing it may break
	// stuff.
	page_size int
	// The root_page is the virtual page number (not including the header) of
	// the page that is the top of the B-tree. This may move around (potentially
	// anywhere in the file) as the root page needs to be divided or merged -
	// although this should be quite infrequent.
	root_page int
	// The transaction_id is the next transaction ID. This will be incremented
	// immediately after being accessed. The transaction ID starts at 2 because
	// there are two special values reserved:
	//
	//   0 indicates not set - specifically for expiries.
	//   1 indicates the frozen transaction.
	//
	// TODO(elliotchance): Is there a way to avoid incrementing this for read
	//  only transactions?
	transaction_id int
	// The row_id is the last row ID that was issued for a row in a table without
	// a PRIMARY KEY. Row IDs are never reused, even if the transaction that
	// used them is rolled back.
	row_id u64
	// active_transaction_ids maintains the transactions that are currently
	// in-flight.
	active_transaction_ids TransactionIDs
}

fn new_header(page_size int) Header {
	return Header{
		// Set all default here - even if they are zero - to be explicit.
		version:        current_version
		schema_version: 0
		page_size:      page_size
		root_page:      0
		// 2 is a reserved number for freezing rows, but the transaction_is is
		// always incremented before returning the next value.
		transaction_id: 2
		row_id:         0
	}
}

fn init_database_file(path string, page_size int) ! {
	header := new_header(page_size)

	mut tmpf := os.create(path) or { return error('cannot create file ${path}: ${err}') }
	write_header(mut tmpf, header)!
	tmpf.close()
}

fn (h Header) bytes() []u8 {
	mut b := new_empty_bytes()
	b.write_u8s(header_magic)
	b.write_u16(h.version)
	b.write_i32(h.schema_version)
	b.write_i32(h.page_size)
	b.write_i32(h.root_page)
	b.write_i32(h.transaction_id)
	b.write_u64(h.row_id)
	for tid in h.active_transaction_ids.tids {
		b.write_i32(tid)
	}

	// The remaining space is reserved and always zero.
	b.write_u8s([]u8{len: header_size - b.pos()})

	return b.bytes()
}

fn new_header_from_bytes(data []u8) !Header {
	if data.len < header_size || data[..header_magic.len] != header_magic {
		return error('not a vsql database, or it was created by a version of vsql before the file format had a magic number')
	}

	mut b := new_bytes(data)
	b.set_pos(header_magic.len)

	version := b.read_u16()
	if version != current_version {
		return error('need version ${current_version} but database is ${version}')
	}

	mut header := Header{
		version:        version
		schema_version: b.read_i32()
		page_size:      b.read_i32()
		root_page:      b.read_i32()
		transaction_id: b.read_i32()
		row_id:         b.read_u64()
	}
	for i in 0 .. header.active_transaction_ids.tids.len {
		header.active_transaction_ids.tids[i] = b.read_i32()
	}

	if header.page_size <= page_header_size {
		return error('invalid page size ${header.page_size}')
	}

	return header
}

fn read_header(mut file os.File) !Header {
	file.seek(0, .start) or { return error('unable seek start: ${err}') }

	mut data := []u8{len: header_size}
	n := file.read(mut data) or { 0 }

	return new_header_from_bytes(data[..n])
}

fn write_header(mut file os.File, header Header) ! {
	file.seek(0, .start) or { return error('unable seek start: ${err}') }

	file.write(header.bytes()) or { return error('unable to write header: ${err}') }
}
