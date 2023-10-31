// ISO/IEC 9075-2:2016(E), 11.1, <schema definition>

module vsql

// Format
//~
//~ <schema definition> /* Stmt */ ::=
//~     CREATE SCHEMA <schema name clause>   -> schema_definition
//~
//~ <schema name clause> /* Identifier */ ::=
//~     <schema name>

struct SchemaDefinition {
	schema_name Identifier
}

fn parse_schema_definition(schema_name Identifier) !Stmt {
	return SchemaDefinition{schema_name}
}
