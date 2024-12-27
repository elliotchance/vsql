%%

value_expression_primary:
  parenthesized_value_expression {
    $$.v = ValueExpressionPrimary($1.v as ParenthesizedValueExpression)
  }
| nonparenthesized_value_expression_primary {
    $$.v = ValueExpressionPrimary($1.v as NonparenthesizedValueExpressionPrimary)
  }

parenthesized_value_expression:
  left_paren value_expression right_paren {
    $$.v = ParenthesizedValueExpression{$2.v as ValueExpression}
  }

nonparenthesized_value_expression_primary:
  unsigned_value_specification {
    $$.v = NonparenthesizedValueExpressionPrimary($1.v as ValueSpecification)
  }
| column_reference {
    $$.v = NonparenthesizedValueExpressionPrimary($1.v as Identifier)
  }
| set_function_specification {
    $$.v = NonparenthesizedValueExpressionPrimary($1.v as AggregateFunction)
  }
| routine_invocation {
    $$.v = NonparenthesizedValueExpressionPrimary($1.v as RoutineInvocation)
  }
| case_expression {
    $$.v = NonparenthesizedValueExpressionPrimary($1.v as CaseExpression)
  }
| cast_specification {
    $$.v = NonparenthesizedValueExpressionPrimary($1.v as CastSpecification)
  }
| next_value_expression {
    $$.v = NonparenthesizedValueExpressionPrimary($1.v as NextValueExpression)
  }

%%
