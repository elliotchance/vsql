// alter_sequence.v contains the implementation for the ALTER SEQUENCE
// statement.

module vsql

import time

fn execute_alter_sequence(mut c Connection, stmt AlterSequenceGeneratorStatement, elapsed_parse time.Duration) !Result {
	t := start_timer()

	c.open_write_connection()!
	defer {
		c.release_write_connection()
	}

	mut catalog := c.catalog()
	name := c.resolve_schema_identifier(stmt.name)!
	old_sequence := catalog.storage.sequence(name)!
	mut sequence := old_sequence.copy()

	for option in stmt.options {
		match option {
			SequenceGeneratorStartWithOption {
				// Not possible.
			}
			SequenceGeneratorRestartOption {
				if v := option.restart_value {
					sequence.current_value = (v.eval(mut c, Row{}, map[string]Value{})!).as_int() - sequence.increment_by
				} else {
					sequence.current_value = sequence.reset() - sequence.increment_by
				}
			}
			SequenceGeneratorIncrementByOption {
				sequence.increment_by = (option.increment_by.eval(mut c, Row{}, map[string]Value{})!).as_int()

				// Since we increment the value after it's returned we need to correct
				// for the current value that takes into account the difference of the
				// new INCREMENT BY.
				sequence.current_value += (sequence.increment_by - old_sequence.increment_by) - 1
			}
			SequenceGeneratorMinvalueOption {
				if v := option.min_value {
					sequence.min_value = (v.eval(mut c, Row{}, map[string]Value{})!).as_int()
					sequence.has_min_value = true
				} else {
					sequence.has_min_value = false
				}
			}
			SequenceGeneratorMaxvalueOption {
				if v := option.max_value {
					sequence.max_value = (v.eval(mut c, Row{}, map[string]Value{})!).as_int()
					sequence.has_max_value = true
				} else {
					sequence.has_min_value = false
				}
			}
			SequenceGeneratorCycleOption {
				sequence.cycle = option.cycle
			}
		}
	}

	catalog.storage.update_sequence(old_sequence, sequence)!

	return new_result_msg('ALTER SEQUENCE 1', elapsed_parse, t.elapsed())
}
