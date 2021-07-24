// storage.v handles storing all tables and records within a single file.
//
// This is extremely crude and inefficient. It'll do for an initial alpha.
// Opening an existing database requires reading the entire file to prepare the
// table definitions and any table scan also requires reading the entire file.
// Although, INSERTs, DELETEs and UPDATEs are O(1).

module vsql

import os

struct FileStorage {
	path string
mut:
	version i8 // should be = 1
	f       os.File
	tables  map[string]Table
	pos     u32
	max_pos u32
}

type FileStorageObject = Row | Table

struct FileStorageNextObject {
	is_eof   bool
	category int
	obj      FileStorageObject
}

fn new_file_storage(path string) ?FileStorage {
	// If the file doesn't exist we initialize it and reopen it.
	if !os.exists(path) {
		mut tmpf := os.create(path) ?
		file_version := i8(1)
		tmpf.write_raw(file_version) ?
		tmpf.close()
	}

	// Now open the prepared or existing file and read all of the table
	// definitions.
	mut f := FileStorage{
		path: path
		f: os.open_file(path, 'r+') ?
	}

	f.version = f.read<i8>() ?

	for {
		next := f.read_object() ?
		if next.is_eof {
			break
		}

		if next.obj is Table {
			f.tables[next.obj.name] = next.obj
		}
	}

	return f
}

fn (mut f FileStorage) read<T>() ?T {
	defer {
		f.pos += sizeof(T)

		if f.pos > f.max_pos {
			f.max_pos = f.pos
		}
	}
	return f.f.read_raw_at<T>(f.pos)
}

fn (mut f FileStorage) write<T>(x T) ? {
	f.f.write_raw_at<T>(x, f.pos) ?
	f.pos += sizeof(T)

	if f.pos > f.max_pos {
		f.max_pos = f.pos
	}
}

fn (mut f FileStorage) close() {
	f.f.close()
}

fn (mut f FileStorage) write_value(v Value) ? {
	f.write<SQLType>(v.typ.typ) ?

	match v.typ.typ {
		.is_boolean, .is_float, .is_bigint, .is_integer, .is_real, .is_smallint {
			f.write<f64>(v.f64_value) ?
		}
		.is_varchar, .is_character {
			f.write<int>(v.string_value.len) ?
			for b in v.string_value.bytes() {
				f.write<byte>(b) ?
			}
		}
	}
}

fn (mut f FileStorage) read_value() ?Value {
	typ := f.read<SQLType>() ?

	return match typ {
		.is_boolean, .is_bigint, .is_float, .is_real, .is_smallint, .is_integer {
			Value{
				typ: Type{typ, 0}
				f64_value: f.read<f64>() ?
			}
		}
		.is_varchar, .is_character {
			len := f.read<int>() ?
			mut buf := []byte{len: len}
			f.f.read_from(f.pos, mut buf) ?
			f.pos += u32(len)

			Value{
				typ: Type{typ, 0}
				string_value: string(buf)
			}
		}
	}
}

fn sizeof_value(value Value) int {
	return int(sizeof(SQLType) + match value.typ.typ {
		.is_boolean, .is_float, .is_integer, .is_bigint, .is_smallint, .is_real { sizeof(f64) }
		.is_varchar, .is_character { sizeof(int) + u32(value.string_value.len) }
	})
}

fn (mut f FileStorage) write_object(category int, values []Value) ? {
	// Always ensure we append to the file.
	f.pos = f.max_pos

	mut data_len := int(0)
	for value in values {
		data_len += sizeof_value(value)
	}

	f.write(data_len) ?
	f.write(category) ?

	for value in values {
		f.write_value(value) ?
	}
}

fn (mut f FileStorage) read_object() ?FileStorageNextObject {
	data_len := f.read<int>() or {
		// TODO(elliotchance): I'm not sure what the correcy way to detect EOF
		//  is, but let's assume this error means the end.
		f.pos -= sizeof(int)
		f.max_pos -= sizeof(int)
		return FileStorageNextObject{
			is_eof: true
		}
	}
	offset := f.pos
	category := f.read<int>() ?

	mut values := []Value{}
	for i := 0; i < data_len; {
		value := f.read_value() ?
		values << value
		i += sizeof_value(value)
	}

	if category == 0 {
		return FileStorageNextObject{
			category: category
		}
	}

	if category >= 10000 {
		mut table := Table{}
		for _, t in f.tables {
			if t.index == category - 10000 {
				table = t
			}
		}

		mut i := 0
		mut row := Row{
			offset: offset
			data: map[string]Value{}
		}
		for column in table.columns {
			row.data[column.name] = values[i]
			i++
		}

		return FileStorageNextObject{
			category: category
			obj: row
		}
	}

	mut columns := []Column{cap: (values.len - 2) / 2}
	for i := 2; i < values.len; i += 2 {
		columns << Column{
			name: values[i].string_value
			typ: new_type(values[i + 1].string_value, 0)
		}
	}

	return FileStorageNextObject{
		category: category
		obj: Table{
			offset: offset
			index: int(values[0].f64_value)
			name: values[1].string_value
			columns: columns
		}
	}
}

fn (mut f FileStorage) create_table(table_name string, columns []Column) ? {
	mut values := []Value{}
	index := f.tables.len + 1
	offset := f.pos

	// If index is 0, the table is deleletd
	values << new_float_value(index)
	values << new_varchar_value(table_name, 0)

	for column in columns {
		values << new_varchar_value(column.name, 0)
		values << new_varchar_value(column.typ.str(), 0)
	}

	f.write_object(1, values) ?

	f.tables[table_name] = Table{offset, index, table_name, columns}
}

fn (mut f FileStorage) delete_table(table_name string) ? {
	f.pos = f.tables[table_name].offset

	// If index is 0, the table is deleted
	f.write_value(new_float_value(0)) ?

	f.tables.delete(table_name)
}

fn (mut f FileStorage) delete_row(row Row) ? {
	f.pos = row.offset
	zero := 0
	f.write<int>(zero) ?
}

fn (mut f FileStorage) write_row(r Row, t Table) ? {
	mut values := []Value{}
	for column in t.columns {
		values << r.data[column.name]
	}
	f.write_object(10000 + t.index, values) ?
}

fn (mut f FileStorage) read_rows(table_index int) ?[]Row {
	f.pos = 1

	mut rows := []Row{}
	for {
		next := f.read_object() ?
		if next.is_eof {
			break
		}

		if next.obj is Row && next.category - 10000 == table_index {
			rows << next.obj
		}
	}

	return rows
}
