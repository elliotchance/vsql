module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.3, <table definition>
//
// Define a persistent base table, a created local temporary table, or a global
// temporary table.
//
// The concepts are described by:
//
// ISO/IEC 9075-1:2003(E), 4.6.6, Base tables and their components
// ISO/IEC 9075-1:2003(E), 4.6.6.1, Base tables
// ISO/IEC 9075-2:2016(E), 4.15, Tables

type TableElement = CheckConstraintDefinition
	| Column
	| NotNullConstraint
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

// TODO(elliotchance): A table with only table constraints has no columns, but
//  it needs at least one column (#787).
//
// ISO/IEC 9075-2:2016(E), 11.3, <table definition>, Syntax Rules, 9.a

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
		// ISO/IEC 9075-2:2016(E), 11.3, <table definition>, Syntax Rules, 7
		return sqlstate_42p07('table', table_name.str()) // duplicate table
	}

	stmt.check_limits(table_name)!
	mut table := stmt.table(table_name, 0)!
	table.name_constraints(catalog.storage.schema_constraint_names(table_name))!
	resolve_generated_columns(mut conn, mut table)!
	resolve_foreign_keys(mut conn, mut table)!
	for column in table.columns {
		check_default_clause(mut conn, column)!
	}
	new_check_constraints(mut conn, table)!

	catalog.storage.create_table(table)!

	return new_result_msg('CREATE TABLE 1', elapsed_parse, t.elapsed())
}

