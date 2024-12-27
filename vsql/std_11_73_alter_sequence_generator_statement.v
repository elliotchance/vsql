module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.73, <alter sequence generator statement>
//
// Change the definition of an external sequence generator.

struct AlterSequenceGeneratorStatement {
	name    Identifier
	options []SequenceGeneratorOption
}

fn (stmt AlterSequenceGeneratorStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut catalog := conn.catalog()
	name := conn.resolve_schema_identifier(stmt.name)!
	old_sequence := catalog.storage.sequence(name)!
	mut sequence := old_sequence.copy()
	mut c := Compiler{
		conn:   conn
		params: params
	}

	for option in stmt.options {
		match option {
			SequenceGeneratorStartWithOption {
				// Not possible.
			}
			SequenceGeneratorRestartOption {
				if v := option.restart_value {
					sequence.current_value = (v.compile(mut c)!.run(mut conn, Row{}, map[string]Value{})!).as_int() - sequence.increment_by
				} else {
					sequence.current_value = sequence.reset() - sequence.increment_by
				}
			}
			SequenceGeneratorIncrementByOption {
				sequence.increment_by = (option.increment_by.compile(mut c)!.run(mut conn,
					Row{}, map[string]Value{})!).as_int()

				// Since we increment the value after it's returned we need to correct
				// for the current value that takes into account the difference of the
				// new INCREMENT BY.
				sequence.current_value += (sequence.increment_by - old_sequence.increment_by) - 1
			}
			SequenceGeneratorMinvalueOption {
				if v := option.min_value {
					sequence.min_value = (v.compile(mut c)!.run(mut conn, Row{}, map[string]Value{})!).as_int()
					sequence.has_min_value = true
				} else {
					sequence.has_min_value = false
				}
			}
			SequenceGeneratorMaxvalueOption {
				if v := option.max_value {
					sequence.max_value = (v.compile(mut c)!.run(mut conn, Row{}, map[string]Value{})!).as_int()
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

fn (stmt AlterSequenceGeneratorStatement) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN ALTER SEQUENCE')
}
