%%

// was: COUNT left_paren asterisk right_paren
aggregate_function:
  COUNT OPERATOR_LEFT_PAREN_ASTERISK right_paren {
    parsed_sort_key_part(mut yylex, .set_function)
    $$.v = AggregateFunction(AggregateFunctionCount{})
  }
| COUNT OPERATOR_LEFT_PAREN_ASTERISK right_paren filter_clause {
    parsed_sort_key_part(mut yylex, .set_function)
    $$.v = AggregateFunction(AggregateFunctionCount{
      filter: &BooleanValueExpression{
        ...$4.v as BooleanValueExpression
      }
    })
  }
| general_set_function {
    parsed_sort_key_part(mut yylex, .set_function)
    $$.v = $1.v as AggregateFunction
  }
| general_set_function filter_clause {
    parsed_sort_key_part(mut yylex, .set_function)
    $$.v = with_filter($1.v as AggregateFunction, $2.v as BooleanValueExpression)
  }

// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Conformance Rules, 13
filter_clause:
  FILTER left_paren WHERE search_condition right_paren {
    flag(mut yylex, 'T612')
    $$.v = $4.v as BooleanValueExpression
  }

// ALL is the same as no <set quantifier>.
//
// SOME and ANY are also the quantifiers of a <quantified comparison predicate>,
// such as x = ANY (SELECT ...). So they aren't a <computational operation>
// here, which lets the parser wait until after the "(" to choose: a subquery
// is a quantified comparison, anything else is this aggregate function.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 3
general_set_function:
  set_function_type left_paren value_expression right_paren {
    flag_if(mut yylex, $1.v as string == 'COUNT', 'F441')
    $$.v = AggregateFunction(RoutineInvocation{
      function_name: $1.v as string
      args:          [$3.v as ValueExpression]
    })
  }
| set_function_type left_paren set_quantifier value_expression right_paren {
    flag_set_quantifier(mut yylex, $1.v as string, $3.v as bool, $4.v as ValueExpression)
    $$.v = AggregateFunction(RoutineInvocation{
      function_name: $1.v as string
      args:          [$4.v as ValueExpression]
      distinct:      $3.v as bool
    })
  }
| SOME left_paren value_expression right_paren {
    flag(mut yylex, 'T031')
    $$.v = AggregateFunction(RoutineInvocation{
      function_name: $1.v as string
      args:          [$3.v as ValueExpression]
    })
  }
| SOME left_paren set_quantifier value_expression right_paren {
    flag(mut yylex, 'T031')
    flag_set_quantifier(mut yylex, $1.v as string, $3.v as bool, $4.v as ValueExpression)
    $$.v = AggregateFunction(RoutineInvocation{
      function_name: $1.v as string
      args:          [$4.v as ValueExpression]
      distinct:      $3.v as bool
    })
  }
| ANY left_paren value_expression right_paren {
    flag(mut yylex, 'T031')
    $$.v = AggregateFunction(RoutineInvocation{
      function_name: $1.v as string
      args:          [$3.v as ValueExpression]
    })
  }
| ANY left_paren set_quantifier value_expression right_paren {
    flag(mut yylex, 'T031')
    flag_set_quantifier(mut yylex, $1.v as string, $3.v as bool, $4.v as ValueExpression)
    $$.v = AggregateFunction(RoutineInvocation{
      function_name: $1.v as string
      args:          [$4.v as ValueExpression]
      distinct:      $3.v as bool
    })
  }

// DISTINCT is true.
set_quantifier:
  ALL { $$.v = false }
| DISTINCT { $$.v = true }

set_function_type:
  computational_operation { $$.v = $1.v as string }

computational_operation:
  AVG { $$.v = $1.v as string }
| MAX { $$.v = $1.v as string }
| MIN { $$.v = $1.v as string }
| SUM { $$.v = $1.v as string }
| COUNT { $$.v = $1.v as string }
| EVERY {
    flag(mut yylex, 'T031')
    $$.v = $1.v as string
  }

%%
