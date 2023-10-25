// ISO/IEC 9075-2:2016(E), 11.2, <drop schema statement>

module vsql

// Format
//~
//~ <drop schema statement> /* Stmt */ ::=
//~     DROP SCHEMA <schema name> <drop behavior>   -> drop_schema_statement
//~
//~ <drop behavior> /* string */ ::=
//~     CASCADE
//~   | RESTRICT

fn parse_drop_schema_statement(schema_name Identifier, behavior string) !Stmt {
	return DropSchemaStmt{schema_name, behavior}
}
