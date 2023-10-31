module vsql

// ISO/IEC 9075-2:2016(E), 6.7, <column reference>
//
// # Function
//
// Reference a column.
//
// # Format
//~
//~ <column reference> /* Identifier */ ::=
//~     <basic identifier chain>   -> column_reference

fn parse_column_reference(identifier IdentifierChain) !Identifier {
	return new_column_identifier(identifier.identifier)
}
