module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.74, <drop sequence generator statement>
//
// Destroy an external sequence generator.

// The behavior is RESTRICT when it's not provided (the standard requires it).
// Nothing can depend on a sequence yet (such as a column default), so CASCADE
// and RESTRICT are the same.
struct DropSequenceGeneratorStatement {
	sequence_name Identifier
	behavior      string // CASCADE or RESTRICT
}

fn (stmt DropSequenceGeneratorStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	name := conn.resolve_schema_identifier(stmt.sequence_name)!
	mut catalog := conn.catalog_for(name)
	sequence := catalog.storage.sequence(name)!
	catalog.storage.delete_sequence(name, sequence.tid)!

	return new_result_msg('DROP SEQUENCE 1', elapsed_parse, t.elapsed())
}

fn (stmt DropSequenceGeneratorStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN DROP SEQUENCE')
}
