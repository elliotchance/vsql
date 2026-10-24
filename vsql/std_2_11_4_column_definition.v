module vsql

// ISO/IEC 9075-2:2016(E), 11.4, <column definition>
//
// Define a column of a base table.

// A <column constraint>. NOT NULL is the only one that isn't added to the table
// as a table constraint.
type ColumnConstraint = CheckConstraintDefinition | NotNullConstraint | UniqueConstraintDefinition

struct NotNullConstraint {}

// add_column_constraint applies a <column constraint> to the column, which is
// the first of the elements. A PRIMARY KEY or CHECK on a column is the same as
// the table constraint, such as PRIMARY KEY (column), so it's added as one
// (Syntax Rule 17). It's checked with the other table elements, so it's also an
// error if the table has another PRIMARY KEY. A CHECK on a column can only use
// that column (Syntax Rule 17d).
fn add_column_constraint(elements []TableElement, constraint ColumnConstraint) []TableElement {
	column := elements[0] as Column
	match constraint {
		NotNullConstraint {
			mut new_elements := elements.clone()
			new_elements[0] = Column{
				...column
				not_null: true
			}
			return new_elements
		}
		UniqueConstraintDefinition {
			return append_list(elements, TableElement(UniqueConstraintDefinition{
				...constraint
				columns: [column.name]
			}))
		}
		CheckConstraintDefinition {
			return append_list(elements, TableElement(CheckConstraintDefinition{
				...constraint
				column_name: column.name.sub_entity_name
			}))
		}
	}
}
