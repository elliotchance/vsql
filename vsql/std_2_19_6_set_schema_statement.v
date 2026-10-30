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

fn (stmt SetSchemaStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// This does not need to hold a write connection with the file.

	mut c := Compiler{
		conn:   conn
		params: params
	}
	new_schema := stmt.schema_name.compile(mut c)!.run(mut conn, Row{}, map[string]Value{})!.str()

	// The value (of any type) is the name of a schema of the current catalog as
	// it is. It isn't trimmed, or an identifier (so 'x' isn't the schema X), it
	// can't have a catalog name, and the schema must exist (#231).
	//
	// ISO/IEC 9075-2:2016(E), 19.6, <set schema statement>, Syntax Rules, 1
	// ISO/IEC 9075-2:2016(E), 19.6, <set schema statement>, General Rules, 1, 2 and 3.a
	if new_schema !in conn.catalog().storage.schemas && new_schema != information_schema_name {
		return sqlstate_3f000(new_schema) // schema does not exist
	}

	// ISO/IEC 9075-2:2016(E), 19.6, <set schema statement>, General Rules, 3.b
	conn.current_schema = new_schema

	return new_result_msg('SET SCHEMA 1', elapsed_parse, t.elapsed())
}

fn (stmt SetSchemaStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN SET SCHEMA')
}
