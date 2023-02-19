// set_schema.v contains the implementation for the SET SCHEMA statement.

module vsql

import time

fn execute_set_schema(mut c Connection, stmt SetSchemaStmt, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// This does not need to hold a write connection with the file.

	new_schema := eval_as_value(mut c, Row{}, stmt.schema_name, map[string]Value{})!.str()

	if new_schema !in c.catalog().storage.schemas {
		return sqlstate_3f000(new_schema) // schema does not exist
	}

	c.current_schema = new_schema

	return new_result_msg('SET SCHEMA 1', elapsed_parse, t.elapsed())
}
