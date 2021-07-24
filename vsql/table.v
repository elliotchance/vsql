// table.v is the definition of a table (columns names and types).

module vsql

struct Column {
	name string
	typ  Type
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
