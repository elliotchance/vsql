module vsql

// ISO/IEC 9075-2:2016(E), 11.4, <column definition>
//
// Define a column of a base table.

// add_column_constraint applies a <column constraint> to the column, which is
// the first of the elements. A PRIMARY KEY on a column is the same as the table
// constraint PRIMARY KEY (column), so it's added as one (Syntax Rule 17). It's
// checked with the other table elements, so it's also an error if the table has
// another PRIMARY KEY.
fn add_column_constraint(elements []TableElement, constraint string) []TableElement {
	column := elements[0] as Column
	if constraint == 'NOT NULL' {
		mut new_elements := elements.clone()
		new_elements[0] = Column{column.name, column.typ, true}
		return new_elements
	}

	return append_list(elements, TableElement(UniqueConstraintDefinition{[column.name]}))
}
