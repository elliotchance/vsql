// drop_sequence.v contains the implementation for the DROP SEQUENCE statement.

module vsql

import time

fn execute_drop_sequence(mut c Connection, stmt DropSequenceGeneratorStatement, elapsed_parse time.Duration) !Result {
	t := start_timer()

	c.open_write_connection()!
	defer {
		c.release_write_connection()
	}

	mut catalog := c.catalog()
	name := c.resolve_schema_identifier(stmt.sequence_name)!
	sequence := catalog.storage.sequence(name)!
	catalog.storage.delete_sequence(name, sequence.tid)!

	return new_result_msg('DROP SEQUENCE 1', elapsed_parse, t.elapsed())
}
