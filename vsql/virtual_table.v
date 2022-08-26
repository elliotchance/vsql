module vsql

// A function than will provide rows to a virtual table.
//
// snippet: v.VirtualTableProviderFn
type VirtualTableProviderFn = fn (mut t VirtualTable) !

pub struct VirtualTable {
	create_table_sql  string
	create_table_stmt CreateTableStmt
	data              VirtualTableProviderFn
mut:
	is_done bool
	rows    []Row
}

fn (mut v VirtualTable) reset() {
	v.is_done = false
	v.rows = []Row{}
}

pub fn (mut v VirtualTable) next_values(values []Value) {
	mut row := map[string]Value{}
	mut i := 0
	for col in v.create_table_stmt.table_elements {
		if col is Column {
			row[col.name] = values[i]
			i++
		}
	}
	v.rows << new_row(row)
}

pub fn (mut v VirtualTable) done() {
	v.is_done = true
}

pub fn (v VirtualTable) table() Table {
	return Table{
		name: v.create_table_stmt.table_name
		columns: v.create_table_stmt.columns()
		is_virtual: true
	}
}

// A VirtualTableOperation reads all rows from a virtual table.
//
// TODO(elliotchance): This needs to support OFFSET and FETCH.
struct VirtualTableOperation {
	table_name string
	table      VirtualTable
}

fn (o VirtualTableOperation) str() string {
	return 'VIRTUAL TABLE $o.table_name ($o.columns())'
}

fn (o VirtualTableOperation) columns() Columns {
	mut columns := []Column{}

	for column in o.table.create_table_stmt.columns() {
		columns << Column{'${o.table.create_table_stmt.table_name}.$column.name', column.typ, column.not_null}
	}

	return columns
}

fn (o VirtualTableOperation) execute(_ []Row) ![]Row {
	mut vt := o.table
	vt.reset()
	for !vt.is_done {
		vt.data(mut vt)!
	}

	mut new_rows := []Row{}

	table_name := o.table.create_table_stmt.table_name
	for row in vt.rows {
		mut data := map[string]Value{}

		for k, v in row.data {
			data['${table_name}.$k'] = v
		}

		new_rows << new_row(data)
	}

	return new_rows
}
