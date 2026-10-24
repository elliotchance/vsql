module vsql

// A function than will provide rows to a virtual table.
type VirtualTableProviderFn = fn (mut t VirtualTable) !

pub struct VirtualTable {
	create_table_sql  string
	create_table_stmt TableDefinition
	data              VirtualTableProviderFn @[required]
mut:
	is_done bool
	rows    []Row
	// wrong_values is the number of values of a row that doesn't have one for
	// each column, or -1.
	wrong_values int = -1
}

fn (mut v VirtualTable) reset() {
	v.is_done = false
	v.rows = []Row{}
	v.wrong_values = -1
}

// next_values adds a row, with a value for each column, in order. Each value
// is converted to the type of its column (like an INSERT), see
// VirtualTableOperation.
pub fn (mut v VirtualTable) next_values(values []Value) {
	columns := v.create_table_stmt.columns()
	// The rows can't be used, so the table is finished. See
	// VirtualTableOperation.
	if values.len != columns.len {
		v.wrong_values = values.len
		v.is_done = true
		return
	}

	mut row := map[string]Value{}
	for i, column in columns {
		row[column.name.sub_entity_name] = values[i]
	}
	v.rows << new_row(row)
}

pub fn (mut v VirtualTable) done() {
	v.is_done = true
}

pub fn (v VirtualTable) table() Table {
	// Like a table from the file, each column is fully qualified (see
	// TableDefinition.table).
	table_name := v.create_table_stmt.table_name
	mut columns := []Column{}
	for column in v.create_table_stmt.columns() {
		columns << Column{
			...column
			name: Identifier{
				catalog_name:    table_name.catalog_name
				schema_name:     table_name.schema_name
				entity_name:     table_name.entity_name
				sub_entity_name: column.name.sub_entity_name
			}
		}
	}

	return Table{
		name:       table_name
		columns:    columns
		is_virtual: true
	}
}

// A VirtualTableOperation reads all rows from a virtual table.
//
// TODO(elliotchance): This needs to support OFFSET and FETCH.
struct VirtualTableOperation {
	table_name string
	table      VirtualTable
mut:
	conn &Connection
}

fn (o VirtualTableOperation) str() string {
	return 'VIRTUAL TABLE ${o.table_name} (${o.table.create_table_stmt.columns()})'
}

fn (o VirtualTableOperation) columns() Columns {
	return o.table.table().columns
}

fn (mut o VirtualTableOperation) execute(_ []Row) ![]Row {
	mut vt := o.table
	vt.reset()
	for !vt.is_done {
		vt.data(mut vt)!
	}

	columns := o.columns()
	if vt.wrong_values >= 0 {
		return sqlstate_42601('virtual table ${o.table_name} has ${columns.len} ${pluralize(columns.len, 'column')}, but a row has ${vt.wrong_values} ${pluralize(vt.wrong_values, 'value')}')
	}

	mut new_rows := []Row{}
	for row in vt.rows {
		mut data := map[string]Value{}
		for column in columns {
			name := column.name.sub_entity_name
			value := row.data[name] or { return sqlstate_xx000('missing value for ${name}') }
			check_store_assignment(value, column.typ)!
			// A value has the type of its column, like when it's read from a table.
			data[column.name.id()] = Value{
				...cast(mut o.conn, 'for column ${name}', value, column.typ)!
				typ: column.typ
			}
		}

		new_rows << new_row(data)
	}

	return new_rows
}
