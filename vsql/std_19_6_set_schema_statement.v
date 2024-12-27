module vsql

import time

// ISO/IEC 9075-2:2016(E), 19.6, <set schema statement>
//
// Set the default schema name for unqualified <schema qualified name>s in
// <preparable statement>s that are prepared in the current SQL-session by an
// <execute immediate statement> or a <prepare statement> and in
// <direct SQL statement>s that are invoked directly.

struct SetSchemaStatement {
	schema_name ValueSpecification
}

fn (e SetSchemaStatement) pstr(params map[string]Value) string {
	return 'SET SCHEMA ${e.schema_name.pstr(params)}'
}

fn (stmt SetSchemaStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// This does not need to hold a write connection with the file.

	mut c := Compiler{
		conn:   conn
		params: params
	}
	new_schema := stmt.schema_name.compile(mut c)!.run(mut conn, Row{}, map[string]Value{})!.str()

	if new_schema !in conn.catalog().storage.schemas {
		return sqlstate_3f000(new_schema) // schema does not exist
	}

	conn.current_schema = new_schema

	return new_result_msg('SET SCHEMA 1', elapsed_parse, t.elapsed())
}

fn (stmt SetSchemaStatement) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN SET SCHEMA')
}
