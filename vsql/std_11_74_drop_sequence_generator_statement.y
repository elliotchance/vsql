%%

drop_sequence_generator_statement:
  DROP SEQUENCE sequence_generator_name {
    $$.v = Stmt(DropSequenceGeneratorStatement{$3.v as Identifier})
  }

%%
