%%

// ISO/IEC 9075-2:2016(E), 6.14, <next value expression>
//
// Return the next value of a sequence generator.

next_value_expression:
  NEXT VALUE FOR sequence_generator_name {
    // ISO/IEC 9075-2:2016(E), 6.14, <next value expression>, Conformance Rules, 1
    flag(mut yylex, 'T176')
    $$.v = NextValueExpression{
      name: $4.v as Identifier
    }
  }

%%
