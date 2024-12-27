module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.72, <sequence generator definition>
//
// # Function
//
// Define an external sequence generator.
//
// # Format
//~
//~ <sequence generator definition> /* Stmt */ ::=
//~     CREATE SEQUENCE
//~     <sequence generator name>                   -> sequence_generator_definition_1
//~   | CREATE SEQUENCE <sequence generator name>
//~     <sequence generator options>                -> sequence_generator_definition_2
//~
//~ <sequence generator options> /* []SequenceGeneratorOption */ ::=
//~     <sequence generator option>
//~   | <sequence generator options> <sequence generator option>
//~
//~ <sequence generator option> /* []SequenceGeneratorOption */ ::=
//~     <common sequence generator options>
//~
//~ <common sequence generator options> /* []SequenceGeneratorOption */ ::=
//~     <common sequence generator option>    -> sequence_generator_options_1
//~   | <common sequence generator options>
//~     <common sequence generator option>    -> sequence_generator_options_2
//~
//~ <common sequence generator option> /* SequenceGeneratorOption */ ::=
//~     <sequence generator start with option>   -> SequenceGeneratorOption
//~   | <basic sequence generator option>
//~
//~ <basic sequence generator option> /* SequenceGeneratorOption */ ::=
//~     <sequence generator increment by option>   -> SequenceGeneratorOption
//~   | <sequence generator maxvalue option>       -> SequenceGeneratorOption
//~   | <sequence generator minvalue option>       -> SequenceGeneratorOption
//~   | <sequence generator cycle option>          -> basic_sequence_generator_option_4
//~
//~ <sequence generator start with option> /* SequenceGeneratorStartWithOption */ ::=
//~     START WITH
//~     <sequence generator start value>   -> sequence_generator_start_with_option
//~
//~ <sequence generator start value> /* Value */ ::=
//~     <signed numeric literal>
//~
//~ <sequence generator increment by option> /* SequenceGeneratorIncrementByOption */ ::=
//~     INCREMENT BY
//~     <sequence generator increment>   -> sequence_generator_increment_by_option
//~
//~ <sequence generator increment> /* Value */ ::=
//~     <signed numeric literal>
//~
//~ <sequence generator maxvalue option> /* SequenceGeneratorMaxvalueOption */ ::=
//~     MAXVALUE
//~     <sequence generator max value>   -> sequence_generator_maxvalue_option_1
//~   | NO MAXVALUE                      -> sequence_generator_maxvalue_option_2
//~
//~ <sequence generator max value> /* Value */ ::=
//~     <signed numeric literal>
//~
//~ <sequence generator minvalue option> /* SequenceGeneratorMinvalueOption */ ::=
//~     MINVALUE
//~     <sequence generator min value>   -> sequence_generator_minvalue_option_1
//~   | NO MINVALUE                      -> sequence_generator_minvalue_option_2
//~
//~ <sequence generator min value> /* Value */ ::=
//~     <signed numeric literal>
//~
//~ <sequence generator cycle option> /* bool */ ::=
//~     CYCLE      -> yes
//~   | NO CYCLE   -> no

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

fn parse_sequence_generator_definition_1(generator_name Identifier) !Stmt {
	return SequenceGeneratorDefinition{
		name: generator_name
	}
}

fn parse_sequence_generator_definition_2(generator_name Identifier, options []SequenceGeneratorOption) !Stmt {
	return SequenceGeneratorDefinition{
		name:    generator_name
		options: options
	}
}

fn parse_sequence_generator_increment_by_option(increment_by Value) !SequenceGeneratorIncrementByOption {
	return SequenceGeneratorIncrementByOption{
		increment_by: increment_by
	}
}

fn parse_sequence_generator_maxvalue_option_1(max_value Value) !SequenceGeneratorMaxvalueOption {
	return SequenceGeneratorMaxvalueOption{
		max_value: max_value
	}
}

fn parse_sequence_generator_maxvalue_option_2() !SequenceGeneratorMaxvalueOption {
	return SequenceGeneratorMaxvalueOption{
		max_value: none
	}
}

fn parse_sequence_generator_minvalue_option_1(min_value Value) !SequenceGeneratorMinvalueOption {
	return SequenceGeneratorMinvalueOption{
		min_value: min_value
	}
}

fn parse_sequence_generator_minvalue_option_2() !SequenceGeneratorMinvalueOption {
	return SequenceGeneratorMinvalueOption{
		min_value: none
	}
}

fn parse_sequence_generator_start_with_option(start_value Value) !SequenceGeneratorStartWithOption {
	return SequenceGeneratorStartWithOption{
		start_value: start_value
	}
}

fn parse_sequence_generator_name(identifier IdentifierChain) !Identifier {
	return new_table_identifier(identifier.identifier)
}

fn parse_basic_sequence_generator_option_4(option bool) !SequenceGeneratorOption {
	return SequenceGeneratorCycleOption{option}
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
