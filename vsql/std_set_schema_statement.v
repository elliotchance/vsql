// ISO/IEC 9075-2:2016(E), 19.6, <set schema statement>

module vsql

// Format
//~
//~ <set schema statement> /* Stmt */ ::=
//~     SET <schema name characteristic>   -> set_schema_stmt
//~
//~ <schema name characteristic> /* ValueSpecification */ ::=
//~     SCHEMA <value specification>   -> schema_name_characteristic

// SET SCHEMA
struct SetSchemaStatement {
	schema_name ValueSpecification
}

fn (e SetSchemaStatement) pstr(params map[string]Value) string {
	return 'SET SCHEMA ${e.schema_name.pstr(params)}'
}

fn parse_schema_name_characteristic(v ValueSpecification) !ValueSpecification {
	return v
}

fn parse_set_schema_stmt(schema_name ValueSpecification) !Stmt {
	return SetSchemaStatement{schema_name}
}
