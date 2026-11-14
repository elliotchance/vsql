module vsql

import math
import time

// ISO/IEC 9075-2:2023, 11.72, <sequence generator definition>
//
// Define an external sequence generator.

type SequenceGeneratorOption = SequenceGeneratorCycleOption
	| SequenceGeneratorDataTypeOption
	| SequenceGeneratorIncrementByOption
	| SequenceGeneratorMaxvalueOption
	| SequenceGeneratorMinvalueOption
	| SequenceGeneratorRestartOption
	| SequenceGeneratorStartWithOption

// SequenceGeneratorDataTypeOption is "AS <data type>", which can only be used
// by CREATE SEQUENCE.
struct SequenceGeneratorDataTypeOption {
	typ Type
}

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
	name          Identifier
	options       []SequenceGeneratorOption
	if_not_exists bool // V106-01, a sequence that already exists isn't an error
}

fn (stmt SequenceGeneratorDefinition) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	msg := if stmt.create(mut conn)! { 'CREATE SEQUENCE 1' } else { 'CREATE SEQUENCE 0' }

	return new_result_msg(msg, elapsed_parse, t.elapsed())
}

// create creates the sequence and returns true, or false if it already exists
// with IF NOT EXISTS. The caller must have the write connection open.
fn (stmt SequenceGeneratorDefinition) create(mut conn Connection) !bool {
	sequence_name := conn.resolve_schema_identifier(stmt.name)!
	check_writable_schema(sequence_name)!
	mut catalog := conn.catalog_for(sequence_name)

	// ISO/IEC 9075-2:2023, 11.72, <sequence generator definition>, Syntax Rules, 3
	if _ := catalog.storage.sequence(sequence_name) {
		// The existing sequence isn't changed (including its current value) or
		// compared with these options, which aren't checked either.
		if stmt.if_not_exists {
			return false
		}

		return sqlstate_42p07('sequence', sequence_name.str()) // duplicate sequence
	}

	check_sequence_options(stmt.options)!
	sequence := stmt.sequence(sequence_name)
	check_sequence_data_type(sequence.typ)!
	sequence.check_data_type()!
	sequence.check_in_range('START WITH', sequence.start_value)!
	catalog.storage.create_sequence(sequence)!

	return true
}

// check_sequence_options checks that each option is only given once and that
// the values are integers in the range of a BIGINT. This is only done for
// CREATE SEQUENCE and ALTER SEQUENCE, not when a sequence is read from the file.
//
// ISO/IEC 9075-2:2023, 9.36, Creation of a sequence generator, Syntax Rules, 3 and 10
// ISO/IEC 9075-2:2023, 9.37, Altering a sequence generator, Syntax Rules, 4 and 10
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
			SequenceGeneratorDataTypeOption {
				'AS', ?Value(none)
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
				// -2^63 is the lowest BIGINT, but 2^63 is one past the highest.
				if f < -9223372036854775808.0 || f >= 9223372036854775808.0 {
					return sqlstate_42601('${name} is out of range for BIGINT: ${v.str()}')
				}
			}
		}
	}
}

// check_sequence_data_type returns an error if t can't be the data type of a
// sequence, which must be an exact numeric type with a scale of 0 (zero).
//
// ISO/IEC 9075-2:2023, 11.72, <sequence generator definition>, Syntax Rules, 6
fn check_sequence_data_type(t Type) ! {
	if t.typ !in [.is_smallint, .is_integer, .is_bigint, .is_decimal, .is_numeric] || t.scale != 0 {
		return sqlstate_42601('sequence data type must be an exact numeric with a scale of 0, not ${t}')
	}
}

// sequence returns the sequence that the definition describes. It's also used
// when reading a sequence definition from the file. The data type is BIGINT by
// default (so a definition without one is the same as before AS was supported).
// The INCREMENT BY is 1 by default, and there's no CYCLE. Without a MINVALUE or MAXVALUE, the limit is
// implicit (see Sequence.min and Sequence.max). Without a START WITH, it's the
// minimum value of an ascending sequence (or the maximum value of a descending
// one), which is 1 (or -1) by default.
//
// ISO/IEC 9075-2:2023, 9.36, Creation of a sequence generator, Syntax Rules, 4 and 6-9
// ISO/IEC 9075-2:2023, 9.36, Creation of a sequence generator, Syntax Rules, 13
// ISO/IEC 9075-2:2023, 11.72, <sequence generator definition>, Syntax Rules, 6
fn (stmt SequenceGeneratorDefinition) sequence(sequence_name Identifier) Sequence {
	mut typ := new_type('BIGINT', 0, 0)
	mut increment_by := i64(1)
	mut has_start_value := false
	mut start_value := i64(0)
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
			SequenceGeneratorDataTypeOption {
				typ = option.typ
			}
		}
	}

	mut sequence := Sequence{
		typ:           typ
		name:          sequence_name
		unused:        true
		increment_by:  increment_by
		cycle:         cycle
		has_min_value: has_min_value
		min_value:     min_value
		has_max_value: has_max_value
		max_value:     max_value
	}
	if !has_start_value {
		start_value = sequence.reset()
	}
	sequence.start_value = start_value
	sequence.current_value = i64(u64(start_value) - u64(increment_by))

	return sequence
}

fn (stmt SequenceGeneratorDefinition) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN CREATE SEQUENCE')
}
