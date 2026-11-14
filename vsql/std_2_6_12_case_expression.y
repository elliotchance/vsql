%%

// ISO/IEC 9075-2:2023(E), 6.12, <case expression>
//
// Specify a conditional value.

case_expression:
  case_abbreviation { $$.v = $1.v }
| case_specification { $$.v = $1.v }

case_abbreviation:
  NULLIF left_paren value_expression comma value_expression right_paren {
    $$.v = yy_box(CaseExpression(new_case_expression_null_if($3.v as ValueExpression,
      $5.v as ValueExpression)))
  }
| COALESCE left_paren value_expression comma value_expression_list right_paren {
    $$.v = yy_box(CaseExpression(CaseExpressionCoalesce{
      prepend_list($3.v as ValueExpression, $5.v as []ValueExpression)
    }))
  }

case_specification:
  simple_case { $$.v = yy_box(CaseExpression($1.v as CaseExpressionSimple)) }
| searched_case { $$.v = yy_box(CaseExpression($1.v as CaseExpressionSearched)) }

// Without an ELSE, the ELSE is NULL.
//
// ISO/IEC 9075-2:2023(E), 6.12, <case expression>, Syntax Rules, 4

simple_case:
  CASE case_operand simple_when_clause_list END {
    flag_simple_case(mut yylex, $2.v as RowValueConstructorPredicand,
      $3.v as []CaseExpressionSimpleWhen)
    $$.v = yy_box(new_case_expression_simple($2.v as RowValueConstructorPredicand,
      $3.v as []CaseExpressionSimpleWhen, CaseResult(NullSpecification{})))
  }
| CASE case_operand simple_when_clause_list else_clause END {
    flag_simple_case(mut yylex, $2.v as RowValueConstructorPredicand,
      $3.v as []CaseExpressionSimpleWhen)
    $$.v = yy_box(new_case_expression_simple($2.v as RowValueConstructorPredicand,
      $3.v as []CaseExpressionSimpleWhen, $4.v as CaseResult))
  }

searched_case:
  CASE searched_when_clause_list END {
    $$.v = yy_box(new_case_expression_searched($2.v as []CaseExpressionSearchedWhen,
      CaseResult(NullSpecification{})))
  }
| CASE searched_when_clause_list else_clause END {
    $$.v = yy_box(new_case_expression_searched($2.v as []CaseExpressionSearchedWhen,
      $3.v as CaseResult))
  }

simple_when_clause:
  WHEN when_operand_list THEN result {
    $$.v = yy_box(CaseExpressionSimpleWhen{
      $2.v as []CaseWhenOperand
      $4.v as CaseResult
    })
  }

searched_when_clause:
  WHEN search_condition THEN result {
    $$.v = yy_box(CaseExpressionSearchedWhen{
      $2.v as BooleanValueExpression
      $4.v as CaseResult
    })
  }

else_clause:
  ELSE result { $$.v = $2.v }

// There's no <overlaps predicate part 1> because there's no <overlaps
// predicate> (F053).
case_operand:
  row_value_predicand { $$.v = $1.v }

// ISO/IEC 9075-2:2023(E), 6.12, <case expression>, Conformance Rules, 3
when_operand_list:
  when_operand { $$.v = yy_box([$1.v as CaseWhenOperand]) }
| when_operand_list comma when_operand {
    flag(mut yylex, 'F263')
    $$.v = yy_box(append_list($1.v as []CaseWhenOperand, $3.v as CaseWhenOperand))
  }

// Each <when operand> is a predicate with the <case operand> on the left (see
// CaseOperand). A <row value predicand> is compared with =.
//
// ISO/IEC 9075-2:2023(E), 6.12, <case expression>, Syntax Rules, 2.f and 2.i
//
// The predicates that vsql doesn't have (such as <overlaps predicate part 2>)
// can't be a <when operand>.
//
// ISO/IEC 9075-2:2023(E), 6.12, <caseexpression>, Conformance Rules, 2; ISO/IEC 9075-2:2023(E), 8.6, <similar predicate>, Conformance Rules, 1
when_operand:
  row_value_predicand {
    flag_if(mut yylex, ($1.v as RowValueConstructorPredicand) is ExplicitRowValueConstructor,
      'F262')
    $$.v = yy_box(CaseWhenOperand{
      predicate: ComparisonPredicate{case_operand(), .equal, $1.v as RowValueConstructorPredicand}
      is_value:  true
    })
  }
| comparison_predicate_part_2 {
    flag(mut yylex, 'F262')
    comp := $1.v as ComparisonPredicatePart2
    $$.v = yy_box(CaseWhenOperand{
      predicate: ComparisonPredicate{case_operand(), comp.op, comp.expr}
    })
  }
| between_predicate_part_2 {
    flag(mut yylex, 'F262')
    $$.v = yy_box(CaseWhenOperand{
      predicate: BetweenPredicate{
        ...$1.v as BetweenPredicate
        expr: case_operand()
      }
    })
  }
| in_predicate_part_2 {
    flag(mut yylex, 'F262')
    $$.v = yy_box(CaseWhenOperand{
      predicate: InPredicate{
        ...$1.v as InPredicate
        expr: case_operand()
      }
    })
  }
| character_like_predicate_part_2 {
    flag(mut yylex, 'F262')
    like := $1.v as CharacterLikePredicatePart2
    $$.v = yy_box(CaseWhenOperand{
      predicate: CharacterLikePredicate{case_operand(), like.right, like.escape, like.not,
        like.insensitive}
    })
  }
| similar_predicate_part_2 {
    flag(mut yylex, 'F262')
    flag(mut yylex, 'T141')
    like := $1.v as SimilarPredicatePart2
    $$.v = yy_box(CaseWhenOperand{
      predicate: SimilarPredicate{case_operand(), like.right, like.escape, like.not}
    })
  }
| null_predicate_part_2 {
    flag(mut yylex, 'F262')
    $$.v = yy_box(CaseWhenOperand{
      predicate: NullPredicate{case_operand(), !($1.v as bool)}
    })
  }
| quantified_comparison_predicate_part_2 {
    flag(mut yylex, 'F262')
    $$.v = yy_box(CaseWhenOperand{
      predicate: QuantifiedComparisonPredicate{
        ...$1.v as QuantifiedComparisonPredicate
        expr: case_operand()
      }
    })
  }

result:
  result_expression { $$.v = yy_box(CaseResult($1.v as ValueExpression)) }
| NULL { $$.v = yy_box(CaseResult(NullSpecification{})) }

result_expression:
  value_expression { $$.v = $1.v }

// These are non-standard, just to simplify standard rules:

value_expression_list:
  value_expression { $$.v = yy_box([$1.v as ValueExpression]) }
| value_expression_list comma value_expression {
    $$.v = yy_box(append_list($1.v as []ValueExpression, $3.v as ValueExpression))
  }

simple_when_clause_list:
  simple_when_clause { $$.v = yy_box([$1.v as CaseExpressionSimpleWhen]) }
| simple_when_clause_list simple_when_clause {
    $$.v = yy_box(append_list($1.v as []CaseExpressionSimpleWhen,
      $2.v as CaseExpressionSimpleWhen))
  }

searched_when_clause_list:
  searched_when_clause { $$.v = yy_box([$1.v as CaseExpressionSearchedWhen]) }
| searched_when_clause_list searched_when_clause {
    $$.v = yy_box(append_list($1.v as []CaseExpressionSearchedWhen,
      $2.v as CaseExpressionSearchedWhen))
  }

%%
