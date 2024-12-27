module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.3, <table definition>
//
// Define a persistent base table, a created local temporary table, or a global
// temporary table.

type TableElement = Column | UniqueConstraintDefinition

struct TableDefinition {
	table_name     Identifier
	table_elements []TableElement
}

fn (s TableDefinition) columns() Columns {
	mut columns := []Column{}
	for c in s.table_elements {
		if c is Column {
			columns << c
		}
	}

	return columns
}

// TODO(elliotchance): A table is allowed to have zero columns.

fn (stmt TableDefinition) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut catalog := conn.catalog()
	mut table_name := conn.resolve_schema_identifier(stmt.table_name)!
	if table_name.storage_id() in catalog.storage.tables {
		return sqlstate_42p07(table_name.str()) // duplicate table
	}

	mut columns := []Column{}
	mut primary_key := []string{}
	for table_element in stmt.table_elements {
		match table_element {
			Column {
				if (table_element.typ.typ == .is_numeric || table_element.typ.typ == .is_decimal)
					&& table_element.typ.size == 0 {
					return sqlstate_42601('column ${table_element.name.sub_entity_name}: ${table_element.typ.typ} must specify a size')
				}

				columns << Column{Identifier{
					catalog_name:    table_name.catalog_name
					schema_name:     table_name.schema_name
					entity_name:     table_name.entity_name
					sub_entity_name: table_element.name.sub_entity_name
				}, table_element.typ, table_element.not_null}
			}
			UniqueConstraintDefinition {
				if primary_key.len > 0 {
					return sqlstate_42601('only one PRIMARY KEY can be defined')
				}

				if table_element.columns.len > 1 {
					return sqlstate_42601('PRIMARY KEY only supports one column')
				}

				for column in table_element.columns {
					// Only some types are allowed in the PRIMARY KEY.
					mut found := false
					for e in stmt.table_elements {
						if e is Column {
							if e.name.sub_entity_name == column.sub_entity_name {
								match e.typ.typ {
									.is_smallint, .is_integer, .is_bigint {
										primary_key << column.sub_entity_name
									}
									else {
										return sqlstate_42601('PRIMARY KEY does not support ${e.typ}')
									}
								}

								found = true
							}
						}
					}

					if !found {
						return sqlstate_42601('unknown column ${column} in PRIMARY KEY')
					}
				}
			}
		}
	}

	catalog.storage.create_table(table_name, columns, primary_key)!

	return new_result_msg('CREATE TABLE 1', elapsed_parse, t.elapsed())
}

fn (stmt TableDefinition) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN CREATE TABLE')
}
