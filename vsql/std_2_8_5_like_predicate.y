%%

like_predicate:
  character_like_predicate { $$.v = $1.v as CharacterLikePredicate }

character_like_predicate:
  row_value_predicand character_like_predicate_part_2 {
    like := $2.v as CharacterLikePredicatePart2
    $$.v = CharacterLikePredicate{
      $1.v as RowValueConstructorPredicand
      like.right
      like.escape
      like.not
    }
  }

character_like_predicate_part_2:
  LIKE character_pattern {
    $$.v = CharacterLikePredicatePart2{$2.v as CharacterValueExpression, none,
      false}
  }
| NOT LIKE character_pattern {
    $$.v = CharacterLikePredicatePart2{$3.v as CharacterValueExpression, none,
      true}
  }
| LIKE character_pattern ESCAPE escape_character {
    $$.v = CharacterLikePredicatePart2{$2.v as CharacterValueExpression,
      ref_character_value_expression($4.v as CharacterValueExpression), false}
  }
| NOT LIKE character_pattern ESCAPE escape_character {
    $$.v = CharacterLikePredicatePart2{$3.v as CharacterValueExpression,
      ref_character_value_expression($5.v as CharacterValueExpression), true}
  }

character_pattern:
  character_value_expression { $$.v = $1.v as CharacterValueExpression }

escape_character:
  character_value_expression { $$.v = $1.v as CharacterValueExpression }

%%
