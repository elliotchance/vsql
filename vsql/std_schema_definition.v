module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.1, <schema definition>
//
// # Function
//
// Define a schema.
//
// # Format
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

fn (stmt SchemaDefinition) execute(mut c Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	c.open_write_connection()!
	defer {
		c.release_write_connection()
	}

	mut catalog := c.catalog()
	schema_name := stmt.schema_name.schema_name

	if schema_name in catalog.storage.schemas {
		return sqlstate_42p06(schema_name) // duplicate schema
	}

	catalog.storage.create_schema(schema_name)!

	return new_result_msg('CREATE SCHEMA 1', elapsed_parse, t.elapsed())
}

fn (stmt SchemaDefinition) explain(mut c Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN CREATE SCHEMA')
}
