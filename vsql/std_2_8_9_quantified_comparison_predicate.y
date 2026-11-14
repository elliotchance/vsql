%%

quantified_comparison_predicate:
  row_value_predicand quantified_comparison_predicate_part_2 {
    part := $2.v as QuantifiedComparisonPredicate
    $$.v = yy_box(QuantifiedComparisonPredicate{
      ...part
      expr: $1.v as RowValueConstructorPredicand
    })
  }

// The <quantifier> is written out (all is true for ALL, and false for SOME or
// ANY) because SOME and ANY are also aggregate functions, see
// general_set_function.
//
// ISO/IEC 9075-2:2023, 8.9, <quantified comparison predicate>, Format
quantified_comparison_predicate_part_2:
  comp_op ALL table_subquery {
    $$.v = yy_box(QuantifiedComparisonPredicate{
      op:       $1.v as ComparisonOperator
      all:      true
      subquery: new_subquery(($3.v as TablePrimary).body as QueryExpression)
    })
  }
| comp_op SOME table_subquery {
    $$.v = yy_box(QuantifiedComparisonPredicate{
      op:       $1.v as ComparisonOperator
      all:      false
      subquery: new_subquery(($3.v as TablePrimary).body as QueryExpression)
    })
  }
| comp_op ANY table_subquery {
    $$.v = yy_box(QuantifiedComparisonPredicate{
      op:       $1.v as ComparisonOperator
      all:      false
      subquery: new_subquery(($3.v as TablePrimary).body as QueryExpression)
    })
  }

%%
