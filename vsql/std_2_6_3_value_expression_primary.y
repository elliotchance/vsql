%%

value_expression_primary:
  parenthesized_value_expression {
    $$.v = yy_box(ValueExpressionPrimary($1.v as ParenthesizedValueExpression))
  }
| parenthesized_boolean_value_expression {
    $$.v = yy_box(ValueExpressionPrimary(new_parenthesized_value_expression(ValueExpression($1.v as BooleanValueExpression))))
  }
| nonparenthesized_value_expression_primary {
    $$.v = yy_box(ValueExpressionPrimary($1.v as NonparenthesizedValueExpressionPrimary))
  }

// A value_expression in parentheses is either a common_value_expression or a
// boolean_value_expression, but the boolean_value_expression is a
// parenthesized_boolean_value_expression so there's only one way to parse it.
parenthesized_value_expression:
  left_paren common_value_expression right_paren {
    $$.v = yy_box(new_parenthesized_value_expression(ValueExpression($2.v as CommonValueExpression)))
  }

nonparenthesized_value_expression_primary:
  unsigned_value_specification {
    $$.v = yy_box(NonparenthesizedValueExpressionPrimary($1.v as ValueSpecification))
  }
| column_reference {
    $$.v = yy_box(NonparenthesizedValueExpressionPrimary(new_ref($1.v as Identifier)))
  }
| set_function_specification {
    $$.v = yy_box(NonparenthesizedValueExpressionPrimary(new_ref($1.v as AggregateFunction)))
  }
| routine_invocation {
    $$.v = yy_box(NonparenthesizedValueExpressionPrimary(new_ref($1.v as RoutineInvocation)))
  }
| case_expression {
    $$.v = yy_box(NonparenthesizedValueExpressionPrimary($1.v as CaseExpression))
  }
| cast_specification {
    $$.v = yy_box(NonparenthesizedValueExpressionPrimary($1.v as CastSpecification))
  }
| pg_cast {
    $$.v = yy_box(NonparenthesizedValueExpressionPrimary($1.v as CastSpecification))
  }
| greatest_or_least_function {
    $$.v = yy_box(NonparenthesizedValueExpressionPrimary(new_ref($1.v as GreatestOrLeastFunction)))
  }
| next_value_expression {
    $$.v = yy_box(NonparenthesizedValueExpressionPrimary(new_ref($1.v as NextValueExpression)))
  }
| scalar_subquery {
    $$.v = yy_box(NonparenthesizedValueExpressionPrimary($1.v as Subquery))
  }

%%
