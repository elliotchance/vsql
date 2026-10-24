%%

drop_sequence_generator_statement:
  DROP SEQUENCE sequence_generator_name {
    $$.v = Stmt(DropSequenceGeneratorStatement{$3.v as Identifier, 'RESTRICT'})
  }
| DROP SEQUENCE sequence_generator_name drop_behavior {
    $$.v = Stmt(DropSequenceGeneratorStatement{$3.v as Identifier, $4.v as string})
  }

%%
