%%

// ISO/IEC 9075-2:2023(E), 11.72, <sequence generator definition>, Conformance Rules, 1
sequence_generator_definition:
  CREATE SEQUENCE sequence_generator_name {
    flag(mut yylex, 'T176')
    $$.v = yy_box(SequenceGeneratorDefinition{
      name: $3.v as Identifier
    })
  }
| CREATE SEQUENCE sequence_generator_name sequence_generator_options {
    flag(mut yylex, 'T176')
    $$.v = yy_box(SequenceGeneratorDefinition{
      name:    $3.v as Identifier
      options: $4.v as []SequenceGeneratorOption
    })
  }
| CREATE SEQUENCE if_not_exists sequence_generator_name {
    flag(mut yylex, 'T176')
    flag(mut yylex, vsql_create_sequence_if_not_exists)
    $$.v = yy_box(SequenceGeneratorDefinition{
      name:          $4.v as Identifier
      if_not_exists: true
    })
  }
| CREATE SEQUENCE if_not_exists sequence_generator_name sequence_generator_options {
    flag(mut yylex, 'T176')
    flag(mut yylex, vsql_create_sequence_if_not_exists)
    $$.v = yy_box(SequenceGeneratorDefinition{
      name:          $4.v as Identifier
      options:       $5.v as []SequenceGeneratorOption
      if_not_exists: true
    })
  }

// <common sequence generator options> is already a list, so each option is a
// single <common sequence generator option> here, otherwise the grammar would be
// ambiguous.
sequence_generator_options:
  sequence_generator_option { $$.v = yy_box([$1.v as SequenceGeneratorOption]) }
| sequence_generator_options sequence_generator_option {
    $$.v = yy_box(append_list($1.v as []SequenceGeneratorOption,
      $2.v as SequenceGeneratorOption))
  }

sequence_generator_option:
  sequence_generator_data_type_option { $$.v = $1.v }
| common_sequence_generator_option { $$.v = $1.v }

sequence_generator_data_type_option:
  AS data_type {
    $$.v = yy_box(SequenceGeneratorOption(SequenceGeneratorDataTypeOption{
      typ: $2.v as Type
    }))
  }

// ISO/IEC 9075-2:2023(E), 9.36, Creation of a sequence generator, Syntax Rules, 2
common_sequence_generator_options:
  common_sequence_generator_option { $$.v = yy_box([$1.v as SequenceGeneratorOption]) }
| common_sequence_generator_options common_sequence_generator_option {
    $$.v = yy_box(append_list($1.v as []SequenceGeneratorOption,
      $2.v as SequenceGeneratorOption))
  }

common_sequence_generator_option:
  sequence_generator_start_with_option {
    $$.v = yy_box(SequenceGeneratorOption($1.v as SequenceGeneratorStartWithOption))
  }
| basic_sequence_generator_option { $$.v = $1.v }

basic_sequence_generator_option:
  sequence_generator_increment_by_option {
    $$.v = yy_box(SequenceGeneratorOption($1.v as SequenceGeneratorIncrementByOption))
  }
| sequence_generator_maxvalue_option {
    $$.v = yy_box(SequenceGeneratorOption($1.v as SequenceGeneratorMaxvalueOption))
  }
| sequence_generator_minvalue_option {
    $$.v = yy_box(SequenceGeneratorOption($1.v as SequenceGeneratorMinvalueOption))
  }
| sequence_generator_cycle_option {
    $$.v = yy_box(SequenceGeneratorOption(SequenceGeneratorCycleOption{$1.v as bool}))
  }

sequence_generator_start_with_option:
  START WITH sequence_generator_start_value {
    $$.v = yy_box(SequenceGeneratorStartWithOption{
      start_value: $3.v as Value
    })
  }

sequence_generator_start_value:
  signed_numeric_literal { $$.v = $1.v }

sequence_generator_increment_by_option:
  INCREMENT BY sequence_generator_increment {
    $$.v = yy_box(SequenceGeneratorIncrementByOption{
      increment_by: $3.v as Value
    })
  }

sequence_generator_increment:
  signed_numeric_literal { $$.v = $1.v }

sequence_generator_maxvalue_option:
  MAXVALUE sequence_generator_max_value {
    $$.v = yy_box(SequenceGeneratorMaxvalueOption{
      max_value: $2.v as Value
    })
  }
| NO MAXVALUE { $$.v = yy_box(SequenceGeneratorMaxvalueOption{}) }

sequence_generator_max_value:
  signed_numeric_literal { $$.v = $1.v }

sequence_generator_minvalue_option:
  MINVALUE sequence_generator_min_value {
    $$.v = yy_box(SequenceGeneratorMinvalueOption{
      min_value: $2.v as Value
    })
  }
| NO MINVALUE { $$.v = yy_box(SequenceGeneratorMinvalueOption{}) }

sequence_generator_min_value:
  signed_numeric_literal { $$.v = $1.v }

sequence_generator_cycle_option:
  CYCLE { $$.v = true }
| NO CYCLE { $$.v = false }

%%
