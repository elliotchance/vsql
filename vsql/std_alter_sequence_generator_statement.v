module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.73, <alter sequence generator statement>
//
// # Function
//
// Change the definition of an external sequence generator.
//
// # Format
//~
//~ <alter sequence generator statement> /* AlterSequenceGeneratorStatement */ ::=
//~     ALTER SEQUENCE
//~     <sequence generator name>
//~     <alter sequence generator options>   -> alter_sequence_generator_statement
//~
//~ <alter sequence generator options> /* []SequenceGeneratorOption */ ::=
//~     <alter sequence generator option>   -> sequence_generator_options_1
//~   | <alter sequence generator options>
//~     <alter sequence generator option>   -> sequence_generator_options_2
//~
//~ <alter sequence generator option> /* SequenceGeneratorOption */ ::=
//~     <alter sequence generator restart option>   -> SequenceGeneratorOption
//~   | <basic sequence generator option>
//~
//~ <alter sequence generator restart option> /* SequenceGeneratorRestartOption */ ::=
//~     RESTART                              -> sequence_generator_restart_option_1
//~   | RESTART WITH
//~     <sequence generator restart value>   -> sequence_generator_restart_option_2
//~
//~ <sequence generator restart value> /* Value */ ::=
//~     <signed numeric literal>

struct AlterSequenceGeneratorStatement {
	name    Identifier
	options []SequenceGeneratorOption
}

fn parse_alter_sequence_generator_statement(generator_name Identifier, options []SequenceGeneratorOption) !AlterSequenceGeneratorStatement {
	return AlterSequenceGeneratorStatement{
		name: generator_name
		options: options
	}
}

fn parse_sequence_generator_options_1(option SequenceGeneratorOption) ![]SequenceGeneratorOption {
	return [option]
}

fn parse_sequence_generator_options_2(options []SequenceGeneratorOption, option SequenceGeneratorOption) ![]SequenceGeneratorOption {
	mut new_options := options.clone()
	new_options << option
	return new_options
}

fn parse_sequence_generator_restart_option_1() !SequenceGeneratorRestartOption {
	return SequenceGeneratorRestartOption{
		restart_value: none
	}
}

fn parse_sequence_generator_restart_option_2(restart_value Value) !SequenceGeneratorRestartOption {
	return SequenceGeneratorRestartOption{
		restart_value: restart_value
	}
}

fn (stmt AlterSequenceGeneratorStatement) execute(mut c Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
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

fn (stmt AlterSequenceGeneratorStatement) explain(mut c Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN ALTER SEQUENCE')
}
