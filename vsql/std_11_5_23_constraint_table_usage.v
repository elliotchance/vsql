module vsql

// ISO/IEC 9075-11:2006, 5.23, CONSTRAINT_TABLE_USAGE view
//
// The CONSTRAINT_TABLE_USAGE view has a row for each table that a constraint
// uses, in the same order as the TABLE_CONSTRAINTS view (and with the same
// names): the table of a PRIMARY KEY or UNIQUE, and the referenced table of a
// FOREIGN KEY (not its own table).
//
// A check constraint only uses a table that's named in a subquery of its
// <search condition> (Description, 2 of ISO/IEC 9075-11:2006, 6.15,
// CHECK_TABLE_USAGE base table). A CHECK can't have a subquery (F671), and there are
// no assertions (F521), so they're never in the view.
//
// The view only has the tables in schemas owned by the current user. Every
// schema is owned by _SYSTEM, which is the only user (see SCHEMATA), so it has
// every constraint.
fn (mut catalog CatalogConnection) register_constraint_table_usage_view() ! {
	c := &catalog
	id := information_schema_sql_identifier
	catalog.add_information_schema_table('CREATE TABLE CONSTRAINT_TABLE_USAGE (
		TABLE_CATALOG ${id} NOT NULL,
		TABLE_SCHEMA ${id} NOT NULL,
		TABLE_NAME ${id} NOT NULL,
		CONSTRAINT_CATALOG ${id} NOT NULL,
		CONSTRAINT_SCHEMA ${id} NOT NULL,
		CONSTRAINT_NAME ${id} NOT NULL
	)',
		fn [c] (mut t VirtualTable) ! {
			for table in c.information_schema_tables() {
				mut usages := []ConstraintUsage{}
				if table.primary_key.len > 0 {
					usages << ConstraintUsage{table, [], table.primary_key_name}
				}
				for constraint in table.unique_constraints {
					usages << ConstraintUsage{table, [], constraint.name}
				}
				for key in table.foreign_keys {
					usages << ConstraintUsage{c.storage.table(key.referenced_table.storage_id()), [], key.name}
				}

				for usage in usages {
					t.next_values([
						new_varchar_value(c.catalog_name), // TABLE_CATALOG
						new_varchar_value(usage.table.name.schema_name), // TABLE_SCHEMA
						new_varchar_value(usage.table.name.entity_name), // TABLE_NAME
						new_varchar_value(c.catalog_name), // CONSTRAINT_CATALOG
						new_varchar_value(table.name.schema_name), // CONSTRAINT_SCHEMA
						new_varchar_value(usage.name), // CONSTRAINT_NAME
					])
				}
			}
			t.done()
		})!
}
