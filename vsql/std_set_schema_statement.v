// ISO/IEC 9075-2:2016(E), 19.6, <set schema statement>

module vsql

// Format
//~
//~ <set schema statement> /* Stmt */ ::=
//~     SET <schema name characteristic>   -> set_schema_stmt
//~
//~ <schema name characteristic> /* Expr */ ::=
//~     SCHEMA <value specification>   -> expr

fn parse_set_schema_stmt(schema_name Expr) !Stmt {
	return SetSchemaStmt{schema_name}
}
