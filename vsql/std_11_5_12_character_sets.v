module vsql

// ISO/IEC 9075-11:2006, 5.12, CHARACTER_SETS view
//
// The CHARACTER_SETS view describes the character sets of the catalog
// (ISO/IEC 9075-11:2006, 6.11, CHARACTER_SETS base table). vsql has one
// character set, UTF8, which is in the INFORMATION_SCHEMA (the same as the
// CHARACTER_SET_SCHEMA in the COLUMNS view). Its repertoire is UCS and its
// encoding form is UTF8 (Description, 1-3). The repertoire and encoding form
// are described by base tables that only exist as this view:
//
//   ISO/IEC 9075-11:2006, 6.9, CHARACTER_ENCODING_FORMS base table
//   ISO/IEC 9075-11:2006, 6.10, CHARACTER_REPERTOIRES base table
//
// The default collation of UTF8 is UCS_BASIC, also in the INFORMATION_SCHEMA
// (Description, 4). vsql compares strings by their code points, which is
// UCS_BASIC, with the PAD SPACE characteristic (so 'a' = 'a  '), which the
// standard leaves to the implementation for a default collation.
//
// The view only has the character sets that the current user has the USAGE
// privilege on. There are no privileges (#732), so it has every one.
fn (mut catalog CatalogConnection) register_character_sets_view() ! {
	c := &catalog
	id := information_schema_sql_identifier
	catalog.add_information_schema_table('CREATE TABLE CHARACTER_SETS (
		CHARACTER_SET_CATALOG ${id} NOT NULL,
		CHARACTER_SET_SCHEMA ${id} NOT NULL,
		CHARACTER_SET_NAME ${id} NOT NULL,
		CHARACTER_REPERTOIRE ${id} NOT NULL,
		FORM_OF_USE ${id} NOT NULL,
		DEFAULT_COLLATE_CATALOG ${id} NOT NULL,
		DEFAULT_COLLATE_SCHEMA ${id} NOT NULL,
		DEFAULT_COLLATE_NAME ${id} NOT NULL
	)',
		fn [c] (mut t VirtualTable) ! {
			t.next_values([
				new_varchar_value(c.catalog_name), // CHARACTER_SET_CATALOG
				new_varchar_value(information_schema_name), // CHARACTER_SET_SCHEMA
				new_varchar_value('UTF8'), // CHARACTER_SET_NAME
				new_varchar_value('UCS'), // CHARACTER_REPERTOIRE
				new_varchar_value('UTF8'), // FORM_OF_USE
				new_varchar_value(c.catalog_name), // DEFAULT_COLLATE_CATALOG
				new_varchar_value(information_schema_name), // DEFAULT_COLLATE_SCHEMA
				new_varchar_value('UCS_BASIC'), // DEFAULT_COLLATE_NAME
			])
			t.done()
		})!
}
