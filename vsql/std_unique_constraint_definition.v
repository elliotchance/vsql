module vsql

// ISO/IEC 9075-2:2016(E), 11.7, <unique constraint definition>
//
// # Function
//
// Specify a uniqueness constraint for a table.
//
// # Format
//~
//~ <unique constraint definition> /* TableElement */ ::=
//~   <unique specification> <left paren>
//~   <unique column list> <right paren>    -> unique_constraint_definition
//~
//~ <unique specification> ::=
//~   PRIMARY KEY   -> ignore
//~
//~ <unique column list> /* []Identifier */ ::=
//~   <column name list>

struct UniqueConstraintDefinition {
	columns []Identifier
}

fn parse_unique_constraint_definition(columns []Identifier) !TableElement {
	return UniqueConstraintDefinition{columns}
}

fn parse_ignore() !bool {
	return false
}
