module vsql

import time

// ISO/IEC 9075-2:2023(E), 11.1, <schema definition>
//
// Define a schema.

struct SchemaDefinition {
	schema_name   Identifier
	elements      []SchemaElement
	if_not_exists bool // V101-01, a schema that already exists isn't an error
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
	// ISO/IEC 9075-2:2023(E), 11.1, <schema definition>, Syntax Rules, 3
	if schema_name in catalog.storage.schemas || schema_name == information_schema_name {
		if stmt.if_not_exists {
			return new_result_msg('CREATE SCHEMA 0', elapsed_parse, t.elapsed())
		}

		return sqlstate_42p06(schema_name) // duplicate schema
	}

	// ISO/IEC 9075-2:2023(E), 11.1, <schema definition>, General Rules, 1.a
	catalog.storage.create_schema(schema_name)!

	// ISO/IEC 9075-2:2023(E), 11.1, <schema definition>, General Rules, 1.e
	stmt.create_elements(mut conn, identifier)!

	return new_result_msg('CREATE SCHEMA 1', elapsed_parse, t.elapsed())
}

// create_elements creates each schema element, in the order they're written.
// The new schema (and its catalog) is the implicit qualifier of every name in an
// element, which is the same as it being the default for the SQL-session until
// they're all created.
//
// The elements aren't in an order, the schema just includes the descriptor that
// each of them creates. So the tables are created without their foreign keys,
// which are added once every element has been created, so that a FOREIGN KEY
// can reference a table that's after it, and two tables can reference each
// other.
//
// ISO/IEC 9075-2:2023(E), 5.4, Names and identifiers, Syntax Rules, 4.b, 13.d.ii and 14.c
// ISO/IEC 9075-2:2023(E), 11.1, <schema definition>, General Rules, 1.e
fn (stmt SchemaDefinition) create_elements(mut conn Connection, schema Identifier) ! {
	current_catalog := conn.current_catalog
	current_schema := conn.current_schema
	conn.current_catalog = schema.catalog_name
	conn.current_schema = schema.schema_name
	defer {
		conn.current_catalog = current_catalog
		conn.current_schema = current_schema
	}

	// The names of the foreign keys that haven't been added yet are reserved,
	// so that another table can't use them.
	mut reserved_names := []string{}
	mut tables := []Table{}
	for element in stmt.elements {
		match element {
			SequenceGeneratorDefinition {
				// ISO/IEC 9075-2:2023(E), 11.72, <sequence generator definition>, Syntax Rules, 2
				check_schema_element_name(conn, element.name)!
				_ := element.create(mut conn)!
			}
			TableDefinition {
				// ISO/IEC 9075-2:2023(E), 11.3, <table definition>, Syntax Rules, 6
				check_schema_element_name(conn, element.table_name)!
				created, table := element.create_table(mut conn, true, reserved_names)!
				if created && table.foreign_keys.len > 0 {
					reserved_names << table.foreign_keys.map(it.name)
					tables << table
				}
			}
		}
	}

	for table in tables {
		mut catalog := conn.catalog_for(table.name)
		mut new_table := Table{
			...catalog.storage.table(table.name.storage_id())
			foreign_keys: table.foreign_keys
		}
		resolve_foreign_keys(mut conn, mut new_table)!
		catalog.storage.update_table(new_table)!
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
