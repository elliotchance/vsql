%%

case_expression:
  case_abbreviation { $$.v = $1.v as CaseExpression }

case_abbreviation:
  NULLIF left_paren value_expression comma value_expression right_paren {
    $$.v = CaseExpression(CaseExpressionNullIf{
      $3.v as ValueExpression
      $5.v as ValueExpression
    })
  }
| COALESCE left_paren value_expression_list right_paren {
    $$.v = CaseExpression(CaseExpressionCoalesce{$3.v as []ValueExpression})
  }

// These are non-standard, just to simplify standard rules:

value_expression_list:
  value_expression { $$.v = [$1.v as ValueExpression] }
| value_expression_list comma value_expression {
    $$.v = append_list($1.v as []ValueExpression, $3.v as ValueExpression)
  }

%%
