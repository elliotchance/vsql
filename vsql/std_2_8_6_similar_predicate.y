%%

// ISO/IEC 9075-2:2016(E), 8.6, <similar predicate>
//
// ISO/IEC 9075-2:2016(E), 8.6, <similar predicate>, Conformance Rules, 1
similar_predicate:
  row_value_predicand similar_predicate_part_2 {
    flag(mut yylex, 'T141')
    like := $2.v as SimilarPredicatePart2
    $$.v = SimilarPredicate{$1.v as RowValueConstructorPredicand, like.right,
      like.escape, like.not}
  }

similar_predicate_part_2:
  SIMILAR TO similar_pattern {
    $$.v = SimilarPredicatePart2{$3.v as CharacterValueExpression, none, false}
  }
| NOT SIMILAR TO similar_pattern {
    $$.v = SimilarPredicatePart2{$4.v as CharacterValueExpression, none, true}
  }
| SIMILAR TO similar_pattern ESCAPE escape_character {
    $$.v = SimilarPredicatePart2{$3.v as CharacterValueExpression,
      ref_character_value_expression($5.v as CharacterValueExpression), false}
  }
| NOT SIMILAR TO similar_pattern ESCAPE escape_character {
    $$.v = SimilarPredicatePart2{$4.v as CharacterValueExpression,
      ref_character_value_expression($6.v as CharacterValueExpression), true}
  }

similar_pattern:
  character_value_expression { $$.v = $1.v as CharacterValueExpression }

%%
