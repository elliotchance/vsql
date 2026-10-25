%%

quantified_comparison_predicate:
  row_value_predicand quantified_comparison_predicate_part_2 {
    part := $2.v as QuantifiedComparisonPredicate
    $$.v = QuantifiedComparisonPredicate{
      ...part
      expr: $1.v as RowValueConstructorPredicand
    }
  }

quantified_comparison_predicate_part_2:
  comp_op quantifier table_subquery {
    $$.v = QuantifiedComparisonPredicate{
      op:       $1.v as ComparisonOperator
      all:      $2.v as bool
      subquery: new_subquery(($3.v as TablePrimary).body as QueryExpression)
    }
  }

// quantifier is true for ALL, and false for SOME (or ANY).
quantifier:
  ALL { $$.v = true }
| SOME { $$.v = false }
| ANY { $$.v = false }

%%
