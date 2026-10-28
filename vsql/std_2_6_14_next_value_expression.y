%%

next_value_expression:
  NEXT VALUE FOR sequence_generator_name {
    flag(mut yylex, 'T176')
    $$.v = NextValueExpression{
      name: $4.v as Identifier
    }
  }

%%
