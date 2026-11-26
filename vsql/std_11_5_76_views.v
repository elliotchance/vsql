module vsql

// ISO/IEC 9075-11:2006, 5.76, VIEWS view
//
// The VIEWS view has a row for each view that's in the TABLES view (where
// TABLE_TYPE is VIEW), in the same order (Function of ISO/IEC 9075-11:2006,
// 6.65, VIEWS base table): the views made by CREATE VIEW and the views of the
// INFORMATION_SCHEMA itself. A view made by CREATE VIEW is described in the
// INFORMATION_SCHEMA as soon as it's created:
//
// ISO/IEC 9075-2:2023, 11.32, <view definition>, General Rules, 12
//
// VIEW_DEFINITION is the text of the view's <query expression> (Description,
// 2). The standard only shows it to the owner of the view's schema (5.76,
// VIEWS view), but there are no owners (#732), so it's always shown. The views
// of the INFORMATION_SCHEMA are built by vsql when they're read, rather than
// from a <query expression>, so there is no text and it's NULL. The standard
// would also hide it, since the INFORMATION_SCHEMA is its own owner (ISO/IEC
// 9075-11:2006, 5.1, INFORMATION_SCHEMA Schema).
//
// None of them have a CHECK OPTION, and they can't be updated or inserted into
// yet (#1448) (Description, 3 and 4), which is the same as their
// IS_INSERTABLE_INTO in the TABLES view.
fn (mut catalog CatalogConnection) register_views_view() ! {
	c := &catalog
	id := information_schema_sql_identifier
	cd := information_schema_character_data
	yn := information_schema_yes_or_no
	catalog.add_information_schema_table('CREATE TABLE VIEWS (
		TABLE_CATALOG ${id} NOT NULL,
		TABLE_SCHEMA ${id} NOT NULL,
		TABLE_NAME ${id} NOT NULL,
		VIEW_DEFINITION ${cd},
		CHECK_OPTION ${cd} NOT NULL,
		IS_UPDATABLE ${yn} NOT NULL,
		INSERTABLE_INTO ${yn} NOT NULL
	)',
		fn [c] (mut t VirtualTable) ! {
			for table in c.information_schema_tables(mut t.conn) {
				if table.is_virtual {
					t.next_values([
						new_varchar_value(c.catalog_name), // TABLE_CATALOG
						new_varchar_value(table.name.schema_name), // TABLE_SCHEMA
						new_varchar_value(table.name.entity_name), // TABLE_NAME
						view_definition(c, table), // VIEW_DEFINITION
						new_varchar_value('NONE'), // CHECK_OPTION
						yes_or_no(false), // IS_UPDATABLE
						yes_or_no(false), // INSERTABLE_INTO
					])
				}
			}
			t.done()
		})!
}

// view_definition is the VIEW_DEFINITION of the VIEWS view, which is NULL for
// the views of the INFORMATION_SCHEMA.
fn view_definition(c &CatalogConnection, table Table) Value {
	view := c.storage.views[table.name.storage_id()] or { return new_null_value(.is_varchar) }

	return new_varchar_value(view.query)
}

// ISO/IEC 9075-11:2006, 5.73, VIEW_COLUMN_USAGE view
// ISO/IEC 9075-11:2006, 5.74, VIEW_ROUTINE_USAGE view
// ISO/IEC 9075-11:2006, 5.75, VIEW_TABLE_USAGE view
//
// These views have a row for each column, routine or table that a view uses.
// The only views are the ones of
// the INFORMATION_SCHEMA, and the standard defines them on the tables of the
// DEFINITION_SCHEMA, which are in a schema that the current user doesn't own,
// so each view only ever has rows for views made by CREATE VIEW, which aren't
// in them yet (#1264). Until then, they're empty, and so are the base tables that they're defined on:
//
//   ISO/IEC 9075-11:2006, 6.62, VIEW_COLUMN_USAGE base table
//   ISO/IEC 9075-11:2006, 6.63, VIEW_ROUTINE_USAGE base table
//   ISO/IEC 9075-11:2006, 6.64, VIEW_TABLE_USAGE base table
fn (mut catalog CatalogConnection) register_view_usage_views() ! {
	id := information_schema_sql_identifier
	empty := fn (mut t VirtualTable) ! {
		t.done()
	}

	catalog.add_information_schema_table('CREATE TABLE VIEW_COLUMN_USAGE (
		VIEW_CATALOG ${id} NOT NULL,
		VIEW_SCHEMA ${id} NOT NULL,
		VIEW_NAME ${id} NOT NULL,
		TABLE_CATALOG ${id} NOT NULL,
		TABLE_SCHEMA ${id} NOT NULL,
		TABLE_NAME ${id} NOT NULL,
		COLUMN_NAME ${id} NOT NULL
	)',
		empty)!

	catalog.add_information_schema_table('CREATE TABLE VIEW_ROUTINE_USAGE (
		TABLE_CATALOG ${id} NOT NULL,
		TABLE_SCHEMA ${id} NOT NULL,
		TABLE_NAME ${id} NOT NULL,
		SPECIFIC_CATALOG ${id} NOT NULL,
		SPECIFIC_SCHEMA ${id} NOT NULL,
		SPECIFIC_NAME ${id} NOT NULL
	)',
		empty)!

	catalog.add_information_schema_table('CREATE TABLE VIEW_TABLE_USAGE (
		VIEW_CATALOG ${id} NOT NULL,
		VIEW_SCHEMA ${id} NOT NULL,
		VIEW_NAME ${id} NOT NULL,
		TABLE_CATALOG ${id} NOT NULL,
		TABLE_SCHEMA ${id} NOT NULL,
		TABLE_NAME ${id} NOT NULL
	)',
		empty)!
}
