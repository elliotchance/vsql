module vsql

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

	mut c := Compiler{
		conn:   conn
		params: params
	}
	mut catalog := conn.catalog()
	mut sequence_name := conn.resolve_schema_identifier(stmt.name)!
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
				start_value = (option.start_value.compile(mut c)!.run(mut conn, Row{},
					map[string]Value{})!).as_int()
				has_start_value = true
			}
			SequenceGeneratorRestartOption {
				// Not possible.
			}
			SequenceGeneratorIncrementByOption {
				increment_by = (option.increment_by.compile(mut c)!.run(mut conn, Row{},
					map[string]Value{})!).as_int()
			}
			SequenceGeneratorMinvalueOption {
				if v := option.min_value {
					min_value = (v.compile(mut c)!.run(mut conn, Row{}, map[string]Value{})!).as_int()
					has_min_value = true
				}
			}
			SequenceGeneratorMaxvalueOption {
				if v := option.max_value {
					max_value = (v.compile(mut c)!.run(mut conn, Row{}, map[string]Value{})!).as_int()
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
		name:          sequence_name
		current_value: current_value
		increment_by:  increment_by
		cycle:         cycle
		has_min_value: has_min_value
		min_value:     min_value
		has_max_value: has_max_value
		max_value:     max_value
	}

	catalog.storage.create_sequence(sequence)!

	return new_result_msg('CREATE SEQUENCE 1', elapsed_parse, t.elapsed())
}

fn (stmt SequenceGeneratorDefinition) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN CREATE SEQUENCE')
}
