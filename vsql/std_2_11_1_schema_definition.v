module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.1, <schema definition>
//
// Define a schema.

struct SchemaDefinition {
	schema_name Identifier
	elements    []SchemaElement
}

type SchemaElement = SequenceGeneratorDefinition | TableDefinition

fn (stmt SchemaDefinition) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	identifier := conn.resolve_catalog_identifier(stmt.schema_name)!
	mut catalog := conn.catalog_for(identifier)
	schema_name := stmt.schema_name.schema_name

	// The name can't be the same as another schema, including the
	// INFORMATION_SCHEMA, which isn't stored.
	//
	// ISO/IEC 9075-2:2016(E), 11.1, <schema definition>, Syntax Rules, 3
	if schema_name in catalog.storage.schemas || schema_name == information_schema_name {
		return sqlstate_42p06(schema_name) // duplicate schema
	}

	// ISO/IEC 9075-2:2016(E), 11.1, <schema definition>, General Rules, 1.a
	catalog.storage.create_schema(schema_name)!

	// ISO/IEC 9075-2:2016(E), 11.1, <schema definition>, General Rules, 1.e
	stmt.create_elements(mut conn, identifier)!

	return new_result_msg('CREATE SCHEMA 1', elapsed_parse, t.elapsed())
}

// create_elements creates each schema element, in the order they're written, so
// a FOREIGN KEY can only reference a table before it (#887). The new schema (and
// its catalog) is the implicit qualifier of every name in an element, which is
// the same as it being the default for the SQL-session until they're all
// created.
//
// ISO/IEC 9075-2:2016(E), 5.4, Names and identifiers, Syntax Rules, 4.b, 13.d.ii and 14.c
fn (stmt SchemaDefinition) create_elements(mut conn Connection, schema Identifier) ! {
	current_catalog := conn.current_catalog
	current_schema := conn.current_schema
	conn.current_catalog = schema.catalog_name
	conn.current_schema = schema.schema_name
	defer {
		conn.current_catalog = current_catalog
		conn.current_schema = current_schema
	}

	for element in stmt.elements {
		match element {
			SequenceGeneratorDefinition {
				// ISO/IEC 9075-2:2016(E), 11.72, <sequence generator definition>, Syntax Rules, 2
				check_schema_element_name(conn, element.name)!
				element.create(mut conn)!
			}
			TableDefinition {
				// ISO/IEC 9075-2:2016(E), 11.3, <table definition>, Syntax Rules, 6
				check_schema_element_name(conn, element.table_name)!
				element.create(mut conn)!
			}
		}
	}
}

// check_schema_element_name returns an error if the name of a schema element is
// qualified by anything other than the schema that's being created, which is
// the current schema of the connection (see create_elements).
fn check_schema_element_name(conn Connection, name Identifier) ! {
	resolved := conn.resolve_identifier(name)
	if resolved.catalog_name != conn.current_catalog
		|| resolved.schema_name != conn.current_schema {
		return sqlstate_42601('${name} must be in schema ${conn.current_schema}')
	}
}

fn (stmt SchemaDefinition) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN CREATE SCHEMA')
}
