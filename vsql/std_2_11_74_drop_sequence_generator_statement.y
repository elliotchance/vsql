%%

drop_sequence_generator_statement:
  DROP SEQUENCE sequence_generator_name {
    flag(mut yylex, 'T176')
    flag(mut yylex, vsql_drop_sequence_behavior)
    $$.v = Stmt(DropSequenceGeneratorStatement{$3.v as Identifier, 'RESTRICT'})
  }
| DROP SEQUENCE sequence_generator_name drop_behavior {
    flag(mut yylex, 'T176')
    $$.v = Stmt(DropSequenceGeneratorStatement{$3.v as Identifier, $4.v as string})
  }

%%
