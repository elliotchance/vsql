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

	check_sequence_options(stmt.options)!

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	name := conn.resolve_schema_identifier(stmt.name)!
	check_writable_schema(name)!
	mut catalog := conn.catalog_for(name)
	old_sequence := catalog.storage.sequence(name)!
	sequence := alter_sequence(mut conn, params, old_sequence, stmt.options)!
	catalog.storage.update_sequence(old_sequence, sequence)!

	return new_result_msg('ALTER SEQUENCE 1', elapsed_parse, t.elapsed())
}

fn (stmt AlterSequenceGeneratorStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN ALTER SEQUENCE')
}

// alter_sequence returns the sequence (an external sequence or the sequence of
// an identity column) with the options of an ALTER (9.31).
fn alter_sequence(mut conn Connection, params map[string]Value, old_sequence Sequence, options []SequenceGeneratorOption) !Sequence {
	mut sequence := old_sequence.copy()
	mut c := Compiler{
		conn:   conn
		params: params
	}
	mut restart_value := ?i64(none)
	mut restart_name := ''
	mut new_min_value := false
	mut new_max_value := false

	for option in options {
		match option {
			SequenceGeneratorStartWithOption {
				// Not possible.
			}
			SequenceGeneratorRestartOption {
				if v := option.restart_value {
					value := (v.compile(mut c)!.run(mut conn, Row{}, map[string]Value{})!).as_int()
					restart_value = value
					restart_name = 'RESTART WITH'
				} else {
					restart_value = sequence.start_value
					restart_name = 'START WITH'
				}
			}
			SequenceGeneratorIncrementByOption {
				sequence.increment_by = (option.increment_by.compile(mut c)!.run(mut conn, Row{},
					map[string]Value{})!).as_int()
			}
			SequenceGeneratorMinvalueOption {
				if v := option.min_value {
					sequence.min_value =
						(v.compile(mut c)!.run(mut conn, Row{}, map[string]Value{})!).as_int()
					sequence.has_min_value = true
					new_min_value = true
				} else {
					sequence.has_min_value = false
				}
			}
			SequenceGeneratorMaxvalueOption {
				if v := option.max_value {
					sequence.max_value =
						(v.compile(mut c)!.run(mut conn, Row{}, map[string]Value{})!).as_int()
					sequence.has_max_value = true
					new_max_value = true
				} else {
					sequence.has_max_value = false
				}
			}
			SequenceGeneratorCycleOption {
				sequence.cycle = option.cycle
			}
		}
	}

	sequence.check()!

	// The current base value is only changed by RESTART (9.31 Syntax Rule 9 and
	// General Rule 2e). It's the last value returned by NEXT VALUE FOR, so the
	// next value uses the new INCREMENT BY. Unless it hasn't been returned yet (a
	// new or restarted sequence), then it's the next value, so current_value
	// must be adjusted for the new INCREMENT BY. These wrap around like add_i64,
	// see Sequence.next.
	if v := restart_value {
		sequence.check_in_range(restart_name, v)!
		sequence.current_value = i64(u64(v) - u64(sequence.increment_by))
		sequence.exhausted = false
		sequence.unused = true
	} else {
		mut next_value := i64(0)
		mut has_next := true
		if old_sequence.unused {
			next_value = i64(u64(old_sequence.current_value) + u64(old_sequence.increment_by))
			sequence.current_value = i64(u64(next_value) - u64(sequence.increment_by))
		} else {
			next_value, sequence.exhausted = add_i64(old_sequence.current_value, sequence.increment_by)
			has_next = !sequence.exhausted
		}

		// The next value must be within a new MINVALUE or MAXVALUE (9.31 Syntax
		// Rule 12). It isn't checked against limits that aren't changed, so CYCLE
		// or NO MAXVALUE can revive a sequence that has gone past its limit.
		if has_next && new_min_value && next_value < sequence.min_value {
			return sqlstate_42601('MINVALUE (${sequence.min_value}) must not be greater than the next value (${next_value})')
		}
		if has_next && new_max_value && next_value > sequence.max_value {
			return sqlstate_42601('MAXVALUE (${sequence.max_value}) must not be less than the next value (${next_value})')
		}
	}

	return sequence
}
