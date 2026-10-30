%%

// ISO/IEC 9075-2:2016(E), 11.73, <alter sequence generator statement>, Conformance Rules, 1
alter_sequence_generator_statement:
  ALTER SEQUENCE sequence_generator_name alter_sequence_generator_options {
    flag(mut yylex, 'T176')
    $$.v = AlterSequenceGeneratorStatement{
      name:    $3.v as Identifier
      options: $4.v as []SequenceGeneratorOption
    }
  }

// ISO/IEC 9075-2:2016(E), 9.31, Altering a sequence generator, Syntax Rules, 2
alter_sequence_generator_options:
  alter_sequence_generator_option { $$.v = [$1.v as SequenceGeneratorOption] }
| alter_sequence_generator_options alter_sequence_generator_option {
    $$.v = append_list($1.v as []SequenceGeneratorOption,
      $2.v as SequenceGeneratorOption)
  }

// ISO/IEC 9075-2:2016(E), 11.73, <alter sequence generator statement>, Conformance Rules, 2
alter_sequence_generator_option:
  alter_sequence_generator_restart_option {
    flag_if(mut yylex, ($1.v as SequenceGeneratorRestartOption).restart_value == none,
      'T177')
    $$.v = SequenceGeneratorOption($1.v as SequenceGeneratorRestartOption)
  }
| basic_sequence_generator_option { $$.v = $1.v as SequenceGeneratorOption }

alter_sequence_generator_restart_option:
  RESTART { $$.v = SequenceGeneratorRestartOption{} }
| RESTART WITH sequence_generator_restart_value {
    $$.v = SequenceGeneratorRestartOption{
      restart_value: $3.v as Value
    }
  }

sequence_generator_restart_value:
  signed_numeric_literal { $$.v = $1.v as Value }

%%
