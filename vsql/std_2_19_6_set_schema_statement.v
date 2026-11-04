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

	// ISO/IEC 9075-2:2016(E), 19.6, <set schema statement>, Syntax Rules, 1
	// ISO/IEC 9075-2:2016(E), 19.6, <set schema statement>, General Rules, 1
	value := session_name_value(mut conn, mut c, stmt.schema_name, 'SET SCHEMA')!

	// The value is a <schema name>, so 'foo' is the regular identifier FOO, and
	// '"foo"' is needed for a lower case name. It can have a catalog name.
	//
	// ISO/IEC 9075-2:2016(E), 19.6, <set schema statement>, General Rules, 2
	parts := split_name_parts(value)
	if parts.len > 2 {
		return sqlstate_3f000(value)
	}
	new_schema := normalize_identifier(parts.last()) or { return sqlstate_3f000(value) }
	new_catalog := if parts.len == 2 {
		conn.catalog_named(parts[0]) or { return sqlstate_3d000(parts[0]) }
	} else {
		conn.current_catalog
	}

	// The schema must exist in that catalog.
	//
	// ISO/IEC 9075-2:2016(E), 19.6, <set schema statement>, General Rules, 3.a
	catalog := conn.catalogs[new_catalog] or { return sqlstate_3d000(new_catalog) }
	if new_schema !in catalog.storage.schemas && new_schema != information_schema_name {
		return sqlstate_3f000(new_schema) // schema does not exist
	}

	// ISO/IEC 9075-2:2016(E), 19.6, <set schema statement>, General Rules, 3.b
	conn.current_catalog = new_catalog
	conn.current_schema = new_schema

	return new_result_msg('SET SCHEMA 1', elapsed_parse, t.elapsed())
}

fn (stmt SetSchemaStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN SET SCHEMA')
}

// split_name_parts splits a name at each period that isn't in a delimited
// identifier. The parts aren't checked, or changed in any way.
fn split_name_parts(s string) []string {
	mut parts := []string{}
	mut start := 0
	mut is_delimited := false
	for i, c in s {
		if c == `"` {
			is_delimited = !is_delimited
		} else if c == `.` && !is_delimited {
			parts << s[start..i]
			start = i + 1
		}
	}
	parts << s[start..]

	return parts
}
