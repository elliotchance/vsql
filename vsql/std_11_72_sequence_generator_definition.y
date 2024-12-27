%%

sequence_generator_definition:
  CREATE SEQUENCE sequence_generator_name {
    $$.v = SequenceGeneratorDefinition{
      name: $3.v as Identifier
    }
  }
| CREATE SEQUENCE sequence_generator_name sequence_generator_options {
    $$.v = SequenceGeneratorDefinition{
      name:    $3.v as Identifier
      options: $4.v as []SequenceGeneratorOption
    }
  }

sequence_generator_options:
  sequence_generator_option { $$.v = $1.v as []SequenceGeneratorOption }
| sequence_generator_options sequence_generator_option {
    $$.v = $1.v as []SequenceGeneratorOption
  }

sequence_generator_option:
  common_sequence_generator_options { $$.v = $1.v as []SequenceGeneratorOption }

common_sequence_generator_options:
  common_sequence_generator_option { $$.v = [$1.v as SequenceGeneratorOption] }
| common_sequence_generator_options common_sequence_generator_option {
    $$.v = append_list($1.v as []SequenceGeneratorOption,
      $2.v as SequenceGeneratorOption)
  }

common_sequence_generator_option:
  sequence_generator_start_with_option {
    $$.v = SequenceGeneratorOption($1.v as SequenceGeneratorStartWithOption)
  }
| basic_sequence_generator_option { $$.v = $1.v as SequenceGeneratorOption }

basic_sequence_generator_option:
  sequence_generator_increment_by_option {
    $$.v = SequenceGeneratorOption($1.v as SequenceGeneratorIncrementByOption)
  }
| sequence_generator_maxvalue_option {
    $$.v = SequenceGeneratorOption($1.v as SequenceGeneratorMaxvalueOption)
  }
| sequence_generator_minvalue_option {
    $$.v = SequenceGeneratorOption($1.v as SequenceGeneratorMinvalueOption)
  }
| sequence_generator_cycle_option {
    $$.v = SequenceGeneratorOption(SequenceGeneratorCycleOption{$1.v as bool})
  }

sequence_generator_start_with_option:
  START WITH sequence_generator_start_value {
    $$.v = SequenceGeneratorStartWithOption{
      start_value: $3.v as Value
    }
  }

sequence_generator_start_value:
  signed_numeric_literal { $$.v = $1.v as Value }

sequence_generator_increment_by_option:
  INCREMENT BY sequence_generator_increment {
    $$.v = SequenceGeneratorIncrementByOption{
      increment_by: $3.v as Value
    }
  }

sequence_generator_increment:
  signed_numeric_literal { $$.v = $1.v as Value }

sequence_generator_maxvalue_option:
  MAXVALUE sequence_generator_max_value {
    $$.v = SequenceGeneratorMaxvalueOption{
      max_value: $2.v as Value
    }
  }
| NO MAXVALUE { $$.v = SequenceGeneratorMaxvalueOption{} }

sequence_generator_max_value:
  signed_numeric_literal { $$.v = $1.v as Value }

sequence_generator_minvalue_option:
  MINVALUE sequence_generator_min_value {
    $$.v = SequenceGeneratorMinvalueOption{
      min_value: $2.v as Value
    }
  }
| NO MINVALUE { $$.v = SequenceGeneratorMinvalueOption{} }

sequence_generator_min_value:
  signed_numeric_literal { $$.v = $1.v as Value }

sequence_generator_cycle_option:
  CYCLE { $$.v = true }
| NO CYCLE { $$.v = false }

%%
