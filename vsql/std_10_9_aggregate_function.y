%%

// was: COUNT left_paren asterisk right_paren
aggregate_function:
  COUNT OPERATOR_LEFT_PAREN_ASTERISK right_paren {
    $$.v = AggregateFunction(AggregateFunctionCount{})
  }
| general_set_function { $$.v = $1.v as AggregateFunction }

general_set_function:
  set_function_type left_paren value_expression right_paren {
    $$.v = AggregateFunction(RoutineInvocation{
      $1.v as string, [$3.v as ValueExpression]})
  }

set_function_type:
  computational_operation { $$.v = $1.v as string }

computational_operation:
  AVG { $$.v = $1.v as string }
| MAX { $$.v = $1.v as string }
| MIN { $$.v = $1.v as string }
| SUM { $$.v = $1.v as string }
| COUNT { $$.v = $1.v as string }

%%
