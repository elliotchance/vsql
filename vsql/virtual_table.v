module vsql

type VirtualTableProviderFn = fn (mut t VirtualTable) ?

struct VirtualTable {
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
			row[identifier_name(col.name)] = values[i]
			i++
		}
	}
	v.rows << new_row(row)
}

pub fn (mut v VirtualTable) done() {
	v.is_done = true
}

// A VirtualTableOperation reads all rows from a virtual table.
//
// TODO(elliotchance): This needs to support OFFSET and FETCH.
struct VirtualTableOperation {
	table_name string
	table      VirtualTable
}

fn (o VirtualTableOperation) str() string {
	return 'TABLE $o.table_name -- virtual'
}

fn (o VirtualTableOperation) execute(_ []Row) ?[]Row {
	mut vt := o.table
	vt.reset()
	for !vt.is_done {
		vt.data(mut vt) ?
	}

	return vt.rows
}
