%%

value_expression_primary:
  parenthesized_value_expression {
    $$.v = ValueExpressionPrimary($1.v as ParenthesizedValueExpression)
  }
| parenthesized_boolean_value_expression {
    $$.v = ValueExpressionPrimary(new_parenthesized_value_expression(ValueExpression($1.v as BooleanValueExpression)))
  }
| nonparenthesized_value_expression_primary {
    $$.v = ValueExpressionPrimary($1.v as NonparenthesizedValueExpressionPrimary)
  }

// A value_expression in parentheses is either a common_value_expression or a
// boolean_value_expression, but the boolean_value_expression is a
// parenthesized_boolean_value_expression so there's only one way to parse it.
parenthesized_value_expression:
  left_paren common_value_expression right_paren {
    $$.v = new_parenthesized_value_expression(ValueExpression($2.v as CommonValueExpression))
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
| scalar_subquery {
    $$.v = NonparenthesizedValueExpressionPrimary($1.v as Subquery)
  }

%%
