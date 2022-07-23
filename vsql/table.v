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
	// When the table is virtual it is not persisted to disk.
	is_virtual bool
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

fn (t Table) bytes() []u8 {
	mut b := new_empty_bytes()

	b.write_string1(t.name)

	b.write_u8(u8(t.primary_key.len))
	for s in t.primary_key {
		b.write_string1(s)
	}

	for col in t.columns {
		b.write_string1(col.name)
		b.write_u8(col.typ.number())
		b.write_bool(col.not_null)
		b.write_i32(col.typ.size)
		b.write_i16(col.typ.scale)
	}

	return b.bytes()
}

fn new_table_from_bytes(data []u8, tid int) Table {
	mut b := new_bytes(data)

	table_name := b.read_string1()

	primary_key_len := b.read_u8()
	mut primary_key := []string{len: int(primary_key_len)}
	for i in 0 .. int(primary_key_len) {
		primary_key[i] = b.read_string1()
	}

	mut columns := []Column{}
	for b.has_more() {
		column_name := b.read_string1()
		column_type := b.read_u8()
		is_not_null := b.read_bool()
		size := b.read_i32()
		scale := b.read_i16()

		columns << Column{column_name, type_from_number(column_type, size, scale), is_not_null}
	}

	return Table{table_name, columns, primary_key, tid, false}
}

// A TableOperation requires that up to rows in the table be read. The number of
// rows read may be limited and/or an offset (rows to skip) provided.
struct TableOperation {
	table_name string
	// table_is_subplan is true if the table_name should be executed from the
	// subplans instead of a real table.
	table_is_subplan  bool
	table             Table
	params            map[string]Value
	conn              &Connection
	prefix_table_name bool
mut:
	subplans map[string]Plan
	storage  Storage
}

fn (o TableOperation) str() string {
	return 'TABLE $o.table_name ($o.columns())'
}

fn (o TableOperation) columns() Columns {
	if o.prefix_table_name {
		mut columns := []Column{}
		for column in o.table.columns {
			columns << Column{'${o.table_name}.$column.name', column.typ, column.not_null}
		}

		return columns
	}

	return o.table.columns
}

fn (mut o TableOperation) execute(_ []Row) ?[]Row {
	mut rows := []Row{}

	if o.table_is_subplan {
		for row in o.subplans[o.table_name].execute([]Row{})? {
			mut data := map[string]Value{}
			for k, v in row.data {
				data['${o.table_name}.$k'] = v
			}

			rows << new_row(data)
		}
	} else {
		rows = o.storage.read_rows(o.table_name, o.prefix_table_name)?
	}

	return rows
}
