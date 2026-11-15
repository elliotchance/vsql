module vsql

// ISO/IEC 9075-11:2006, 5.50, SCHEMATA view
//
// The SCHEMATA view has a row for each schema of the catalog, including the
// INFORMATION_SCHEMA, ordered by name (Description, 1 and 2 of ISO/IEC
// 9075-11:2006, 6.41, SCHEMATA base table).
//
// There are no authorization identifiers yet (#732), so the owner of every
// schema is _SYSTEM, which is the default (and only) user (Description, 3).
// It's the special grantor value of the standard, and it can only be written as
// a delimited identifier, so it can't be the same as a user that's created
// later. The standard makes the INFORMATION_SCHEMA its own owner, which isn't
// the same:
//
//   ISO/IEC 9075-11:2006, 5.1, INFORMATION_SCHEMA Schema
//
// The default character set of every schema is UTF8 (Description, 4), which is
// the only one (see CHARACTER_SETS). A schema can't have a <schema path
// specification>, so SQL_PATH is NULL (Description, 5.b).
//
// The view only has the schemas owned by the current user, which is every one.
fn (mut catalog CatalogConnection) register_schemata_view() ! {
	c := &catalog
	id := information_schema_sql_identifier
	catalog.add_information_schema_table('CREATE TABLE SCHEMATA (
		CATALOG_NAME ${id} NOT NULL,
		SCHEMA_NAME ${id} NOT NULL,
		SCHEMA_OWNER ${id} NOT NULL,
		DEFAULT_CHARACTER_SET_CATALOG ${id} NOT NULL,
		DEFAULT_CHARACTER_SET_SCHEMA ${id} NOT NULL,
		DEFAULT_CHARACTER_SET_NAME ${id} NOT NULL,
		SQL_PATH ${information_schema_character_data}
	)',
		fn [c] (mut t VirtualTable) ! {
			mut names := c.storage.schemas.keys()
			names << information_schema_name
			names.sort()
			for name in names {
				t.next_values([
					new_varchar_value(c.catalog_name), // CATALOG_NAME
					new_varchar_value(name), // SCHEMA_NAME
					new_varchar_value('_SYSTEM'), // SCHEMA_OWNER
					new_varchar_value(c.catalog_name), // DEFAULT_CHARACTER_SET_CATALOG
					new_varchar_value(information_schema_name), // DEFAULT_CHARACTER_SET_SCHEMA
					new_varchar_value('UTF8'), // DEFAULT_CHARACTER_SET_NAME
					new_null_value(.is_varchar), // SQL_PATH
				])
			}
			t.done()
		})!
}
