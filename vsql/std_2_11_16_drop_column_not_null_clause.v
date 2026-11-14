module vsql

// ISO/IEC 9075-2:2023, 11.16, <drop column not null clause>
//
// Drop a not null constraint on a column.

struct DropColumnNotNullClause {}

// execute returns the column without NOT NULL, which drops its constraint (see
// AlterColumnDefinition.execute). A column of the PRIMARY KEY is always NOT
// NULL, so it's an error. A column that isn't NOT NULL doesn't change.
//
// ISO/IEC 9075-2:2023, 11.16, <drop column not null clause>, Syntax Rules, 1 and 4
// ISO/IEC 9075-2:2023, 11.16, <drop column not null clause>, General Rules, 1
fn (c DropColumnNotNullClause) execute(table Table, column Column) !Column {
	if column.name.sub_entity_name in table.primary_key {
		return sqlstate_42601('column ${column.name.sub_entity_name} is in the PRIMARY KEY, so its NOT NULL cannot be dropped')
	}

	return Column{
		...column
		not_null: false
	}
}
