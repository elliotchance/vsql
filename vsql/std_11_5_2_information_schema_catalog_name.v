module vsql

// ISO/IEC 9075-11:2006, 5.2, INFORMATION_SCHEMA_CATALOG_NAME base table
//
// INFORMATION_SCHEMA_CATALOG_NAME has one row, with the name of the catalog
// that the INFORMATION_SCHEMA is in (Description, 1). The standard makes it a
// base table, with constraints that keep it to that one row. vsql builds it
// when it's read, like the views, so it's a VIEW in the TABLES view and has no
// constraints. Its rows can't be changed either way. The catalog is the one
// that's described (ISO/IEC 9075-11:2006, 6.8, CATALOG_NAMES base table).
//
// The CATALOG_NAME view (5.77) is its short name view, which is added with the
// others in register_information_schema.
fn (mut catalog CatalogConnection) register_information_schema_catalog_name_table() ! {
	c := &catalog
	catalog.add_information_schema_table('CREATE TABLE INFORMATION_SCHEMA_CATALOG_NAME (
		CATALOG_NAME ${information_schema_sql_identifier} NOT NULL
	)',
		fn [c] (mut t VirtualTable) ! {
			t.next_values([new_varchar_value(c.catalog_name)])
			t.done()
		})!
}
