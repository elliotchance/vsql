%%

alter_identity_column_specification:
  alter_identity_column_options {
    $$.v = AlterIdentityColumnSpecification{$1.v as []SequenceGeneratorOption}
  }

alter_identity_column_options:
  alter_identity_column_option { $$.v = [$1.v as SequenceGeneratorOption] }
| alter_identity_column_options alter_identity_column_option {
    $$.v = append_list($1.v as []SequenceGeneratorOption,
      $2.v as SequenceGeneratorOption)
  }

alter_identity_column_option:
  alter_sequence_generator_restart_option {
    $$.v = SequenceGeneratorOption($1.v as SequenceGeneratorRestartOption)
  }
| SET basic_sequence_generator_option {
    $$.v = $2.v as SequenceGeneratorOption
  }

%%
