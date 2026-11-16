module vsql

// ISO/IEC 9075-11:2006, 5.17, COLUMN_COLUMN_USAGE view
//
// The COLUMN_COLUMN_USAGE view has a row for each column that a generated
// column uses in its generation expression (Description, 1 and 2 of ISO/IEC
// 9075-11:2006, 6.18, COLUMN_COLUMN_USAGE base table). The rows are ordered
// by schema and table name, then by the generated column, then by the column
// that it uses (in the order of the columns of the table).
//
// The view only has the tables of schemas owned by the current user. Every
// schema is owned by _SYSTEM, which is the only user (see SCHEMATA), so it has
// every table of the catalog.
fn (mut catalog CatalogConnection) register_column_column_usage_view() ! {
	c := &catalog
	id := information_schema_sql_identifier
	catalog.add_information_schema_table('CREATE TABLE COLUMN_COLUMN_USAGE (
		TABLE_CATALOG ${id} NOT NULL,
		TABLE_SCHEMA ${id} NOT NULL,
		TABLE_NAME ${id} NOT NULL,
		COLUMN_NAME ${id} NOT NULL,
		DEPENDENT_COLUMN ${id} NOT NULL
	)',
		fn [c] (mut t VirtualTable) ! {
			for table in c.information_schema_tables() {
				for column in table.columns {
					generated := column.generated or { continue }
					used := generated.columns(mut t.conn, table, column)!
					for used_column in table.columns {
						name := used_column.name.sub_entity_name
						if name in used {
							t.next_values([
								new_varchar_value(c.catalog_name), // TABLE_CATALOG
								new_varchar_value(table.name.schema_name), // TABLE_SCHEMA
								new_varchar_value(table.name.entity_name), // TABLE_NAME
								new_varchar_value(name), // COLUMN_NAME
								new_varchar_value(column.name.sub_entity_name), // DEPENDENT_COLUMN
							])
						}
					}
				}
			}
			t.done()
		})!
}
