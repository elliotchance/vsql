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
// CHECK_OPTION is CASCADED for a view with CHECK OPTION (there's no LOCAL,
// #1262), otherwise it's NONE. A view made by CREATE VIEW can be updated
// and inserted into if it's simply updatable (see updatable_view), but the views
// of the INFORMATION_SCHEMA can't be (Description, 3 and 4). INSERTABLE_INTO is
// the same as the IS_INSERTABLE_INTO of the TABLES view.
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
						view_check_option(c, table), // CHECK_OPTION
						yes_or_no(table.updatable), // IS_UPDATABLE
						yes_or_no(table.updatable), // INSERTABLE_INTO
					])
				}
			}
			t.done()
		})!
}

// view_check_option is the CHECK_OPTION of the VIEWS view.
fn view_check_option(c &CatalogConnection, table Table) Value {
	view := c.storage.views[table.name.storage_id()] or { return new_varchar_value('NONE') }

	return new_varchar_value(if view.check_option { 'CASCADED' } else { 'NONE' })
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
// These views have a row for each column, routine or table that the query of a
// view made by CREATE VIEW uses, which is found by planning the query (see
// Connection.view_usage_of):
//
//   ISO/IEC 9075-11:2006, 6.62, VIEW_COLUMN_USAGE base table
//   ISO/IEC 9075-11:2006, 6.63, VIEW_ROUTINE_USAGE base table
//   ISO/IEC 9075-11:2006, 6.64, VIEW_TABLE_USAGE base table
//
// A table is a base table or a view (including the views of the
// INFORMATION_SCHEMA) that the query reads, but not the tables that another
// view reads for it. A column is a column of one of those tables that the query
// references, including with *. A routine is a routine of the VSQL schema
// (see vsql_routines) that the query invokes. The views of the
// INFORMATION_SCHEMA don't use anything that's described here.
//
// The standard only has the views of schemas that the current user owns, but
// there are no owners (#732), so they have every view. A view that can't be read
// (such as when a table that it reads was dropped) uses nothing.
fn (mut catalog CatalogConnection) register_view_usage_views() ! {
	c := &catalog
	id := information_schema_sql_identifier

	catalog.add_information_schema_table('CREATE TABLE VIEW_COLUMN_USAGE (
		VIEW_CATALOG ${id} NOT NULL,
		VIEW_SCHEMA ${id} NOT NULL,
		VIEW_NAME ${id} NOT NULL,
		TABLE_CATALOG ${id} NOT NULL,
		TABLE_SCHEMA ${id} NOT NULL,
		TABLE_NAME ${id} NOT NULL,
		COLUMN_NAME ${id} NOT NULL
	)',
		fn [c] (mut t VirtualTable) ! {
			for view in c.sorted_views() {
				usage := t.conn.view_usage_of(c.catalog_name, view) or { continue }
				for column in usage.columns {
					t.next_values(view_usage_row(c.catalog_name, view, [
						column.schema_name,
						column.entity_name,
						column.sub_entity_name,
					]))
				}
			}
			t.done()
		})!

	catalog.add_information_schema_table('CREATE TABLE VIEW_ROUTINE_USAGE (
		TABLE_CATALOG ${id} NOT NULL,
		TABLE_SCHEMA ${id} NOT NULL,
		TABLE_NAME ${id} NOT NULL,
		SPECIFIC_CATALOG ${id} NOT NULL,
		SPECIFIC_SCHEMA ${id} NOT NULL,
		SPECIFIC_NAME ${id} NOT NULL
	)',
		fn [c] (mut t VirtualTable) ! {
			for view in c.sorted_views() {
				usage := t.conn.view_usage_of(c.catalog_name, view) or { continue }
				for routine in usage.routines {
					t.next_values(view_usage_row(c.catalog_name, view, [
						vsql_schema_name,
						routine,
					]))
				}
			}
			t.done()
		})!

	catalog.add_information_schema_table('CREATE TABLE VIEW_TABLE_USAGE (
		VIEW_CATALOG ${id} NOT NULL,
		VIEW_SCHEMA ${id} NOT NULL,
		VIEW_NAME ${id} NOT NULL,
		TABLE_CATALOG ${id} NOT NULL,
		TABLE_SCHEMA ${id} NOT NULL,
		TABLE_NAME ${id} NOT NULL
	)',
		fn [c] (mut t VirtualTable) ! {
			for view in c.sorted_views() {
				usage := t.conn.view_usage_of(c.catalog_name, view) or { continue }
				for table in usage.tables {
					t.next_values(view_usage_row(c.catalog_name, view, [
						table.schema_name,
						table.entity_name,
					]))
				}
			}
			t.done()
		})!
}

// view_usage_row is a row of one of the usage views: the view, then the catalog
// and the rest of the name of what it uses.
fn view_usage_row(catalog_name string, view View, used []string) []Value {
	mut row := [new_varchar_value(catalog_name), new_varchar_value(view.name.schema_name),
		new_varchar_value(view.name.entity_name), new_varchar_value(catalog_name)]
	row << used.map(new_varchar_value(it))

	return row
}

