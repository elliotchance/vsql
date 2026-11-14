module vsql

// ISO/IEC 9075-2:2023, 11.15, <set column not null clause>
//
// Add a not null constraint to a column.

struct SetColumnNotNullClause {}

// execute returns the column with NOT NULL. Its constraint gets a name like the
// NOT NULL of a CREATE TABLE, and every existing row must satisfy it (see
// AlterColumnDefinition.execute). A column that's already NOT NULL doesn't
// change.
//
// ISO/IEC 9075-2:2023, 11.15, <set column not null clause>, General Rules, 1
fn (c SetColumnNotNullClause) execute(column Column) Column {
	return Column{
		...column
		not_null: true
	}
}
