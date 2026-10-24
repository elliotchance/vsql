module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.3, <table definition>
//
// Define a persistent base table, a created local temporary table, or a global
// temporary table.

type TableElement = CheckConstraintDefinition
	| Column
	| ReferentialConstraintDefinition
	| UniqueConstraintDefinition

// max_columns is the maximum number of columns in a table.
const max_columns = 1600

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

// check_limits returns an error if the table has more columns, or a column has
// a larger type, than allowed. Like check_data_type, it's not used when a table
// definition is read from the file.
fn (s TableDefinition) check_limits(table_name Identifier) ! {
	columns := s.columns()
	if columns.len > max_columns {
		return sqlstate_54000('table ${table_name} has ${columns.len} columns, but the maximum is ${max_columns}')
	}

	for column in columns {
		check_data_type(column.typ)!
	}
}

// TODO(elliotchance): A table is allowed to have zero columns.

fn (stmt TableDefinition) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut table_name := conn.resolve_schema_identifier(stmt.table_name)!
	check_writable_schema(table_name)!
	mut catalog := conn.catalog_for(table_name)
	if table_name.storage_id() in catalog.storage.tables
		|| table_name.storage_id() in catalog.virtual_tables {
		return sqlstate_42p07('table', table_name.str()) // duplicate table
	}

	stmt.check_limits(table_name)!
	mut table := stmt.table(table_name, 0)!
	resolve_foreign_keys(mut conn, mut table)!
	for column in table.columns {
		check_default_clause(mut conn, column)!
	}
	new_check_constraints(mut conn, table)!

	catalog.storage.create_table(table)!

	return new_result_msg('CREATE TABLE 1', elapsed_parse, t.elapsed())
}

// table checks the definition and returns the table that it describes. It's
// also used when reading a table definition from the file.
fn (stmt TableDefinition) table(table_name Identifier, tid u64) !Table {
	mut columns := []Column{}
	mut primary_key := []string{}
	mut check_constraints := []CheckConstraintDefinition{}
	mut unique_constraints := [][]string{}
	mut foreign_keys := []ForeignKey{}
	mut column_names := map[string]bool{}
	for table_element in stmt.table_elements {
		match table_element {
			Column {
				if table_element.name.sub_entity_name in column_names {
					return sqlstate_42601('column ${table_element.name.sub_entity_name} is defined more than once')
				}
				column_names[table_element.name.sub_entity_name] = true

				columns << Column{
					...table_element
					name: Identifier{
						catalog_name:    table_name.catalog_name
						schema_name:     table_name.schema_name
						entity_name:     table_name.entity_name
						sub_entity_name: table_element.name.sub_entity_name
					}
				}
			}
			CheckConstraintDefinition {
				check_constraints << table_element
			}
			UniqueConstraintDefinition {
				if table_element.is_primary_key && primary_key.len > 0 {
					return sqlstate_42601('only one PRIMARY KEY can be defined')
				}

				constraint := if table_element.is_primary_key { 'PRIMARY KEY' } else { 'UNIQUE' }
				mut unique_columns := []string{}
				for column in table_element.columns {
					if column.sub_entity_name in unique_columns {
						return sqlstate_42601('column ${column.sub_entity_name} appears more than once in ${constraint}')
					}

					// A column of any type can be in a PRIMARY KEY or UNIQUE,
					// because they can all be grouped (11.7 Syntax Rule 1).
					if !stmt.has_column(column.sub_entity_name) {
						return sqlstate_42601('unknown column ${column} in ${constraint}')
					}
					unique_columns << column.sub_entity_name
				}

				if table_element.is_primary_key {
					primary_key = unique_columns.clone()
				} else {
					unique_constraints << unique_columns
				}
			}
			ReferentialConstraintDefinition {
				// 11.8 Syntax Rule 8.
				mut referencing_columns := []string{}
				for column in table_element.columns {
					if column.sub_entity_name in referencing_columns {
						return sqlstate_42601('column ${column.sub_entity_name} appears more than once in FOREIGN KEY')
					}
					if !stmt.has_column(column.sub_entity_name) {
						return sqlstate_42601('unknown column ${column} in FOREIGN KEY')
					}
					referencing_columns << column.sub_entity_name
				}

				// 11.8 Syntax Rule 4a. The rest of the referenced table and
				// columns are checked by resolve_foreign_keys.
				mut referenced_columns := []string{}
				for column in table_element.referenced_columns {
					if column.sub_entity_name in referenced_columns {
						return sqlstate_42601('column ${column.sub_entity_name} appears more than once in REFERENCES')
					}
					referenced_columns << column.sub_entity_name
				}

				foreign_keys << ForeignKey{
					columns:            referencing_columns
					referenced_table:   Identifier{
						...table_element.referenced_table
						catalog_name: if table_element.referenced_table.catalog_name == '' {
							table_name.catalog_name
						} else {
							table_element.referenced_table.catalog_name
						}
					}
					referenced_columns: referenced_columns
				}
			}
		}
	}

	// Each unique constraint must have a different set of columns (11.7 Syntax
	// Rule 5c), in any order.
	mut column_sets := map[string]bool{}
	mut all_unique_columns := [primary_key]
	all_unique_columns << unique_constraints
	for unique_columns in all_unique_columns {
		if unique_columns.len == 0 {
			continue
		}
		mut sorted := unique_columns.clone()
		sorted.sort()
		set := sorted.map(delimit_identifier(it)).join(', ')
		if set in column_sets {
			return sqlstate_42601('UNIQUE (${unique_columns.map(requote_identifier(it)).join(', ')}) has the same columns as another unique constraint')
		}
		column_sets[set] = true
	}

	// Columns in the PRIMARY KEY are implicitly NOT NULL (11.7).
	for i, column in columns {
		if column.name.sub_entity_name in primary_key {
			columns[i] = Column{
				...column
				not_null: true
			}
		}
	}

	return Table{
		tid:                tid
		name:               table_name
		columns:            columns
		primary_key:        primary_key
		check_constraints:  check_constraints
		unique_constraints: unique_constraints
		foreign_keys:       foreign_keys
	}
}

// has_column is true if one of the table elements is the column.
fn (stmt TableDefinition) has_column(name string) bool {
	for e in stmt.table_elements {
		if e is Column && e.name.sub_entity_name == name {
			return true
		}
	}

	return false
}

fn (stmt TableDefinition) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN CREATE TABLE')
}
