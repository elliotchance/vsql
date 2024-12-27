%%

string_value_expression:
  character_value_expression { $$.v = $1.v as CharacterValueExpression }

character_value_expression:
  concatenation { $$.v = CharacterValueExpression($1.v as Concatenation) }
| character_factor { $$.v = CharacterValueExpression($1.v as CharacterPrimary) }

concatenation:
  character_value_expression concatenation_operator character_factor {
    $$.v = Concatenation{
      $1.v as CharacterValueExpression
      $3.v as CharacterPrimary
    }
  }

character_factor:
  character_primary { $$.v = $1.v as CharacterPrimary }

character_primary:
  value_expression_primary {
    $$.v = CharacterPrimary($1.v as ValueExpressionPrimary)
  }
| string_value_function {
    $$.v = CharacterPrimary($1.v as CharacterValueFunction)
  }

%%
