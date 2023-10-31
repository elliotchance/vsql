module vsql

import time

// ISO/IEC 9075-2:2016(E), 19.5, <set catalog statement>
//
// # Function
//
// Set the default catalog name for unqualified <schema name>s in
// <preparable statement>s that are prepared in the current SQL-session by an
// <execute immediate statement> or a <prepare statement> and in
// <direct SQL statement>s that are invoked directly.
//
// # Format
//~
//~ <set catalog statement> /* Stmt */ ::=
//~     SET <catalog name characteristic>   -> set_catalog_stmt
//~
//~ <catalog name characteristic> /* ValueSpecification */ ::=
//~     CATALOG <value specification>   -> catalog_name_characteristic

struct SetCatalogStatement {
	catalog_name ValueSpecification
}

fn (e SetCatalogStatement) pstr(params map[string]Value) string {
	return 'SET CATALOG ${e.catalog_name.pstr(params)}'
}

fn parse_set_catalog_stmt(catalog_name ValueSpecification) !Stmt {
	return SetCatalogStatement{catalog_name}
}

fn parse_catalog_name_characteristic(v ValueSpecification) !ValueSpecification {
	return v
}

fn (stmt SetCatalogStatement) execute(mut c Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// This does not need to hold a write connection with the file.

	new_catalog := stmt.catalog_name.eval(mut c, Row{}, map[string]Value{})!.str()

	if new_catalog !in c.catalogs {
		return sqlstate_3d000(new_catalog) // catalog does not exist
	}

	c.current_catalog = new_catalog

	return new_result_msg('SET CATALOG 1', elapsed_parse, t.elapsed())
}

fn (stmt SetCatalogStatement) explain(mut c Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN SET CATALOG')
}
