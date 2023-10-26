// ISO/IEC 9075-2:2016(E), 11.72, <sequence generator definition>

module vsql

// Format
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
		name: generator_name
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
