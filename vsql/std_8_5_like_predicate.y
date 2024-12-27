%%

like_predicate:
  character_like_predicate { $$.v = $1.v as CharacterLikePredicate }

character_like_predicate:
  row_value_predicand character_like_predicate_part_2 {
    like := $2.v as CharacterLikePredicate
    $$.v = CharacterLikePredicate{
      $1.v as RowValueConstructorPredicand
      like.right
      like.not
    }
  }

character_like_predicate_part_2:
  LIKE character_pattern {
    $$.v = CharacterLikePredicate{none, $2.v as CharacterValueExpression, false}
  }
| NOT LIKE character_pattern {
    $$.v = CharacterLikePredicate{none, $3.v as CharacterValueExpression, true}
  }

character_pattern:
  character_value_expression { $$.v = $1.v as CharacterValueExpression }

%%
