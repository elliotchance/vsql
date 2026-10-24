%%

case_expression:
  case_abbreviation { $$.v = $1.v as CaseExpression }
| case_specification { $$.v = $1.v as CaseExpression }

case_abbreviation:
  NULLIF left_paren value_expression comma value_expression right_paren {
    $$.v = CaseExpression(new_case_expression_null_if($3.v as ValueExpression,
      $5.v as ValueExpression))
  }
| COALESCE left_paren value_expression comma value_expression_list right_paren {
    $$.v = CaseExpression(CaseExpressionCoalesce{
      prepend_list($3.v as ValueExpression, $5.v as []ValueExpression)
    })
  }

case_specification:
  simple_case { $$.v = CaseExpression($1.v as CaseExpressionSimple) }
| searched_case { $$.v = CaseExpression($1.v as CaseExpressionSearched) }

simple_case:
  CASE case_operand simple_when_clause_list END {
    $$.v = new_case_expression_simple($2.v as RowValueConstructorPredicand,
      $3.v as []CaseExpressionSimpleWhen, CaseResult(NullSpecification{}))
  }
| CASE case_operand simple_when_clause_list else_clause END {
    $$.v = new_case_expression_simple($2.v as RowValueConstructorPredicand,
      $3.v as []CaseExpressionSimpleWhen, $4.v as CaseResult)
  }

searched_case:
  CASE searched_when_clause_list END {
    $$.v = new_case_expression_searched($2.v as []CaseExpressionSearchedWhen,
      CaseResult(NullSpecification{}))
  }
| CASE searched_when_clause_list else_clause END {
    $$.v = new_case_expression_searched($2.v as []CaseExpressionSearchedWhen,
      $3.v as CaseResult)
  }

simple_when_clause:
  WHEN when_operand_list THEN result {
    $$.v = CaseExpressionSimpleWhen{
      $2.v as RowValueConstructorPredicand
      $4.v as CaseResult
    }
  }

searched_when_clause:
  WHEN search_condition THEN result {
    $$.v = CaseExpressionSearchedWhen{
      $2.v as BooleanValueExpression
      $4.v as CaseResult
    }
  }

else_clause:
  ELSE result { $$.v = $2.v as CaseResult }

case_operand:
  row_value_predicand { $$.v = $1.v as RowValueConstructorPredicand }

when_operand_list:
  when_operand { $$.v = $1.v as RowValueConstructorPredicand }

when_operand:
  row_value_predicand { $$.v = $1.v as RowValueConstructorPredicand }

result:
  result_expression { $$.v = CaseResult($1.v as ValueExpression) }
| NULL { $$.v = CaseResult(NullSpecification{}) }

result_expression:
  value_expression { $$.v = $1.v as ValueExpression }

// These are non-standard, just to simplify standard rules:

value_expression_list:
  value_expression { $$.v = [$1.v as ValueExpression] }
| value_expression_list comma value_expression {
    $$.v = append_list($1.v as []ValueExpression, $3.v as ValueExpression)
  }

simple_when_clause_list:
  simple_when_clause { $$.v = [$1.v as CaseExpressionSimpleWhen] }
| simple_when_clause_list simple_when_clause {
    $$.v = append_list($1.v as []CaseExpressionSimpleWhen,
      $2.v as CaseExpressionSimpleWhen)
  }

searched_when_clause_list:
  searched_when_clause { $$.v = [$1.v as CaseExpressionSearchedWhen] }
| searched_when_clause_list searched_when_clause {
    $$.v = append_list($1.v as []CaseExpressionSearchedWhen,
      $2.v as CaseExpressionSearchedWhen)
  }

%%