// sorted_views are the views of the catalog, ordered by schema and name.
fn (catalog &CatalogConnection) sorted_views() []View {
	mut views := catalog.storage.views.values()
	views.sort_with_compare(fn (a &View, b &View) int {
		if a.name.schema_name != b.name.schema_name {
			return a.name.schema_name.compare(b.name.schema_name)
		}
		return a.name.entity_name.compare(b.name.entity_name)
	})

	return views
}

// ViewUsage is what the query of a view uses (see Connection.view_usage_of).
// Each is in the order of their names.
@[heap]
struct ViewUsage {
mut:
	// tables are the base tables and views that the query reads.
	tables []Identifier
	// columns are the columns of the tables that the query references. The
	// sub_entity_name is the name of the column.
	columns []Identifier
	// routines are the specific names of the routines of the VSQL schema.
	routines []string
	// correlations are the tables that a table with a correlation name (such as
	// "t AS x (a, b)") reads, by the id of the correlation name, so that its
	// columns are the columns of the table.
	correlations map[string]ViewUsageCorrelation
}

// ViewUsageCorrelation is a table with a correlation name, see
// ViewUsage.correlations.
struct ViewUsageCorrelation {
	table Identifier
	// columns are the names of the columns of the table, in the same order as
	// names, the names of the columns with the correlation name.
	columns []string
	names   []string
}

fn (mut u ViewUsage) add_table(name Identifier) {
	table := Identifier{
		schema_name: name.schema_name
		entity_name: name.entity_name
	}
	if !u.tables.any(it.storage_id() == table.storage_id()) {
		u.tables << table
		u.tables.sort_with_compare(compare_view_usage)
	}
}

fn (mut u ViewUsage) add_correlation(table Table, base_table Identifier, columns []string) {
	u.correlations[table.name.id()] = ViewUsageCorrelation{base_table, columns, table.column_names()}
}

// add_column adds a column of a table that's in scope, which might be a table
// with a correlation name. Only the columns of the tables that the query reads
// are added, not the columns of a derived table.
fn (mut u ViewUsage) add_column(table_name Identifier, column_name string) {
	mut table := table_name
	mut name := column_name
	if correlation := u.correlations[table_name.id()] {
		// The correlation has the same columns as its table.
		table = correlation.table
		name = correlation.columns[correlation.names.index(column_name)] or { return }
	}
	if !u.tables.any(it.schema_name == table.schema_name && it.entity_name == table.entity_name) {
		return
	}

	column := Identifier{
		schema_name:     table.schema_name
		entity_name:     table.entity_name
		sub_entity_name: name
	}
	if !u.columns.any(it.storage_id() == column.storage_id()) {
		u.columns << column
		u.columns.sort_with_compare(compare_view_usage)
	}
}

fn (mut u ViewUsage) add_routine(specific_name string) {
	if specific_name !in u.routines {
		u.routines << specific_name
		u.routines.sort()
	}
}

fn compare_view_usage(a &Identifier, b &Identifier) int {
	for pair in [[a.schema_name, b.schema_name], [a.entity_name, b.entity_name],
		[a.sub_entity_name, b.sub_entity_name]] {
		if pair[0] != pair[1] {
			return pair[0].compare(pair[1])
		}
	}

	return 0
}

// record_column_usage adds a column reference to the usage of the view that's
// being planned (see ViewUsage). It's only called once the reference has been
// compiled, so it's known to be valid.
fn (mut c Compiler) record_column_usage(e Identifier) {
	if isnil(c.conn.view_usage) || e.custom_id != '' {
		return
	}

	// The same order that Identifier.compile_column finds the column.
	mut tables := c.tables.clone()
	if !e.is_column_of(c.conn, tables, c.context) {
		for i := c.conn.subquery_scopes.len - 1; i >= 0; i-- {
			scope := c.conn.subquery_scopes[i]
			if e.is_column_of(c.conn, scope.tables, scope.context) {
				tables = scope.tables.clone()
				break
			}
		}
	}

	for _, table in tables {
		if e.is_column_of_table(c.conn, table) {
			c.conn.view_usage.add_column(table.name, e.sub_entity_name)
		}
	}
}

// view_usage_of is what the query of a view uses, found by planning it, or none
// if it can't be planned (such as when a table that it reads was dropped).
fn (mut conn Connection) view_usage_of(catalog_name string, view View) ?ViewUsage {
	name := Identifier{
		...view.name
		catalog_name: catalog_name
	}
	query := view.query_expression() or { return none }
	previous := conn.view_usage
	mut usage := &ViewUsage{}
	conn.view_usage = usage
	defer {
		conn.view_usage = previous
	}
	view_query_plan(mut conn, name, query) or { return none }

	return *usage
}
