// storage.v acts as the gateway for common operations against the raw objects
// on from the pager, such as fetching tables and rows.
//
// Storage is maintained over individual operations on the file because it
// caches the schema.

module vsql

import os

struct Storage {
mut:
	header Header
	// btree is replaced for each operation (because it needs a new pager for
	// each operation).
	btree Btree
	// We keep the table definitions in memory because they are needed for most
	// operations (including read and writing rows). All tables must be loaded
	// when the database is opened.
	tables map[string]Table
	// file is opened, flushed and closed with each operation against the file.
	file os.File
}

fn new_storage() Storage {
	return Storage{}
}

fn (mut f Storage) open(path string) ? {
	f.file = os.open_file(path, 'r+') ?

	header := read_header(mut f.file) ?
	defer {
		f.header = header
	}

	f.btree = new_btree(new_file_pager(mut f.file, header.page_size, header.root_page) ?,
		header.page_size)

	// Avoid reloading the schema if it hasn't change.
	if header.schema_version == f.header.schema_version {
		return
	}

	f.tables = map[string]Table{}

	for object in f.btree.new_range_iterator('T'.bytes(), 'U'.bytes()) {
		table := new_table_from_bytes(object.value)
		f.tables[table.name] = table
	}
}

fn (mut f Storage) schema_changed() {
	// We don't need to read the header again because write operations on a file
	// are exclusive so the version (and the header itself) we already have can
	// be incremented.
	f.header.schema_version++
}

fn (mut f Storage) close() ? {
	// Before closing the connection we always write back the page header in
	// case the schema_version or root_page have changed.
	//
	// TODO(elliotchance): We should be smarter about only writing this when we
	//  need to.
	f.header.root_page = f.btree.pager.root_page()
	write_header(mut f.file, f.header) ?

	f.file.flush()
	f.file.close()
}

fn (mut f Storage) create_table(table_name string, columns []Column, primary_key []string) ? {
	table := Table{table_name, columns, primary_key}

	obj := new_page_object('T$table_name'.bytes(), 0, 0, table.bytes())
	f.btree.add(obj) ?

	f.tables[table_name] = table
	f.schema_changed()
}

fn (mut f Storage) delete_table(table_name string) ? {
	// TODO(elliotchance): This is wrong because we should expire (not delete)
	//  and the tid needs to be maintained on the row.
	f.btree.remove('T$table_name'.bytes(), 0) ?

	f.tables.delete(table_name)
	f.schema_changed()
}

fn (mut f Storage) delete_row(table_name string, mut row Row) ? {
	// TODO(elliotchance): This is wrong because we should expire (not delete)
	//  and the tid needs to be maintained on the row.
	f.btree.remove(row.object_key(f.tables[table_name]) ?, 0) ?
}

fn (mut f Storage) write_row(mut r Row, t Table) ? {
	// TODO(elliotchance): The real tid needs to be provided.
	obj := new_page_object(r.object_key(t) ?, 0, 0, r.bytes(t))
	f.btree.add(obj) ?
}

fn (mut f Storage) read_rows(table_name string, offset int) ?[]Row {
	mut rows := []Row{}

	// ';' = ':' + 1
	for object in f.btree.new_range_iterator('R$table_name:'.bytes(), 'R$table_name;'.bytes()) {
		rows << new_row_from_bytes(f.tables[table_name], object.value)
	}

	if offset >= rows.len {
		return []Row{}
	}

	return rows[offset..]
}
