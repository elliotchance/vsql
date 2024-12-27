module vsql

import time

// ISO/IEC 9075-2:2016(E), 19.5, <set catalog statement>
//
// Set the default catalog name for unqualified <schema name>s in
// <preparable statement>s that are prepared in the current SQL-session by an
// <execute immediate statement> or a <prepare statement> and in
// <direct SQL statement>s that are invoked directly.

struct SetCatalogStatement {
	catalog_name ValueSpecification
}

fn (e SetCatalogStatement) pstr(params map[string]Value) string {
	return 'SET CATALOG ${e.catalog_name.pstr(params)}'
}

fn (stmt SetCatalogStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// This does not need to hold a write connection with the file.

	mut c := Compiler{
		conn:   conn
		params: params
	}
	new_catalog := stmt.catalog_name.compile(mut c)!.run(mut conn, Row{}, map[string]Value{})!.str()

	if new_catalog !in conn.catalogs {
		return sqlstate_3d000(new_catalog) // catalog does not exist
	}

	conn.current_catalog = new_catalog

	return new_result_msg('SET CATALOG 1', elapsed_parse, t.elapsed())
}

fn (stmt SetCatalogStatement) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN SET CATALOG')
}
