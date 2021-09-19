// table.v is the definition of a table (columns names and types).

module vsql

struct Column {
	name     string
	typ      Type
	not_null bool
}

struct Table {
mut:
	name    string
	columns []Column
	// If the table has a PRIMARY KEY defined the column (or columns) will be
	// defined here.
	primary_key []string
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

	b.write_string1(t.name)
	b.write_string1_list(t.primary_key)

	for col in t.columns {
		b.write_string1(col.name)
		b.write_byte(col.typ.number())
		b.write_bool(col.not_null)
		b.write_i16(0) // size
		b.write_i16(0) // precision
	}

	return b.bytes()
}

fn new_table_from_bytes(data []byte) Table {
	mut b := new_bytes(data)

	table_name := b.read_string1()
	primary_key := b.read_string1_list()

	mut columns := []Column{}
	for b.has_more() {
		column_name := b.read_string1()
		column_type := b.read_byte()
		is_not_null := b.read_bool()
		b.read_i16() // size
		b.read_i16() // precision

		columns << Column{column_name, type_from_number(column_type), is_not_null}
	}

	return Table{table_name, columns, primary_key}
}

// A TableOperation requires that up to rows in the table be read. The number of
// rows read may be limited and/or an offset (rows to skip) provided.
struct TableOperation {
	table_name string
	table      Table
	offset     Expr // NoExpr for not set
	params     map[string]Value
	conn       Connection
mut:
	storage Storage
}

fn (o TableOperation) str() string {
	mut s := 'TABLE $o.table_name'

	// TODO(elliotchance): It would be nice to correctly pluralize ROW/ROWS, but
	//  the number may be a parameter we would have to resolve.

	if o.offset !is NoExpr {
		s += ' OFFSET ${o.offset.pstr(o.params)} ROWS'
	}

	return s
}

fn (mut o TableOperation) execute(_ []Row) ?[]Row {
	mut offset := 0
	if o.offset !is NoExpr {
		offset = int((eval_as_value(o.conn, Row{}, o.offset, o.params) ?).f64_value)
	}

	return o.storage.read_rows(o.table_name, offset)
}

// A LimitOperation stops after a specified number of rows have been received.
struct LimitOperation {
	fetch  Expr
	params map[string]Value
	conn   Connection
}

fn (o LimitOperation) str() string {
	return 'FETCH FIRST ${o.fetch.pstr(o.params)} ROWS ONLY'
}

fn (o LimitOperation) execute(rows []Row) ?[]Row {
	mut fetch := int((eval_as_value(o.conn, Row{}, o.fetch, o.params) ?).f64_value)

	if fetch < rows.len {
		return rows[..fetch]
	}

	return rows
}
