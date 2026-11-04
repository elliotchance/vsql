module vsql

import time

// ISO/IEC 9075-2:2016(E), 19.7, <set names statement>
//
// Set the default character set name for <character string literal>s in
// <preparable statement>s that are prepared in the current SQL-session by an
// <execute immediate statement> or a <prepare statement> and in
// <direct SQL statement>s that are invoked directly.
//
// vsql only has UTF-8, which is the character set UTF8 (F461 isn't supported, so
// there's nothing else that can use the name). There's nothing to change.

struct SetNamesStatement {
	value ValueSpecification
}

fn (stmt SetNamesStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	mut c := Compiler{
		conn:   conn
		params: params
	}

	// ISO/IEC 9075-2:2016(E), 19.7, <set names statement>, Syntax Rules, 1
	// ISO/IEC 9075-2:2016(E), 19.7, <set names statement>, General Rules, 1
	value := session_name_value(mut conn, mut c, stmt.value, 'SET NAMES')!

	// ISO/IEC 9075-2:2016(E), 19.7, <set names statement>, General Rules, 2
	name := normalize_identifier(value) or { return sqlstate_2c000(value) }
	if name != 'UTF8' {
		return sqlstate_2c000(value)
	}

	return new_result_msg('SET NAMES', elapsed_parse, t.elapsed())
}

fn (stmt SetNamesStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN SET NAMES')
}
