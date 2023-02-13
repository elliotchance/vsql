// drop_sequence.v contains the implementation for the DROP SEQUENCE statement.

module vsql

import time

fn execute_drop_sequence(mut c Connection, stmt DropSequenceStmt, elapsed_parse time.Duration) !Result {
	t := start_timer()

	c.open_write_connection()!
	defer {
		c.release_write_connection()
	}

	sequence := c.storage.sequence(stmt.sequence_name)!

	sequence_name := stmt.sequence_name.name
	c.storage.delete_sequence(sequence_name, sequence.tid)!

	return new_result_msg('DROP SEQUENCE 1', elapsed_parse, t.elapsed())
}
