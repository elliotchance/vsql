module vsql

// ISO/IEC 9075-2:2016(E), 11.14, <drop column default clause>
//
// Drop the default clause from a column.

struct DropColumnDefaultClause {}

// execute returns the column without its default, so the default is NULL. The
// column must have a default, which can be an explicit DEFAULT NULL.
//
// ISO/IEC 9075-2:2016(E), 11.14, <drop column default clause>, Syntax Rules, 2
// ISO/IEC 9075-2:2016(E), 11.14, <drop column default clause>, General Rules, 1
fn (c DropColumnDefaultClause) execute(column Column) !Column {
	_ := column.default_value or {
		return sqlstate_42601('column ${column.name.sub_entity_name} has no DEFAULT')
	}

	return Column{
		...column
		default_value: none
	}
}
