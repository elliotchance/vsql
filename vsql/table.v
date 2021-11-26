// table.v is the definition of a table (columns names and types).

module vsql

struct Column {
pub:
	name     string
	typ      Type
	not_null bool
}

fn (c Column) str() string {
	return c.name
}

type Columns = []Column

fn (c Columns) str() string {
	mut s := []string{}
	for col in c {
		mut f := '$col.name $col.typ'
		if col.not_null {
			f += ' NOT NULL'
		}
		s << f
	}

	return s.join(', ')
}

struct Table {
mut:
	name    string
	columns Columns
	// If the table has a PRIMARY KEY defined the column (or columns) will be
	// defined here.
	primary_key []string
	// The tid is the transaction ID that created this table.
	tid int
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

fn new_table_from_bytes(data []byte, tid int) Table {
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

	return Table{table_name, columns, primary_key, tid}
}

// A TableOperation requires that up to rows in the table be read. The number of
// rows read may be limited and/or an offset (rows to skip) provided.
struct TableOperation {
	table_name string
	// table_is_subplan is true if the table_name should be executed from the
	// subplans instead of a real table.
	table_is_subplan bool
	table            Table
	params           map[string]Value
	conn             &Connection
	columns          Columns
	select_list      SelectList
mut:
	subplans map[string]Plan
	storage  Storage
}

fn (o TableOperation) str() string {
	return 'TABLE $o.table_name ($o.columns())'
}

fn (o TableOperation) columns() Columns {
	return o.columns
}

fn (mut o TableOperation) execute(_ []Row) ?[]Row {
	mut rows := []Row{}

	if o.table_is_subplan {
		rows = o.subplans[o.table_name].execute([]Row{}) ?
	} else {
		rows = o.storage.read_rows(o.table_name) ?
	}

	return transform_select_expressions(o.conn, o.params, rows, o.select_list, o.columns())
}
