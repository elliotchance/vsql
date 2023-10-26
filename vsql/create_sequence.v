// create_sequence.v contains the implementation for the CREATE SEQUENCE
// statement.

module vsql

import time

fn execute_create_sequence(mut c Connection, stmt SequenceGeneratorDefinition, elapsed_parse time.Duration) !Result {
	t := start_timer()

	c.open_write_connection()!
	defer {
		c.release_write_connection()
	}

	mut catalog := c.catalog()
	mut sequence_name := c.resolve_schema_identifier(stmt.name)!
	mut increment_by := i64(1)
	mut has_start_value := false
	mut start_value := i64(1)
	mut has_min_value := false
	mut min_value := i64(0)
	mut has_max_value := false
	mut max_value := i64(0)
	mut cycle := false
	for option in stmt.options {
		match option {
			SequenceGeneratorStartWithOption {
				start_value = (option.start_value.eval(mut c, Row{}, map[string]Value{})!).as_int()
				has_start_value = true
			}
			SequenceGeneratorRestartOption {
				// Not possible.
			}
			SequenceGeneratorIncrementByOption {
				increment_by = (option.increment_by.eval(mut c, Row{}, map[string]Value{})!).as_int()
			}
			SequenceGeneratorMinvalueOption {
				if v := option.min_value {
					min_value = (v.eval(mut c, Row{}, map[string]Value{})!).as_int()
					has_min_value = true
				}
			}
			SequenceGeneratorMaxvalueOption {
				if v := option.max_value {
					max_value = (v.eval(mut c, Row{}, map[string]Value{})!).as_int()
					has_max_value = true
				}
			}
			SequenceGeneratorCycleOption {
				cycle = option.cycle
			}
		}
	}

	is_ascending := increment_by >= 0
	current_value := match true {
		has_start_value {
			start_value - increment_by
		}
		is_ascending && has_min_value {
			min_value - increment_by
		}
		!is_ascending && has_max_value {
			max_value - increment_by
		}
		else {
			1 - increment_by
		}
	}

	sequence := Sequence{
		name: sequence_name
		current_value: current_value
		increment_by: increment_by
		cycle: cycle
		has_min_value: has_min_value
		min_value: min_value
		has_max_value: has_max_value
		max_value: max_value
	}

	catalog.storage.create_sequence(sequence)!

	return new_result_msg('CREATE SEQUENCE 1', elapsed_parse, t.elapsed())
}
