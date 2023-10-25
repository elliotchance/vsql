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
//~     <sequence generator start with option>   -> common_sequence_generator_option_1
//~   | <basic sequence generator option>
//~
//~ <basic sequence generator option> /* SequenceGeneratorOption */ ::=
//~     <sequence generator increment by option>   -> basic_sequence_generator_option_1
//~   | <sequence generator maxvalue option>       -> basic_sequence_generator_option_2
//~   | <sequence generator minvalue option>       -> basic_sequence_generator_option_3
//~   | <sequence generator cycle option>          -> basic_sequence_generator_option_4
//~
//~ <sequence generator start with option> /* SequenceGeneratorStartWithOption */ ::=
//~     START WITH
//~     <sequence generator start value>   -> sequence_generator_start_with_option
//~
//~ <sequence generator start value> /* Expr */ ::=
//~     <signed numeric literal>
//~
//~ <sequence generator increment by option> /* SequenceGeneratorIncrementByOption */ ::=
//~     INCREMENT BY
//~     <sequence generator increment>   -> sequence_generator_increment_by_option
//~
//~ <sequence generator increment> /* Expr */ ::=
//~     <signed numeric literal>
//~
//~ <sequence generator maxvalue option> /* SequenceGeneratorMaxvalueOption */ ::=
//~     MAXVALUE
//~     <sequence generator max value>   -> sequence_generator_maxvalue_option_1
//~   | NO MAXVALUE                      -> sequence_generator_maxvalue_option_2
//~
//~ <sequence generator max value> /* Expr */ ::=
//~     <signed numeric literal>
//~
//~ <sequence generator minvalue option> /* SequenceGeneratorMinvalueOption */ ::=
//~     MINVALUE
//~     <sequence generator min value>   -> sequence_generator_minvalue_option_1
//~   | NO MINVALUE                      -> sequence_generator_minvalue_option_2
//~
//~ <sequence generator min value> /* Expr */ ::=
//~     <signed numeric literal>
//~
//~ <sequence generator cycle option> /* bool */ ::=
//~     CYCLE      -> yes
//~   | NO CYCLE   -> no

fn parse_sequence_generator_definition_1(generator_name Identifier) !Stmt {
	return CreateSequenceStmt{
		name: generator_name
	}
}

fn parse_sequence_generator_definition_2(generator_name Identifier, options []SequenceGeneratorOption) !Stmt {
	return CreateSequenceStmt{
		name: generator_name
		options: options
	}
}

fn parse_sequence_generator_increment_by_option(increment_by Expr) !SequenceGeneratorIncrementByOption {
	return SequenceGeneratorIncrementByOption{
		increment_by: increment_by
	}
}

fn parse_sequence_generator_maxvalue_option_1(max_value Expr) !SequenceGeneratorMaxvalueOption {
	return SequenceGeneratorMaxvalueOption{
		max_value: max_value
	}
}

fn parse_sequence_generator_maxvalue_option_2() !SequenceGeneratorMaxvalueOption {
	return SequenceGeneratorMaxvalueOption{
		max_value: NoExpr{}
	}
}

fn parse_sequence_generator_minvalue_option_1(min_value Expr) !SequenceGeneratorMinvalueOption {
	return SequenceGeneratorMinvalueOption{
		min_value: min_value
	}
}

fn parse_sequence_generator_minvalue_option_2() !SequenceGeneratorMinvalueOption {
	return SequenceGeneratorMinvalueOption{
		min_value: NoExpr{}
	}
}

fn parse_sequence_generator_start_with_option(start_value Expr) !SequenceGeneratorStartWithOption {
	return SequenceGeneratorStartWithOption{
		start_value: start_value
	}
}

fn parse_sequence_generator_name(identifier IdentifierChain) !Identifier {
	return new_table_identifier(identifier.identifier)
}

fn parse_basic_sequence_generator_option_1(option SequenceGeneratorIncrementByOption) !SequenceGeneratorOption {
	return option
}

fn parse_basic_sequence_generator_option_2(option SequenceGeneratorMaxvalueOption) !SequenceGeneratorOption {
	return option
}

fn parse_basic_sequence_generator_option_3(option SequenceGeneratorMinvalueOption) !SequenceGeneratorOption {
	return option
}

fn parse_basic_sequence_generator_option_4(option bool) !SequenceGeneratorOption {
	return SequenceGeneratorCycleOption{option}
}

fn parse_common_sequence_generator_option_1(option SequenceGeneratorStartWithOption) !SequenceGeneratorOption {
	return option
}
