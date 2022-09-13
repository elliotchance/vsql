// column.v contains the definitions for a column (or columns).
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
	name := if c.name.is_upper() { c.name } else { '"$c.name"' }
	mut f := '$name $c.typ'
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
