%%

// ISO/IEC 9075-2:2016(E), 11.74, <drop sequence generator statement>, Conformance Rules, 1
drop_sequence_generator_statement:
  DROP SEQUENCE sequence_generator_name {
    flag(mut yylex, 'T176')
    flag(mut yylex, vsql_drop_sequence_behavior)
    $$.v = yy_box(Stmt(DropSequenceGeneratorStatement{
      sequence_name: $3.v as Identifier
      behavior:      'RESTRICT'
    }))
  }
| DROP SEQUENCE sequence_generator_name drop_behavior {
    flag(mut yylex, 'T176')
    $$.v = yy_box(Stmt(DropSequenceGeneratorStatement{
      sequence_name: $3.v as Identifier
      behavior:      $4.v as string
    }))
  }
| DROP SEQUENCE if_exists sequence_generator_name {
    flag(mut yylex, 'T176')
    flag(mut yylex, vsql_drop_sequence_behavior)
    flag(mut yylex, vsql_drop_sequence_if_exists)
    $$.v = yy_box(Stmt(DropSequenceGeneratorStatement{
      sequence_name: $4.v as Identifier
      behavior:      'RESTRICT'
      if_exists:     true
    }))
  }
| DROP SEQUENCE if_exists sequence_generator_name drop_behavior {
    flag(mut yylex, 'T176')
    flag(mut yylex, vsql_drop_sequence_if_exists)
    $$.v = yy_box(Stmt(DropSequenceGeneratorStatement{
      sequence_name: $4.v as Identifier
      behavior:      $5.v as string
      if_exists:     true
    }))
  }

%%
