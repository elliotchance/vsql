%%

numeric_value_expression:
  term { $$.v = NumericValueExpression{term: $1.v as Term} }
| numeric_value_expression plus_sign term {
    n := $1.v as NumericValueExpression
    $$.v = NumericValueExpression{&n, '+', $3.v as Term}
  }
| numeric_value_expression minus_sign term {
    n := $1.v as NumericValueExpression
    $$.v = NumericValueExpression{&n, '-', $3.v as Term}
  }

term:
  factor { $$.v = Term{factor: $1.v as NumericPrimary} }
| term asterisk factor {
    t := $1.v as Term
    $$.v = Term{&t, '*', $3.v as NumericPrimary}
  }
| term solidus factor {
    t := $1.v as Term
    $$.v = Term{&t, '/', $3.v as NumericPrimary}
  }

factor:
  numeric_primary { $$.v = $1.v as NumericPrimary }
| sign numeric_primary {
    $$.v = parse_factor_2($1.v as string, $2.v as NumericPrimary)!
  }

numeric_primary:
  value_expression_primary {
    $$.v = NumericPrimary($1.v as ValueExpressionPrimary)
  }
| numeric_value_function { $$.v = NumericPrimary($1.v as RoutineInvocation) }

%%
