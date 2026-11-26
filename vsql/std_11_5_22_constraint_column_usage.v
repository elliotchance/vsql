module vsql

// ISO/IEC 9075-11:2006, 5.22, CONSTRAINT_COLUMN_USAGE view
//
// The CONSTRAINT_COLUMN_USAGE view has a row for each column that a constraint
// uses, in the same order as the TABLE_CONSTRAINTS view (and with the same
// names):
//
// - The columns of a PRIMARY KEY or UNIQUE, in the order of the key.
// - The columns of the PRIMARY KEY or UNIQUE that a FOREIGN KEY references (in
//   the referenced table), in the order of that key. The columns of the
//   FOREIGN KEY itself aren't included.
// - The column of a NOT NULL, which is a check constraint.
// - Each column that a CHECK uses in its <search condition>, in the order of
//   the columns of the table (Description, 2 of ISO/IEC 9075-11:2006,
//   6.12, CHECK_COLUMN_USAGE base table).
//
// There are no assertions (F521), and a CHECK can't have a subquery (F671), so
// it can only use the columns of its own table.
//
// The view only has the columns of tables in schemas owned by the current
// user. Every schema is owned by _SYSTEM, which is the only user (see
// SCHEMATA), so it has every constraint.
fn (mut catalog CatalogConnection) register_constraint_column_usage_view() ! {
	c := &catalog
	id := information_schema_sql_identifier
	catalog.add_information_schema_table('CREATE TABLE CONSTRAINT_COLUMN_USAGE (
		TABLE_CATALOG ${id} NOT NULL,
		TABLE_SCHEMA ${id} NOT NULL,
		TABLE_NAME ${id} NOT NULL,
		COLUMN_NAME ${id} NOT NULL,
		CONSTRAINT_CATALOG ${id} NOT NULL,
		CONSTRAINT_SCHEMA ${id} NOT NULL,
		CONSTRAINT_NAME ${id} NOT NULL
	)',
		fn [c] (mut t VirtualTable) ! {
			for table in c.information_schema_tables(mut t.conn) {
				if table.is_virtual {
					continue
				}

				mut usages := []ConstraintUsage{}
				if table.primary_key.len > 0 {
					usages << ConstraintUsage{table, table.primary_key, table.primary_key_name}
				}
				for constraint in table.unique_constraints {
					usages << ConstraintUsage{table, constraint.columns, constraint.name}
				}
				for key in table.foreign_keys {
					referenced := c.storage.table(key.referenced_table.storage_id())
					_, unique_columns := unique_constraint_for(referenced, key.referenced_columns)
					usages << ConstraintUsage{referenced, unique_columns, key.name}
				}
				for column in table.columns {
					if table.has_not_null(column) {
						name := column.name.sub_entity_name
						usages << ConstraintUsage{table, [name], table.not_null_names[name]}
					}
				}
				for constraint in table.check_constraints {
					used := constraint.columns(mut t.conn, table)!
					mut columns := []string{}
					for column in table.columns {
						if column.name.sub_entity_name in used {
							columns << column.name.sub_entity_name
						}
					}
					usages << ConstraintUsage{table, columns, constraint.name.entity_name}
				}

				for usage in usages {
					for column in usage.columns {
						t.next_values([
							new_varchar_value(c.catalog_name), // TABLE_CATALOG
							new_varchar_value(usage.table.name.schema_name), // TABLE_SCHEMA
							new_varchar_value(usage.table.name.entity_name), // TABLE_NAME
							new_varchar_value(column), // COLUMN_NAME
							new_varchar_value(c.catalog_name), // CONSTRAINT_CATALOG
							new_varchar_value(table.name.schema_name), // CONSTRAINT_SCHEMA
							new_varchar_value(usage.name), // CONSTRAINT_NAME
						])
					}
				}
			}
			t.done()
		})!
}

// ConstraintUsage is a constraint (by its name) and the columns of a table that
// it uses.
struct ConstraintUsage {
	table   Table
	columns []string
	name    string
}
