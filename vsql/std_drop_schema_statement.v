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

struct DropSchemaStatement {
	schema_name Identifier
	behavior    string // CASCADE or RESTRICT
}

fn parse_drop_schema_statement(schema_name Identifier, behavior string) !Stmt {
	return DropSchemaStatement{schema_name, behavior}
}
