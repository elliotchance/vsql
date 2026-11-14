%%

string_value_expression:
  character_value_expression { $$.v = $1.v }

character_value_expression:
  concatenation { $$.v = yy_box(CharacterValueExpression($1.v as Concatenation)) }
| character_factor { $$.v = yy_box(CharacterValueExpression($1.v as CharacterPrimary)) }

concatenation:
  character_value_expression concatenation_operator character_factor {
    $$.v = yy_box(new_concatenation($1.v as CharacterValueExpression,
      $3.v as CharacterPrimary))
  }

character_factor:
  character_primary { $$.v = $1.v }

character_primary:
  value_expression_primary {
    $$.v = yy_box(CharacterPrimary($1.v as ValueExpressionPrimary))
  }
| string_value_function {
    $$.v = yy_box(CharacterPrimary($1.v as CharacterValueFunction))
  }

%%
