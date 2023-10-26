// set_catalog.v contains the implementation for the SET CATALOG statement.

module vsql

import time

fn execute_set_catalog(mut c Connection, stmt SetCatalogStatement, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// This does not need to hold a write connection with the file.

	new_catalog := stmt.catalog_name.eval(mut c, Row{}, map[string]Value{})!.str()

	if new_catalog !in c.catalogs {
		return sqlstate_3d000(new_catalog) // catalog does not exist
	}

	c.current_catalog = new_catalog

	return new_result_msg('SET CATALOG 1', elapsed_parse, t.elapsed())
}
