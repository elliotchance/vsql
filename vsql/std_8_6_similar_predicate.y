%%

similar_predicate:
  row_value_predicand similar_predicate_part_2 {
    like := $2.v as SimilarPredicate
    $$.v = SimilarPredicate{$1.v as RowValueConstructorPredicand, like.right, like.not}
  }

similar_predicate_part_2:
  SIMILAR TO similar_pattern {
    $$.v = SimilarPredicate{none, $3.v as CharacterValueExpression, false}
  }
| NOT SIMILAR TO similar_pattern {
    $$.v = SimilarPredicate{none, $4.v as CharacterValueExpression, true}
  }

similar_pattern:
  character_value_expression { $$.v = $1.v as CharacterValueExpression }

%%
