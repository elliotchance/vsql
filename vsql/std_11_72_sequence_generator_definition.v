module vsql

import math
import time

// ISO/IEC 9075-2:2016(E), 11.72, <sequence generator definition>
//
// Define an external sequence generator.

type SequenceGeneratorOption = SequenceGeneratorCycleOption
	| SequenceGeneratorIncrementByOption
	| SequenceGeneratorMaxvalueOption
	| SequenceGeneratorMinvalueOption
	| SequenceGeneratorRestartOption
	| SequenceGeneratorStartWithOption

struct SequenceGeneratorStartWithOption {
	start_value Value
}

struct SequenceGeneratorRestartOption {
	restart_value ?Value
}

struct SequenceGeneratorIncrementByOption {
	increment_by Value
}

struct SequenceGeneratorMinvalueOption {
	min_value ?Value // not set = NO MINVALUE
}

struct SequenceGeneratorMaxvalueOption {
	max_value ?Value // not set = NO MAXVALUE
}

struct SequenceGeneratorCycleOption {
	cycle bool
}

struct SequenceGeneratorDefinition {
	name    Identifier
	options []SequenceGeneratorOption
}

fn (stmt SequenceGeneratorDefinition) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	check_sequence_options(stmt.options)!

	mut catalog := conn.catalog()
	sequence_name := conn.resolve_schema_identifier(stmt.name)!

	// ISO/IEC 9075-2:2016(E), 11.72, <sequence generator definition>, Syntax
	// Rules, 3
	if _ := catalog.storage.sequence(sequence_name) {
		return sqlstate_42p07('sequence', sequence_name.str()) // duplicate sequence
	}

	sequence := stmt.sequence(sequence_name)
	sequence.check()!
	sequence.check_in_range('START WITH', sequence.start_value)!
	catalog.storage.create_sequence(sequence)!

	return new_result_msg('CREATE SEQUENCE 1', elapsed_parse, t.elapsed())
}

// check_sequence_options checks that each option is only given once and that
// the values are integers (9.30 and 9.31 Syntax Rules). This is only done for
// CREATE SEQUENCE and ALTER SEQUENCE, not when a sequence is read from the
// file.
fn check_sequence_options(options []SequenceGeneratorOption) ! {
	mut seen := map[string]bool{}
	for option in options {
		name, value := match option {
			SequenceGeneratorStartWithOption {
				'START WITH', ?Value(option.start_value)
			}
			SequenceGeneratorRestartOption {
				'RESTART', option.restart_value
			}
			SequenceGeneratorIncrementByOption {
				'INCREMENT BY', ?Value(option.increment_by)
			}
			SequenceGeneratorMinvalueOption {
				'MINVALUE', option.min_value
			}
			SequenceGeneratorMaxvalueOption {
				'MAXVALUE', option.max_value
			}
			SequenceGeneratorCycleOption {
				'CYCLE', ?Value(none)
			}
		}

		if name in seen {
			return sqlstate_42601('${name} is specified more than once')
		}
		seen[name] = true

		if v := value {
			if !v.typ.uses_int() {
				f := v.as_f64()!
				if f != math.floor(f) {
					return sqlstate_42601('${name} must be an integer: ${v.str()}')
				}
			}
		}
	}
}

// sequence returns the sequence that the definition describes. It's also used
// when reading a sequence definition from the file.
fn (stmt SequenceGeneratorDefinition) sequence(sequence_name Identifier) Sequence {
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
				start_value = option.start_value.as_int()
				has_start_value = true
			}
			SequenceGeneratorRestartOption {
				// Not possible.
			}
			SequenceGeneratorIncrementByOption {
				increment_by = option.increment_by.as_int()
			}
			SequenceGeneratorMinvalueOption {
				if v := option.min_value {
					min_value = v.as_int()
					has_min_value = true
				}
			}
			SequenceGeneratorMaxvalueOption {
				if v := option.max_value {
					max_value = v.as_int()
					has_max_value = true
				}
			}
			SequenceGeneratorCycleOption {
				cycle = option.cycle
			}
		}
	}

	is_ascending := increment_by >= 0
	if !has_start_value {
		if is_ascending && has_min_value {
			start_value = min_value
		} else if !is_ascending && has_max_value {
			start_value = max_value
		}
	}

	return Sequence{
		name:          sequence_name
		start_value:   start_value
		current_value: start_value - increment_by
		increment_by:  increment_by
		cycle:         cycle
		has_min_value: has_min_value
		min_value:     min_value
		has_max_value: has_max_value
		max_value:     max_value
	}
}

fn (stmt SequenceGeneratorDefinition) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN CREATE SEQUENCE')
}
