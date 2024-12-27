%%

next_value_expression:
  NEXT VALUE FOR sequence_generator_name {
    $$.v = NextValueExpression{
      name: $4.v as Identifier
    }
  }

%%
