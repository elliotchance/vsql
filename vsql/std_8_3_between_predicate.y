%%

between_predicate:
  row_value_predicand between_predicate_part_2 {
    between := $2.v as BetweenPredicate
    $$.v = BetweenPredicate{
      not:       between.not
      symmetric: between.symmetric
      expr:      $1.v as RowValueConstructorPredicand
      left:      between.left
      right:     between.right
    }
  }

between_predicate_part_2:
  between_predicate_part_1 row_value_predicand AND row_value_predicand {
    $$.v = BetweenPredicate{
      not:       !($1.v as bool)
      symmetric: false
      left:      $2.v as RowValueConstructorPredicand
      right:     $4.v as RowValueConstructorPredicand
    }
  }
| between_predicate_part_1 is_symmetric row_value_predicand AND
  row_value_predicand {
    $$.v = BetweenPredicate{
      not:       !($1.v as bool)
      symmetric: $2.v as bool
      left:      $3.v as RowValueConstructorPredicand
      right:     $5.v as RowValueConstructorPredicand
    }
  }

between_predicate_part_1:
  BETWEEN { $$.v = true }
| NOT BETWEEN { $$.v = false }

is_symmetric:
  SYMMETRIC { $$.v = true }
| ASYMMETRIC { $$.v = false }

%%
