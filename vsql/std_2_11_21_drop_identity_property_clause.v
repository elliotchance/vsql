module vsql

// ISO/IEC 9075-2:2023, 11.21, <drop identity property clause>
//
// Make an identity column a normal column.

struct DropIdentityPropertyClause {}

// execute returns the column without its identity (whether it was ALWAYS or BY
// DEFAULT) and its sequence. The current value of the sequence is dropped by
// AlterColumnDefinition. The column keeps its values and its NOT NULL, which
// can then be dropped like any other NOT NULL.
//
// ISO/IEC 9075-2:2023, 11.21, <drop identity property clause>, General Rules, 1 and 2
fn (c DropIdentityPropertyClause) execute(column Column) Column {
	return Column{
		...column
		identity: none
	}
}
