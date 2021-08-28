module vsql

struct VirtualTable {
	create_table_sql  string
	create_table_stmt CreateTableStmt
	data              fn (mut t VirtualTable) ?
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
	for col in v.create_table_stmt.columns {
		row[identifier_name(col.name)] = values[i]
		i++
	}
	v.rows << new_row(row)
}

pub fn (mut v VirtualTable) done() {
	v.is_done = true
}
