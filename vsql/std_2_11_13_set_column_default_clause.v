module vsql

// ISO/IEC 9075-2:2016(E), 11.13, <set column default clause>
//
// Set the default clause for a column.

struct SetColumnDefaultClause {
	default_value DefaultOption
}

// execute returns the column with the new default (General Rule 2), which is
// checked the same way as the default of a column of a CREATE TABLE.
fn (c SetColumnDefaultClause) execute(mut conn Connection, column Column) !Column {
	new_column := Column{
		...column
		default_value: c.default_value
	}
	check_default_clause(mut conn, new_column)!

	return new_column
}
