%%

// operator_numeric_value_expression is a numeric_value_expression that isn't
// only a value_expression_primary (see common_value_expression).
operator_numeric_value_expression:
  operator_term { $$.v = yy_box(NumericValueExpression{term: $1.v as Term}) }
| numeric_value_expression plus_sign term {
    n := $1.v as NumericValueExpression
    $$.v = yy_box(NumericValueExpression{&n, '+', $3.v as Term})
  }
| numeric_value_expression minus_sign term {
    n := $1.v as NumericValueExpression
    $$.v = yy_box(NumericValueExpression{&n, '-', $3.v as Term})
  }

operator_term:
  operator_factor { $$.v = yy_box(Term{factor: $1.v as NumericPrimary}) }
| term asterisk factor {
    t := $1.v as Term
    $$.v = yy_box(Term{&t, '*', $3.v as NumericPrimary})
  }
| term solidus factor {
    t := $1.v as Term
    $$.v = yy_box(Term{&t, '/', $3.v as NumericPrimary})
  }

operator_factor:
  sign numeric_primary {
    $$.v = yy_box(parse_factor_2($1.v as string, $2.v as NumericPrimary)!)
  }
| numeric_value_function { $$.v = yy_box(NumericPrimary($1.v as RoutineInvocation)) }

numeric_value_expression:
  term { $$.v = yy_box(NumericValueExpression{term: $1.v as Term}) }
| numeric_value_expression plus_sign term {
    n := $1.v as NumericValueExpression
    $$.v = yy_box(NumericValueExpression{&n, '+', $3.v as Term})
  }
| numeric_value_expression minus_sign term {
    n := $1.v as NumericValueExpression
    $$.v = yy_box(NumericValueExpression{&n, '-', $3.v as Term})
  }

term:
  factor { $$.v = yy_box(Term{factor: $1.v as NumericPrimary}) }
| term asterisk factor {
    t := $1.v as Term
    $$.v = yy_box(Term{&t, '*', $3.v as NumericPrimary})
  }
| term solidus factor {
    t := $1.v as Term
    $$.v = yy_box(Term{&t, '/', $3.v as NumericPrimary})
  }

factor:
  numeric_primary { $$.v = $1.v }
| sign numeric_primary {
    $$.v = yy_box(parse_factor_2($1.v as string, $2.v as NumericPrimary)!)
  }

numeric_primary:
  value_expression_primary {
    $$.v = yy_box(NumericPrimary($1.v as ValueExpressionPrimary))
  }
| numeric_value_function { $$.v = yy_box(NumericPrimary($1.v as RoutineInvocation)) }

%%
