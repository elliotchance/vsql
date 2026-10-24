%%

// was: COUNT left_paren asterisk right_paren
aggregate_function:
  COUNT OPERATOR_LEFT_PAREN_ASTERISK right_paren {
    $$.v = AggregateFunction(AggregateFunctionCount{})
  }
| general_set_function { $$.v = $1.v as AggregateFunction }

// ALL is the same as no <set quantifier> (Syntax Rule 3).
general_set_function:
  set_function_type left_paren value_expression right_paren {
    $$.v = AggregateFunction(RoutineInvocation{
      $1.v as string, [$3.v as ValueExpression], false})
  }
| set_function_type left_paren set_quantifier value_expression right_paren {
    $$.v = AggregateFunction(RoutineInvocation{
      $1.v as string, [$4.v as ValueExpression], $3.v as bool})
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

%%
