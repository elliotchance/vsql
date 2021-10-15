// header.v contains the logic to read and write the page header of a file.

module vsql

import os

// This is a rudimentary way to ensure that small changes to storage.v are
// compatible as things change so rapidly. Sorry if you had a database in a
// previous version, you'll need to recreate it.
const current_version = i8(6)

// The Header contains important metadata about the database and always occupies
// the first page of the database.
struct Header {
	// version must be current_version.
	version i8
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
}

fn new_header(page_size int) Header {
	return Header{
		// Set all default here - even if they are zero - to be explicit.
		version: vsql.current_version
		schema_version: 0
		page_size: page_size
		root_page: 0
	}
}

fn init_database_file(path string, page_size int) ? {
	header := new_header(page_size)

	mut tmpf := os.create(path) ?
	write_header(mut tmpf, header) ?
	tmpf.write([]byte{len: page_size - int(sizeof(header))}) ?
	tmpf.close()
}

fn read_header(mut file os.File) ?Header {
	file.seek(0, .start) ?
	header := file.read_raw<Header>() ?

	// Check file version compatibility.
	if header.version != vsql.current_version {
		return error('need version $vsql.current_version but database is $header.version')
	}

	return header
}

fn write_header(mut file os.File, header Header) ? {
	file.seek(0, .start) ?
	file.write_raw(header) ?
}
