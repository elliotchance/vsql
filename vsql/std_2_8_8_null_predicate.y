%%

null_predicate:
  row_value_predicand null_predicate_part_2 {
    $$.v = NullPredicate{$1.v as RowValueConstructorPredicand, !($2.v as bool)}
  }

null_predicate_part_2:
  IS NULL { $$.v = true }
| IS NOT NULL { $$.v = false }

%%
