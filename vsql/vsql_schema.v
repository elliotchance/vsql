module vsql

// The VSQL schema has everything that's built into vsql that isn't in the SQL
// standard. Like the INFORMATION_SCHEMA, it's in every catalog, it's always
// there, it can't be created, dropped or changed, and it isn't stored in the
// file. It's owned by _SYSTEM, like every other schema (see SCHEMATA).
//
// The functions that vsql has beyond the standard (such as GCD, NOW and the
// PostgreSQL functions), and the ones that are registered with
// register_function, are the external routines of the VSQL schema. They're
// described by the ROUTINES and PARAMETERS views as if each one had been made
// with CREATE FUNCTION. A standard function (such as ABS or UPPER) isn't a
// routine, it's part of the grammar, so it isn't in any schema.
//
// The SQL-path that's used to find a routine that isn't qualified by a schema
// always ends with the VSQL schema, after every other schema. That can't be
// changed, so a routine with the same name in another schema is always found
// first, and VSQL.GCD is always the built-in GCD.
//
// ISO/IEC 9075-2:2023, 9.18, Invoking an SQL-invoked routine, Syntax Rules, 7.d
const vsql_schema_name = 'VSQL'

// system_schema_names are the schemas that are in every catalog, aren't stored
// in the file, and can't be changed.
const system_schema_names = [information_schema_name, vsql_schema_name]

// A VsqlRoutine is a function that's described as a routine of the VSQL
// schema. Each overload is its own routine, with its own specific name.
struct VsqlRoutine {
	specific_name string
	func          Func
}

// is_vsql_routine is true for a function that's a routine of the VSQL schema.
// A built-in function is a vsql extension when it's flagged with a vsql feature
// (see Func.features), which always starts with V. A standard function can
// also be flagged with a standard feature, such as POSITION of a BINARY LARGE
// OBJECT (T047), but it isn't a routine. A function that's registered with
// register_function is always called on a NULL argument, unlike a built-in
// function. Aggregate functions aren't routines.
fn (f Func) is_vsql_routine() bool {
	return !f.is_agg && (f.features.any(it.starts_with('V')) || f.called_on_null_input)
}

// vsql_routines returns the routines of the VSQL schema, ordered by name, then
// by the order they were registered in. The specific name is the name with the
// number of the overload (from 1), such as GCD_1. It's implementation-dependent,
// but must be unique in the schema:
//
//   ISO/IEC 9075-2:2023, 11.60, <SQL-invoked routine>, Syntax Rules, 9.s and 9.u
fn (conn &Connection) vsql_routines() []VsqlRoutine {
	mut overloads := map[string]int{}
	mut routines := []VsqlRoutine{}
	for f in conn.funcs {
		if f.is_vsql_routine() {
			overloads[f.name]++
			routines << VsqlRoutine{'${f.name}_${overloads[f.name]}', f}
		}
	}
	routines.sort_with_compare(fn (a &VsqlRoutine, b &VsqlRoutine) int {
		if a.func.name != b.func.name {
			return if a.func.name < b.func.name { -1 } else { 1 }
		}
		an := a.specific_name.all_after_last('_').int()
		bn := b.specific_name.all_after_last('_').int()
		return an - bn
	})

	return routines
}

// register_vsql_schema adds the views of the VSQL schema to a catalog.
//
// LAST_VACUUM has the rows of the last VACUUM of the connection that reads it
// (see VacuumTarget.rows), and LAST_VACUUM_ANALYZE the rows of the last VACUUM
// ANALYZE (see VacuumAnalysis.rows). They're only in memory and are gone when
// the connection is closed. Each is the same in every catalog, since a VACUUM
// can be of more than one catalog. Their columns are named and typed like the
// views of the INFORMATION_SCHEMA, except the bytes, which can be more than a
// CARDINAL_NUMBER.
fn register_vsql_schema(mut catalog CatalogConnection) ! {
	register_vsql_view(mut catalog, 'CREATE TABLE LAST_VACUUM (
		OBJECT_CATALOG ${information_schema_sql_identifier} NOT NULL,
		OBJECT_SCHEMA ${information_schema_sql_identifier},
		OBJECT_NAME ${information_schema_sql_identifier},
		OBJECT_TYPE ${information_schema_character_data} NOT NULL,
		PAGES_READ ${information_schema_cardinal_number} NOT NULL,
		PAGES_FREED ${information_schema_cardinal_number} NOT NULL,
		IS_FINISHED ${information_schema_yes_or_no} NOT NULL
	)', vsql_last_vacuum, fn (mut t VirtualTable) ! {
		for row in t.conn.last_vacuum {
			t.next_values(row)
		}
		t.done()
	})!

	register_vsql_view(mut catalog, 'CREATE TABLE LAST_VACUUM_ANALYZE (
		OBJECT_CATALOG ${information_schema_sql_identifier} NOT NULL,
		OBJECT_SCHEMA ${information_schema_sql_identifier},
		OBJECT_NAME ${information_schema_sql_identifier},
		OBJECT_TYPE ${information_schema_character_data} NOT NULL,
		PAGE_SIZE ${information_schema_cardinal_number} NOT NULL,
		PAGES ${information_schema_cardinal_number} NOT NULL,
		TOTAL_BYTES BIGINT NOT NULL,
		USED_BYTES BIGINT,
		VERSIONS ${information_schema_cardinal_number},
		EXPIRED_VERSIONS ${information_schema_cardinal_number},
		INTERNAL_PAGES ${information_schema_cardinal_number},
		FREE_PAGES ${information_schema_cardinal_number},
		PAGES_AFTER_COMPACT ${information_schema_cardinal_number} NOT NULL,
		PAGES_AFTER_FULL ${information_schema_cardinal_number},
		PAGES_AFTER_FREE_PAGES ${information_schema_cardinal_number} NOT NULL,
		TOTAL_BYTES_AFTER_COMPACT BIGINT NOT NULL,
		TOTAL_BYTES_AFTER_FULL BIGINT,
		TOTAL_BYTES_AFTER_FREE_PAGES BIGINT NOT NULL,
		IS_FINISHED ${information_schema_yes_or_no} NOT NULL
	)', vsql_last_vacuum_analyze, fn (mut t VirtualTable) ! {
		for row in t.conn.last_vacuum_analyze {
			t.next_values(row)
		}
		t.done()
	})!
}

fn register_vsql_view(mut catalog CatalogConnection, create_table string, feature string, data VirtualTableProviderFn) ! {
	stmt := parse_definition(create_table.bytes())!
	if stmt is TableDefinition {
		table_name := Identifier{
			catalog_name: catalog.catalog_name
			schema_name:  vsql_schema_name
			entity_name:  stmt.table_name.entity_name
		}
		catalog.virtual_tables[table_name.storage_id()] = VirtualTable{
			create_table_sql:  create_table
			create_table_stmt: TableDefinition{
				...stmt
				table_name: table_name
			}
			data:              data
			features:          [feature]
		}
	}
}