// table checks the definition and returns the table that it describes. It's
// also used when reading a table definition from the file. A constraint that
// doesn't have a <constraint name definition> has an empty name, see
// Table.name_constraints.
fn (stmt TableDefinition) table(table_name Identifier, tid u64) !Table {
	mut columns := []Column{}
	mut primary_key := []string{}
	mut primary_key_name := ''
	mut not_null_names := map[string]string{}
	mut check_constraints := []CheckConstraintDefinition{}
	mut unique_constraints := []UniqueConstraint{}
	mut foreign_keys := []ForeignKey{}
	mut column_names := map[string]bool{}
	for table_element in stmt.table_elements {
		match table_element {
			Column {
				if table_element.name.sub_entity_name in column_names {
					return sqlstate_42601('column ${table_element.name.sub_entity_name} is defined more than once')
				}
				column_names[table_element.name.sub_entity_name] = true

				mut column := Column{
					...table_element
					name: Identifier{
						catalog_name:    table_name.catalog_name
						schema_name:     table_name.schema_name
						entity_name:     table_name.entity_name
						sub_entity_name: table_element.name.sub_entity_name
					}
				}

				// A table can have at most one identity column (also for ADD
				// COLUMN), which is implicitly NOT NULL.
				//
				// ISO/IEC 9075-2:2016(E), 11.3, <table definition>, Syntax Rules, 15
				// ISO/IEC 9075-2:2016(E), 11.11, <add column definition>, Syntax Rules, 3
				// ISO/IEC 9075-2:2016(E), 11.4, <column definition>, Syntax Rules, 16
				if identity := column.identity {
					if _ := Table{
						columns: columns
					}.identity_column()
					{
						return sqlstate_42601('table ${table_name} has more than one identity column')
					}
					column = Column{
						...column
						not_null: true
						identity: IdentityColumn{
							...identity
							sequence: new_identity_sequence(column, identity.options)!
						}
					}
				}
				columns << column
			}
			CheckConstraintDefinition {
				check_constraints << CheckConstraintDefinition{
					...table_element
					name: Identifier{
						entity_name: table_constraint_name(table_element.name, table_name)!
					}
				}
			}
			NotNullConstraint {
				table_element.characteristics.check_not_deferrable('NOT NULL')!
				if table_element.name.entity_name == '' {
					continue
				}
				if not_null_names[table_element.column] != '' {
					return sqlstate_42601('column ${table_element.column} has more than one named NOT NULL')
				}
				not_null_names[table_element.column] = table_constraint_name(table_element.name,
					table_name)!
			}
			UniqueConstraintDefinition {
				// ISO/IEC 9075-2:2016(E), 11.7, <unique constraint definition>, Syntax Rules, 8
				if table_element.is_primary_key && primary_key.len > 0 {
					return sqlstate_42601('only one PRIMARY KEY can be defined')
				}

				constraint := if table_element.is_primary_key { 'PRIMARY KEY' } else { 'UNIQUE' }
				mut unique_columns := []string{}
				for column in table_element.columns {
					if column.sub_entity_name in unique_columns {
						return sqlstate_42601('column ${column.sub_entity_name} appears more than once in ${constraint}')
					}

					// Each column must be a column of the table, and only once. A
					// column of any type can be in a PRIMARY KEY or UNIQUE,
					// because they can all be grouped.
					//
					// ISO/IEC 9075-2:2016(E), 11.7, <unique constraint definition>, Syntax Rules, 1 and 5.a
					if !stmt.has_column(column.sub_entity_name) {
						return sqlstate_42601('unknown column ${column} in ${constraint}')
					}
					unique_columns << column.sub_entity_name
				}

				name := table_constraint_name(table_element.name, table_name)!
				if table_element.is_primary_key {
					table_element.characteristics.check_not_deferrable('PRIMARY KEY')!
					primary_key = unique_columns.clone()
					primary_key_name = name
				} else {
					unique_constraints << UniqueConstraint{name, unique_columns, table_element.characteristics}
				}
			}
			ReferentialConstraintDefinition {
				// Each referencing column must be a column of the table, and only
				// once.
				//
				// ISO/IEC 9075-2:2016(E), 11.8, <referential constraint definition>, Syntax Rules, 8
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

				// A referenced column can't be given more than once. The rest of
				// the referenced table and columns are checked by
				// resolve_foreign_keys.
				//
				// ISO/IEC 9075-2:2016(E), 11.8, <referential constraint definition>, Syntax Rules, 4.a
				mut referenced_columns := []string{}
				for column in table_element.referenced_columns {
					if column.sub_entity_name in referenced_columns {
						return sqlstate_42601('column ${column.sub_entity_name} appears more than once in REFERENCES')
					}
					referenced_columns << column.sub_entity_name
				}

				foreign_keys << ForeignKey{
					name:               table_constraint_name(table_element.name, table_name)!
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
					// NO ACTION is the same as no ON UPDATE or ON DELETE.
					//
					// ISO/IEC 9075-2:2016(E), 11.8, <referential constraint definition>, Syntax Rules, 12 and 13
					update_rule:        if table_element.update_rule == 'NO ACTION' {
						''
					} else {
						table_element.update_rule
					}
					delete_rule:        if table_element.delete_rule == 'NO ACTION' {
						''
					} else {
						table_element.delete_rule
					}
					characteristics:    table_element.characteristics
				}
			}
		}
	}

	// Each unique constraint must have a different set of columns, in any order.
	//
	// ISO/IEC 9075-2:2016(E), 11.7, <unique constraint definition>, Syntax Rules, 5.c
	mut column_sets := map[string]bool{}
	mut all_unique_columns := [primary_key]
	all_unique_columns << unique_constraints.map(it.columns)
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

	// Columns in the PRIMARY KEY are implicitly NOT NULL.
	//
	// ISO/IEC 9075-2:2016(E), 11.7, <unique constraint definition>, Syntax Rules, 7
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
		primary_key_name:   primary_key_name
		not_null_names:     not_null_names
		check_constraints:  check_constraints
		unique_constraints: unique_constraints
		foreign_keys:       foreign_keys
	}
}

// table_constraint_name is the name of a constraint of a table, or empty if it
// wasn't given one. The name can only be qualified by the schema of the table,
// which is also the schema of an unqualified name.
//
// ISO/IEC 9075-2:2016(E), 11.6, <table constraint definition>, Syntax Rules, 2
fn table_constraint_name(name Identifier, table_name Identifier) !string {
	if (name.catalog_name != '' && name.catalog_name != table_name.catalog_name)
		|| (name.schema_name != '' && name.schema_name != table_name.schema_name) {
		return sqlstate_42601('constraint ${name} must be in the same schema as table ${table_name}')
	}

	return name.entity_name
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
