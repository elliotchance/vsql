// storage.v acts as the gateway for common operations against the raw objects
// on from the pager, such as fetching tables and rows.

module vsql

struct Storage {
mut:
	version i8
	// schema_version determines if the schema needs to be reloaded.
	schema_version int
	btree          Btree
	// We keep the table definitions in memory because they are needed for most
	// operations (including read and writing rows). All tables must be loaded
	// when the database is opened.
	tables map[string]Table
}

fn new_storage(pager Pager) ?Storage {
	mut f := Storage{
		btree: new_btree(pager)
	}

	return f
}

fn (mut f Storage) load_schema() ? {
	current_schema_version := f.btree.pager.schema_version() ?
	if current_schema_version == f.schema_version {
		return
	}

	f.tables = map[string]Table{}

	for object in f.btree.new_range_iterator('T'.bytes(), 'U'.bytes()) {
		table := new_table_from_bytes(object.value)
		f.tables[table.name] = table
	}

	f.schema_version = current_schema_version
}

fn (mut f Storage) close() {
	f.btree.close()
}

fn (mut f Storage) flush() {
	f.btree.flush()
}

fn (mut f Storage) create_table(table_name string, columns []Column, primary_key []string) ? {
	table := Table{table_name, columns, primary_key}

	obj := new_page_object('T$table_name'.bytes(), table.bytes())
	f.btree.add(obj) ?

	f.tables[table_name] = table
	f.btree.pager.schema_changed() ?
}

fn (mut f Storage) delete_table(table_name string) ? {
	f.btree.remove('T$table_name'.bytes()) ?
	f.tables.delete(table_name)
	f.btree.pager.schema_changed() ?
}

fn (mut f Storage) delete_row(table_name string, mut row Row) ? {
	f.btree.remove(row.object_key(f.tables[table_name]) ?) ?
}

fn (mut f Storage) write_row(mut r Row, t Table) ? {
	obj := new_page_object(r.object_key(t) ?, r.bytes(t))
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
