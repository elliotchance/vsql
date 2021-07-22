// table.v is the definition of a table (columns names and types).

module vdb

struct Column {
	name string
	typ  string
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
