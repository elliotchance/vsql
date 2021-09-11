// table.v is the definition of a table (columns names and types).

module vsql

struct Column {
	name     string
	typ      Type
	not_null bool
}

struct Table {
mut:
	offset  u32
	index   int
	name    string
	columns []Column
}

fn (t Table) column_names() []string {
	mut names := []string{}
	for col in t.columns {
		names << col.name
	}

	return names
}

fn (t Table) column(name string) ?Column {
	for col in t.columns {
		if name == col.name {
			return col
		}
	}

	return sqlstate_42703(name) // column does not exist
}

fn (t Table) bytes() []byte {
	mut b := new_bytes([]byte{})

	b.write_int(t.index)
	b.write_string1(t.name)

	for col in t.columns {
		b.write_string1(col.name)
		b.write_byte(col.typ.number())
		b.write_bool(col.not_null)
		b.write_i16(0) // size
		b.write_i16(0) // precision
	}

	return b.bytes()
}

fn new_table_from_bytes(data []byte, offset u32) Table {
	mut b := new_bytes(data)

	index := b.read_int()
	table_name := b.read_string1()

	mut columns := []Column{}
	for b.has_more() {
		column_name := b.read_string1()
		column_type := b.read_byte()
		is_not_null := b.read_bool()
		b.read_i16() // size
		b.read_i16() // precision

		columns << Column{column_name, type_from_number(column_type), is_not_null}
	}

	return Table{offset, index, table_name, columns}
}
