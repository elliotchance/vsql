%%

comparison_predicate:
  row_value_predicand comparison_predicate_part_2 {
    comp := $2.v as ComparisonPredicatePart2
    $$.v = ComparisonPredicate{
      $1.v as RowValueConstructorPredicand
      comp.op
      comp.expr
    }
  }

comparison_predicate_part_2:
  comp_op row_value_predicand {
    $$.v = ComparisonPredicatePart2{
      $1.v as string
      $2.v as RowValueConstructorPredicand
    }
  }

comp_op:
  equals_operator { $$.v = $1.v as string }
| not_equals_operator { $$.v = $1.v as string }
| less_than_operator { $$.v = $1.v as string }
| greater_than_operator { $$.v = $1.v as string }
| less_than_or_equals_operator { $$.v = $1.v as string }
| greater_than_or_equals_operator { $$.v = $1.v as string }

%%
