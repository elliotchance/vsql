// table.v is the definition of a table (columns names and types).

module vsql

// A column definition.
//
// snippet: v.Column
struct Column {
pub:
	// name is case-sensitive. The name is equivilent to using a deliminated
	// identifier (with double quotes).
	//
	// snippet: v.Column.name
	name string
	// typ of the column contains more specifics like size and precision.
	//
	// snippet: v.Column.typ
	typ Type
	// not_null will be true if ``NOT NULL`` was specified on the column.
	//
	// snippet: v.Column.not_null
	not_null bool
}

// str returns the column definition like:
//
//   "foo" INT
//   BAR DOUBLE PRECISION NOT NULL
//
// snippet: v.Column.str
pub fn (c Column) str() string {
	name := if c.name.is_upper() { c.name } else { '"${c.name}"' }
	mut f := '${name} ${c.typ}'
	if c.not_null {
		f += ' NOT NULL'
	}

	return f
}

type Columns = []Column

fn (c Columns) str() string {
	mut s := []string{}
	for col in c {
		s << col.str()
	}

	return s.join(', ')
}

// Represents the structure of a table.
//
// snippet: v.Table
pub struct Table {
mut:
	// The tid is the transaction ID that created this table.
	tid int
pub mut:
	// The name of the table including the schema.
	//
	// snippet: v.Table.name
	name Identifier
	// The column definitions for the table.
	//
	// snippet: v.Table.columns
	columns Columns
	// If the table has a PRIMARY KEY defined the column (or columns) will be
	// defined here in order.
	//
	// snippet: v.Table.primary_key
	primary_key []string
	// When the table is virtual it is not persisted to disk.
	//
	// snippet: v.Table.is_virtual
	is_virtual bool
}

// Convenience method for returning the ordered list of column names.
//
// snippet: v.Table.column_names
pub fn (t Table) column_names() []string {
	mut names := []string{}
	for col in t.columns {
		names << col.name
	}

	return names
}

// Find a column by name, or return a SQLSTATE 42703 error.
//
// snippet: v.Table.column
pub fn (t Table) column(name string) !Column {
	for col in t.columns {
		if name == col.name {
			return col
		}
	}

	return sqlstate_42703(name) // column does not exist
}

fn (t Table) bytes() []u8 {
	mut b := new_empty_bytes()

	b.write_identifier(t.name)

	b.write_u8(u8(t.primary_key.len))
	for s in t.primary_key {
		b.write_string1(s)
	}

	for col in t.columns {
		b.write_string1(col.name)
		b.write_u8(col.typ.number())
		b.write_bool(col.not_null)
		b.write_i32(col.typ.size)
		b.write_i16(0) // precision
	}

	return b.bytes()
}

fn new_table_from_bytes(data []u8, tid int) Table {
	mut b := new_bytes(data)

	table_name := b.read_identifier()

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
		b.read_i16() // precision

		columns << Column{column_name, type_from_number(column_type, size), is_not_null}
	}

	return Table{tid, table_name, columns, primary_key, false}
}

// Returns the CREATE TABLE statement, including the ';'.
//
// snippet: v.Table.str
pub fn (t Table) str() string {
	mut s := 'CREATE TABLE ${t.name} ('
	mut cols := []string{}

	for col in t.columns {
		cols << '  ${col}'
	}

	return s + '\n' + cols.join(',\n') + '\n);'
}

// A TableOperation requires that up to rows in the table be read. The number of
// rows read may be limited and/or an offset (rows to skip) provided.
struct TableOperation {
	table_name Identifier
	// table_is_subplan is true if the table_name should be executed from the
	// subplans instead of a real table.
	table_is_subplan bool
	table            Table
	params           map[string]Value
	conn             &Connection
mut:
	subplans map[string]Plan
	storage  Storage
}

fn (o TableOperation) str() string {
	return 'TABLE ${o.table_name} (${o.columns()})'
}

fn (o TableOperation) columns() Columns {
	mut columns := []Column{}
	for column in o.table.columns {
		columns << Column{'${o.table_name.id()}.${column.name}', column.typ, column.not_null}
	}

	return columns
}

fn (mut o TableOperation) execute(_ []Row) ![]Row {
	mut rows := []Row{}

	if o.table_is_subplan {
		for row in o.subplans[o.table_name.id()].execute([]Row{})! {
			mut data := map[string]Value{}
			for k, v in row.data {
				data['${o.table_name.id()}.${k}'] = v
			}

			rows << new_row(data)
		}
	} else {
		rows = o.storage.read_rows(o.table_name.id())!
	}

	return rows
}
