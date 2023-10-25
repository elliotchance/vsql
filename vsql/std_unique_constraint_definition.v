// ISO/IEC 9075-2:2016(E), 11.7, <unique constraint definition>

module vsql

// Format
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

fn parse_unique_constraint_definition(columns []Identifier) !TableElement {
	return UniqueConstraintDefinition{columns}
}

fn parse_ignore() !bool {
	return false
}
