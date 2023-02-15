// alter_sequence.v contains the implementation for the ALTER SEQUENCE
// statement.

module vsql

import time

fn execute_alter_sequence(mut c Connection, stmt AlterSequenceStmt, elapsed_parse time.Duration) !Result {
	t := start_timer()

	c.open_write_connection()!
	defer {
		c.release_write_connection()
	}

	mut sequence_name := stmt.name.str()

	// TODO(elliotchance): This isn't really ideal. Replace with a proper
	//  identifier chain when we support that.
	if sequence_name.contains('.') {
		parts := sequence_name.split('.')

		if parts[0] !in c.storage.schemas {
			return sqlstate_3f000(parts[0]) // scheme does not exist
		}
	} else {
		sequence_name = 'PUBLIC.${sequence_name}'
	}

	old_sequence := c.storage.sequence(stmt.name)!
	mut sequence := old_sequence.copy()

	for option in stmt.options {
		match option {
			SequenceGeneratorStartWithOption {
				// Not possible.
			}
			SequenceGeneratorRestartOption {
				if option.restart_value is NoExpr {
					sequence.current_value = sequence.reset() - sequence.increment_by
				} else {
					sequence.current_value = (eval_as_value(mut c, Row{}, option.restart_value,
						map[string]Value{})!).as_int() - sequence.increment_by
				}
			}
			SequenceGeneratorIncrementByOption {
				sequence.increment_by = (eval_as_value(mut c, Row{}, option.increment_by,
					map[string]Value{})!).as_int()

				// Since we increment the value after it's returned we need to correct
				// for the current value that takes into account the difference of the
				// new INCREMENT BY.
				sequence.current_value += (sequence.increment_by - old_sequence.increment_by) - 1
			}
			SequenceGeneratorMinvalueOption {
				if option.min_value is NoExpr {
					sequence.has_min_value = false
				} else {
					sequence.min_value = (eval_as_value(mut c, Row{}, option.min_value,
						map[string]Value{})!).as_int()
					sequence.has_min_value = true
				}
			}
			SequenceGeneratorMaxvalueOption {
				if option.max_value is NoExpr {
					sequence.has_min_value = false
				} else {
					sequence.max_value = (eval_as_value(mut c, Row{}, option.max_value,
						map[string]Value{})!).as_int()
					sequence.has_max_value = true
				}
			}
			SequenceGeneratorCycleOption {
				sequence.cycle = option.cycle
			}
		}
	}

	c.storage.update_sequence(old_sequence, sequence)!

	return new_result_msg('ALTER SEQUENCE 1', elapsed_parse, t.elapsed())
}
