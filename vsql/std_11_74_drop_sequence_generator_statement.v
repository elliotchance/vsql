module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.74, <drop sequence generator statement>
//
// Destroy an external sequence generator.

struct DropSequenceGeneratorStatement {
	sequence_name Identifier
}

fn (stmt DropSequenceGeneratorStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut catalog := conn.catalog()
	name := conn.resolve_schema_identifier(stmt.sequence_name)!
	sequence := catalog.storage.sequence(name)!
	catalog.storage.delete_sequence(name, sequence.tid)!

	return new_result_msg('DROP SEQUENCE 1', elapsed_parse, t.elapsed())
}

fn (stmt DropSequenceGeneratorStatement) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN DROP SEQUENCE')
}
