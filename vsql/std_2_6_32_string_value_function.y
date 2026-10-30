%%

// ISO/IEC 9075-2:2016(E), 6.32, <string value function>
//
// Specify a function yielding a value of type character string or binary
// string.

string_value_function:
  character_value_function { $$.v = $1.v as CharacterValueFunction }

character_value_function:
  character_substring_function {
    $$.v = CharacterValueFunction($1.v as CharacterSubstringFunction)
  }
| fold { $$.v = CharacterValueFunction($1.v as RoutineInvocation) }
| trim_function { $$.v = CharacterValueFunction($1.v as TrimFunction) }

// Without USING, it's USING CHARACTERS.
//
// ISO/IEC 9075-2:2016(E), 6.32, <string value function>, Syntax Rules, 6

character_substring_function:
  SUBSTRING left_paren character_value_expression FROM start_position
  right_paren {
    $$.v = new_character_substring_function($3.v as CharacterValueExpression,
      $5.v as NumericValueExpression, none, 'CHARACTERS')
  }
| SUBSTRING left_paren character_value_expression FROM start_position FOR
  string_length right_paren {
    $$.v = new_character_substring_function($3.v as CharacterValueExpression,
      $5.v as NumericValueExpression, $7.v as NumericValueExpression,
      'CHARACTERS')
  }
| SUBSTRING left_paren character_value_expression FROM start_position USING
  char_length_units right_paren {
    $$.v = new_character_substring_function($3.v as CharacterValueExpression,
      $5.v as NumericValueExpression, none, $7.v as string)
  }
| SUBSTRING left_paren character_value_expression FROM start_position FOR
  string_length USING char_length_units right_paren {
    $$.v = new_character_substring_function($3.v as CharacterValueExpression,
      $5.v as NumericValueExpression, $7.v as NumericValueExpression,
      $9.v as string)
  }

fold:
  UPPER left_paren character_value_expression right_paren {
    $$.v = RoutineInvocation{function_name: 'UPPER', args: [
      ValueExpression(CommonValueExpression($3.v as CharacterValueExpression))]}
  }
| LOWER left_paren character_value_expression right_paren {
    $$.v = RoutineInvocation{function_name: 'LOWER', args: [
      ValueExpression(CommonValueExpression($3.v as CharacterValueExpression))]}
  }

trim_function:
  TRIM left_paren trim_operands right_paren { $$.v = $3.v as TrimFunction }

// Without a trim specification it's BOTH, and without a trim character it's a
// space. vsql also allows FROM without either (#770).
//
// ISO/IEC 9075-2:2016(E), 6.32, <string value function>, Syntax Rules, 13.a

trim_operands:
  trim_source {
    space := CharacterValueExpression(CharacterPrimary(ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(ValueSpecification(new_varchar_value(' '))))))
    $$.v = new_trim_function('BOTH', space, $1.v as CharacterValueExpression)
  }
| FROM trim_source {
    space := CharacterValueExpression(CharacterPrimary(ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(ValueSpecification(new_varchar_value(' '))))))
    $$.v = new_trim_function('BOTH', space, $2.v as CharacterValueExpression)
  }
| trim_specification FROM trim_source {
    space := CharacterValueExpression(CharacterPrimary(ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(ValueSpecification(new_varchar_value(' '))))))
    $$.v = new_trim_function($1.v as string, space, $3.v as CharacterValueExpression)
  }
| trim_character FROM trim_source {
    $$.v = new_trim_function('BOTH', $1.v as CharacterValueExpression, $3.v as CharacterValueExpression)
  }
| trim_specification trim_character FROM trim_source   {
    $$.v = new_trim_function($1.v as string, $2.v as CharacterValueExpression, $4.v as CharacterValueExpression)
  }

trim_source:
  character_value_expression { $$.v = $1.v as CharacterValueExpression }

trim_specification:
  LEADING { $$.v = $1.v as string }
| TRAILING { $$.v = $1.v as string }
| BOTH { $$.v = $1.v as string }

trim_character:
  character_value_expression { $$.v = $1.v as CharacterValueExpression }

start_position:
  numeric_value_expression { $$.v = $1.v as NumericValueExpression }

string_length:
  numeric_value_expression { $$.v = $1.v as NumericValueExpression }

%%
