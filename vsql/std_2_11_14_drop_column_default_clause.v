module vsql

// ISO/IEC 9075-2:2016(E), 11.14, <drop column default clause>
//
// Drop the default clause from a column.

struct DropColumnDefaultClause {}

// execute returns the column without its default (General Rule 1), so the
// default is NULL. The column must have a default (Syntax Rule 2), which can be
// an explicit DEFAULT NULL.
fn (c DropColumnDefaultClause) execute(column Column) !Column {
	_ := column.default_value or {
		return sqlstate_42601('column ${column.name.sub_entity_name} has no DEFAULT')
	}

	return Column{
		...column
		default_value: none
	}
}
