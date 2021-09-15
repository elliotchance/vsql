// storage.v acts as the gateway for common operations against the raw objects
// on from the pager, such as fetching tables and rows.

module vsql

import os

struct Storage {
mut:
	version i8
	btree   Btree
	// We keep the table definitions in memory because they are needed for most
	// operations (including read and writing rows). All tables must be loaded
	// when the database is opened.
	tables map[string]Table
}

fn new_file_storage(path string) ?Storage {
	// This is a rudimentary way to ensure that small changes to storage.v are
	// compatible as things change so rapidly. Sorry if you had a database in a
	// previous version, you'll need to recreate it.
	current_version := i8(4)

	page_size := 4096

	// If the file doesn't exist we initialize it and reopen it.
	if !os.exists(path) {
		mut tmpf := os.create(path) ?
		tmpf.write_raw(current_version) ?
		tmpf.write([]byte{len: page_size - 1}) ?
		tmpf.close()
	}

	// Now open the prepared or existing file and read all of the table
	// definitions.
	mut pager := new_file_pager(path, page_size) ?
	mut f := Storage{
		btree: new_btree(pager)
	}

	// TODO(elliotchance): Move this to a read/write header. See
	//  https://github.com/elliotchance/vsql/issues/42.
	mut version := []byte{len: page_size}
	pager.file.seek(0, .start) ?
	pager.file.read(mut version) ?
	f.version = i8(version[0])

	// Check file version compatibility.
	if f.version != current_version {
		return error('need version $current_version but database is $f.version')
	}

	for object in f.btree.new_range_iterator('T'.bytes(), 'U'.bytes()) {
		table := new_table_from_bytes(object.value)
		f.tables[table.name] = table
	}

	return f
}

fn (mut f Storage) close() {
	f.btree.close()
}

fn (mut f Storage) create_table(table_name string, columns []Column) ? {
	table := Table{table_name, columns}

	obj := new_page_object('T$table_name'.bytes(), table.bytes())
	f.btree.add(obj) ?

	f.tables[table_name] = table
}

fn (mut f Storage) delete_table(table_name string) ? {
	f.btree.remove('T$table_name'.bytes()) ?
	f.tables.delete(table_name)
}

fn (mut f Storage) delete_row(table_name string, row Row) ? {
	f.btree.remove('R$table_name:$row.id'.bytes()) ?
}

fn (mut f Storage) write_row(r Row, t Table) ? {
	obj := new_page_object('R$t.name:$r.id'.bytes(), r.bytes(t))
	f.btree.add(obj) ?
}

fn (mut f Storage) read_rows(table_name string, offset int) ?[]Row {
	mut rows := []Row{}
	for object in f.btree.new_range_iterator('R$table_name:'.bytes(), 'R$table_name:Z'.bytes()) {
		rows << new_row_from_bytes(f.tables[table_name], object.value)
	}

	if offset >= rows.len {
		return []Row{}
	}

	return rows[offset..]
}
