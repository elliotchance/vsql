// ISO/IEC 9075-2:2016(E), 14.3, <cursor specification>

module vsql

// Format
//~
//~ <cursor specification> /* Stmt */ ::=
//~     <query expression>   -> cursor_specification

fn parse_cursor_specification(stmt QueryExpression) !Stmt {
	return stmt
}
