// table.v is the definition of a table (columns names and types).

module vsql

// A column definition.
struct Column {
pub:
	// name resolves to the actual canonical location. If you only need the column
	// name itself, you can use name.sub_entity_name.
	name Identifier
	// typ of the column contains more specifics like size and precision.
	typ Type
	// not_null will be true if ``NOT NULL`` was specified on the column.
	not_null bool
}

// str returns the column definition like:
//
//   "foo" INT
//   BAR DOUBLE PRECISION NOT NULL
pub fn (c Column) str() string {
	mut f := '${c.name} ${c.typ}'
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
pub struct Table {
mut:
	// The tid is the transaction ID that created this table.
	tid int
pub mut:
	// The name of the table including the schema.
	name Identifier
	// The column definitions for the table.
	columns Columns
	// If the table has a PRIMARY KEY defined the column (or columns) will be
	// defined here in order.
	primary_key []string
	// When the table is virtual it is not persisted to disk.
	is_virtual bool
}

// Convenience method for returning the ordered list of column names.
pub fn (t Table) column_names() []string {
	mut names := []string{}
	for col in t.columns {
		names << col.name.sub_entity_name
	}

	return names
}

// Find a column by name, or return a SQLSTATE 42703 error.
pub fn (t Table) column(name string) !Column {
	for col in t.columns {
		if name == col.name.sub_entity_name {
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
		b.write_string1(col.name.sub_entity_name)
		b.write_u8(col.typ.number())
		b.write_bool(col.not_null)
		b.write_i32(col.typ.size)
		b.write_i16(col.typ.scale)
	}

	return b.bytes()
}

fn new_table_from_bytes(data []u8, tid int, catalog_name string) Table {
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
		scale := b.read_i16()

		columns << Column{Identifier{
			catalog_name: catalog_name
			schema_name: table_name.schema_name
			entity_name: table_name.entity_name
			sub_entity_name: column_name
		}, type_from_number(column_type, size, scale), is_not_null}
	}

	return Table{tid, table_name, columns, primary_key, false}
}

// Returns the CREATE TABLE statement, including the ';'.
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
mut:
	conn     &Connection
	subplans map[string]Plan
}

fn (o TableOperation) str() string {
	return 'TABLE ${o.table_name} (${o.pretty_columns()})'
}

// We could just render `o.table.columns`. However, it makes the output extra
// verbose, so we only show the column names.
fn (o TableOperation) pretty_columns() Columns {
	mut cols := []Column{}
	for c in o.table.columns {
		cols << Column{Identifier{
			sub_entity_name: c.name.sub_entity_name
		}, c.typ, c.not_null}
	}

	return cols
}

fn (o TableOperation) columns() Columns {
	return o.table.columns
}

fn (mut o TableOperation) execute(_ []Row) ![]Row {
	mut rows := []Row{}

	if o.table_is_subplan {
		for row in o.subplans[o.table_name.id()].execute([]Row{})! {
			mut data := map[string]Value{}
			for k, v in row.data {
				data['${o.table_name}.${k}'] = v
			}

			rows << new_row(data)
		}
	} else {
		mut catalog := o.conn.catalogs[o.table_name.catalog_name] or {
			return error('unknown catalog: ${o.table_name.catalog_name}')
		}
		rows = catalog.storage.read_rows(o.table_name)!
	}

	return rows
}
