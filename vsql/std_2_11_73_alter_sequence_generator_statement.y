%%

alter_sequence_generator_statement:
  ALTER SEQUENCE sequence_generator_name alter_sequence_generator_options {
    $$.v = AlterSequenceGeneratorStatement{
      name:    $3.v as Identifier
      options: $4.v as []SequenceGeneratorOption
    }
  }

alter_sequence_generator_options:
  alter_sequence_generator_option { $$.v = [$1.v as SequenceGeneratorOption] }
| alter_sequence_generator_options alter_sequence_generator_option {
    $$.v = append_list($1.v as []SequenceGeneratorOption,
      $2.v as SequenceGeneratorOption)
  }

alter_sequence_generator_option:
  alter_sequence_generator_restart_option {
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
