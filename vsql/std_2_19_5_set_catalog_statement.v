module vsql

import time

// ISO/IEC 9075-2:2016(E), 19.5, <set catalog statement>
//
// Set the default catalog name for unqualified <schema name>s in
// <preparable statement>s that are prepared in the current SQL-session by an
// <execute immediate statement> or a <prepare statement> and in
// <direct SQL statement>s that are invoked directly.
//
// The concept is described by ISO/IEC 9075-1:2003(E), 4.2.8.1, Catalogs.

struct SetCatalogStatement {
	catalog_name ValueSpecification
}

fn (stmt SetCatalogStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// This does not need to hold a write connection with the file.

	mut c := Compiler{
		conn:   conn
		params: params
	}

	// ISO/IEC 9075-2:2016(E), 19.5, <set catalog statement>, Syntax Rules, 1
	// ISO/IEC 9075-2:2016(E), 19.5, <set catalog statement>, General Rules, 1
	value := session_name_value(mut conn, mut c, stmt.catalog_name, 'SET CATALOG')!

	// ISO/IEC 9075-2:2016(E), 19.5, <set catalog statement>, General Rules, 2
	new_catalog := conn.catalog_named(value) or {
		return sqlstate_3d000(value) // catalog does not exist
	}

	// ISO/IEC 9075-2:2016(E), 19.5, <set catalog statement>, General Rules, 3
	conn.current_catalog = new_catalog

	return new_result_msg('SET CATALOG 1', elapsed_parse, t.elapsed())
}

fn (stmt SetCatalogStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN SET CATALOG')
}

// session_name_value is the value of a statement that sets a name for the
// SQL-session, which must be a character string, without the spaces around it.
// NULL is the empty string, which isn't a name.
fn session_name_value(mut conn Connection, mut c Compiler, value ValueSpecification, statement string) !string {
	v := value.compile(mut c)!.run(mut conn, Row{}, map[string]Value{})!
	if !v.typ.uses_string() {
		return sqlstate_42804('for ${statement}', 'character string', v.typ.str())
	}
	if v.is_null {
		return ''
	}

	return v.string_value().trim(' ')
}

// catalog_named is the catalog that a <catalog name> refers to. The name of a
// catalog comes from a file path, so it often isn't an identifier, such as
// ":memory:" or a lower case name. So a value that's exactly the name of a catalog
// is that catalog, otherwise it's an identifier.
fn (conn Connection) catalog_named(value string) ?string {
	if value in conn.catalogs {
		return value
	}

	name := normalize_identifier(value) or { return none }
	if name in conn.catalogs {
		return name
	}

	return none
}
