%%

// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>
//
// There's no <octet like predicate> because there are no binary strings
// (T021).

like_predicate:
  character_like_predicate { $$.v = $1.v as CharacterLikePredicate }

// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>, Conformance Rules, 2
character_like_predicate:
  row_value_predicand character_like_predicate_part_2 {
    flag_if(mut yylex, !is_column_reference($1.v as RowValueConstructorPredicand), 'F281')
    like := $2.v as CharacterLikePredicatePart2
    $$.v = CharacterLikePredicate{
      $1.v as RowValueConstructorPredicand
      like.right
      like.escape
      like.not
    }
  }

// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>, Conformance Rules, 3 and 4
character_like_predicate_part_2:
  LIKE character_pattern {
    flag_if(mut yylex, !is_character_value_specification($2.v as CharacterValueExpression),
      'F281')
    $$.v = CharacterLikePredicatePart2{$2.v as CharacterValueExpression, none,
      false}
  }
| NOT LIKE character_pattern {
    flag_if(mut yylex, !is_character_value_specification($3.v as CharacterValueExpression),
      'F281')
    $$.v = CharacterLikePredicatePart2{$3.v as CharacterValueExpression, none,
      true}
  }
| LIKE character_pattern ESCAPE escape_character {
    flag_if(mut yylex, !is_character_value_specification($2.v as CharacterValueExpression),
      'F281')
    flag_if(mut yylex, !is_character_value_specification($4.v as CharacterValueExpression),
      'F281')
    $$.v = CharacterLikePredicatePart2{$2.v as CharacterValueExpression,
      ref_character_value_expression($4.v as CharacterValueExpression), false}
  }
| NOT LIKE character_pattern ESCAPE escape_character {
    flag_if(mut yylex, !is_character_value_specification($3.v as CharacterValueExpression),
      'F281')
    flag_if(mut yylex, !is_character_value_specification($5.v as CharacterValueExpression),
      'F281')
    $$.v = CharacterLikePredicatePart2{$3.v as CharacterValueExpression,
      ref_character_value_expression($5.v as CharacterValueExpression), true}
  }

character_pattern:
  character_value_expression { $$.v = $1.v as CharacterValueExpression }

escape_character:
  character_value_expression { $$.v = $1.v as CharacterValueExpression }

%%
