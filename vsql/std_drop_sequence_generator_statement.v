// ISO/IEC 9075-2:2016(E), 11.74, <drop sequence generator statement>

module vsql

// Format
//~
//~ <drop sequence generator statement> /* Stmt */ ::=
//~     DROP SEQUENCE
//~     <sequence generator name>   -> drop_sequence_generator_statement

fn parse_drop_sequence_generator_statement(sequence_name Identifier) !Stmt {
	return DropSequenceStmt{sequence_name}
}
