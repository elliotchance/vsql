%%

// ISO/IEC 9075-2:2023, 6.15, <greatest or least function>
//
// Specify functions yielding the greatest or least value of its arguments.

// There must be at least two arguments.
//
// ISO/IEC 9075-2:2023, 6.15, <greatest or least function>, Conformance Rules, 1
greatest_or_least_function:
  greatest_or_least left_paren value_expression comma value_expression_list right_paren {
    flag(mut yylex, 'T054')
    $$.v = yy_box(GreatestOrLeastFunction{
      greatest: $1.v as bool
      exprs:    prepend_list($3.v as ValueExpression, $5.v as []ValueExpression)
    })
  }

greatest_or_least:
  GREATEST { $$.v = true }
| LEAST { $$.v = false }

%%
