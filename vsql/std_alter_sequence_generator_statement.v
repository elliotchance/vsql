// ISO/IEC 9075-2:2016(E), 11.73, <alter sequence generator statement>

module vsql

// Format
//~
//~ <alter sequence generator statement> /* Stmt */ ::=
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
//~     <alter sequence generator restart option>   -> alter_sequence_generator_option_1
//~   | <basic sequence generator option>
//~
//~ <alter sequence generator restart option> /* SequenceGeneratorRestartOption */ ::=
//~     RESTART                              -> sequence_generator_restart_option_1
//~   | RESTART WITH
//~     <sequence generator restart value>   -> sequence_generator_restart_option_2
//~
//~ <sequence generator restart value> /* Expr */ ::=
//~     <signed numeric literal>

fn parse_alter_sequence_generator_statement(generator_name Identifier, options []SequenceGeneratorOption) !Stmt {
	return AlterSequenceStmt{
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

fn parse_alter_sequence_generator_option_1(option SequenceGeneratorRestartOption) !SequenceGeneratorOption {
	return option
}

fn parse_sequence_generator_restart_option_1() !SequenceGeneratorRestartOption {
	return SequenceGeneratorRestartOption{
		restart_value: NoExpr{}
	}
}

fn parse_sequence_generator_restart_option_2(restart_value Expr) !SequenceGeneratorRestartOption {
	return SequenceGeneratorRestartOption{
		restart_value: restart_value
	}
}
