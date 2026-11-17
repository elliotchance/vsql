module vsql

// ISO/IEC 9075-2:2023, 11.22, <drop column generation expression clause>
//
// Make a generated column a base column.

struct DropColumnGenerationExpressionClause {}

// execute returns the column without its generation expression, so it's never
// generated and values can be assigned to it. The existing rows keep the values
// that were generated, and the column keeps its data type (even if it was
// inferred from the expression) and constraints.
//
// ISO/IEC 9075-2:2023, 11.12, <alter column definition>, Syntax Rules, 8
// ISO/IEC 9075-2:2023, 11.22, <drop column generation expression clause>, General Rules, 1 and 2
fn (c DropColumnGenerationExpressionClause) execute(column Column) !Column {
	_ := column.generated or {
		return sqlstate_42601('column ${column.name.sub_entity_name} is not a generated column')
	}

	return Column{
		...column
		generated: none
	}
}
