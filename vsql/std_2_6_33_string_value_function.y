%%

// ISO/IEC 9075-2:2023, 6.33, <string value function>
//
// Specify a function yielding a value of type character string or binary
// string.

string_value_function:
  character_value_function { $$.v = $1.v }

character_value_function:
  character_substring_function {
    $$.v = yy_box(CharacterValueFunction($1.v as CharacterSubstringFunction))
  }
| regular_expression_substring_function {
    $$.v = yy_box(CharacterValueFunction($1.v as RegularExpressionSubstringFunction))
  }
| fold { $$.v = yy_box(CharacterValueFunction($1.v as RoutineInvocation)) }
| character_overlay_function {
    flag(mut yylex, 'T312')
    $$.v = yy_box(CharacterValueFunction($1.v as OverlayFunction))
  }
| trim_function { $$.v = yy_box(CharacterValueFunction($1.v as TrimFunction)) }

// Without USING, it's USING CHARACTERS.
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 6

character_substring_function:
  SUBSTRING left_paren character_value_expression FROM start_position
  right_paren {
    $$.v = yy_box(new_character_substring_function($3.v as CharacterValueExpression,
      $5.v as NumericValueExpression, none, 'CHARACTERS'))
  }
| SUBSTRING left_paren character_value_expression FROM start_position FOR
  string_length right_paren {
    $$.v = yy_box(new_character_substring_function($3.v as CharacterValueExpression,
      $5.v as NumericValueExpression, $7.v as NumericValueExpression,
      'CHARACTERS'))
  }
| SUBSTRING left_paren character_value_expression FROM start_position USING
  char_length_units right_paren {
    $$.v = yy_box(new_character_substring_function($3.v as CharacterValueExpression,
      $5.v as NumericValueExpression, none, $7.v as string))
  }
| SUBSTRING left_paren character_value_expression FROM start_position FOR
  string_length USING char_length_units right_paren {
    $$.v = yy_box(new_character_substring_function($3.v as CharacterValueExpression,
      $5.v as NumericValueExpression, $7.v as NumericValueExpression,
      $9.v as string))
  }

// ISO/IEC 9075-2:2023, 6.33, <string value function>, Conformance Rules, 2
regular_expression_substring_function:
  SUBSTRING left_paren character_value_expression SIMILAR
  character_value_expression ESCAPE escape_character right_paren {
    flag(mut yylex, 'T581')
    $$.v = yy_box(new_regular_expression_substring_function(
      $3.v as CharacterValueExpression, $5.v as CharacterValueExpression,
      $7.v as CharacterValueExpression))
  }

fold:
  UPPER left_paren character_value_expression right_paren {
    $$.v = yy_box(RoutineInvocation{function_name: 'UPPER', args: [
      ValueExpression(CommonValueExpression($3.v as CharacterValueExpression))]})
  }
| LOWER left_paren character_value_expression right_paren {
    $$.v = yy_box(RoutineInvocation{function_name: 'LOWER', args: [
      ValueExpression(CommonValueExpression($3.v as CharacterValueExpression))]})
  }

// Without USING, it's USING CHARACTERS (like SUBSTRING).
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 17

character_overlay_function:
  OVERLAY left_paren character_value_expression PLACING
  character_value_expression FROM start_position right_paren {
    $$.v = yy_box(new_overlay_function($3.v as CharacterValueExpression,
      $5.v as CharacterValueExpression, $7.v as NumericValueExpression, none,
      'CHARACTERS'))
  }
| OVERLAY left_paren character_value_expression PLACING
  character_value_expression FROM start_position FOR string_length
  right_paren {
    $$.v = yy_box(new_overlay_function($3.v as CharacterValueExpression,
      $5.v as CharacterValueExpression, $7.v as NumericValueExpression,
      $9.v as NumericValueExpression, 'CHARACTERS'))
  }
| OVERLAY left_paren character_value_expression PLACING
  character_value_expression FROM start_position USING char_length_units
  right_paren {
    $$.v = yy_box(new_overlay_function($3.v as CharacterValueExpression,
      $5.v as CharacterValueExpression, $7.v as NumericValueExpression, none,
      $9.v as string))
  }
| OVERLAY left_paren character_value_expression PLACING
  character_value_expression FROM start_position FOR string_length USING
  char_length_units right_paren {
    $$.v = yy_box(new_overlay_function($3.v as CharacterValueExpression,
      $5.v as CharacterValueExpression, $7.v as NumericValueExpression,
      $9.v as NumericValueExpression, $11.v as string))
  }

trim_function:
  TRIM left_paren trim_operands right_paren { $$.v = $3.v }

// Without a trim specification it's BOTH, and without a trim character it's a
// space. vsql also allows FROM without either (V404-01).
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, Syntax Rules, 14.a

trim_operands:
  trim_source {
    space := CharacterValueExpression(CharacterPrimary(ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(ValueSpecification(new_varchar_value(' '))))))
    $$.v = yy_box(new_trim_function('BOTH', space, $1.v as CharacterValueExpression))
  }
| FROM trim_source {
    flag(mut yylex, vsql_trim_only_from)
    space := CharacterValueExpression(CharacterPrimary(ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(ValueSpecification(new_varchar_value(' '))))))
    $$.v = yy_box(new_trim_function('BOTH', space, $2.v as CharacterValueExpression))
  }
| trim_specification FROM trim_source {
    space := CharacterValueExpression(CharacterPrimary(ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(ValueSpecification(new_varchar_value(' '))))))
    $$.v = yy_box(new_trim_function($1.v as string, space, $3.v as CharacterValueExpression))
  }
| trim_character FROM trim_source {
    $$.v = yy_box(new_trim_function('BOTH', $1.v as CharacterValueExpression, $3.v as CharacterValueExpression))
  }
| trim_specification trim_character FROM trim_source   {
    $$.v = yy_box(new_trim_function($1.v as string, $2.v as CharacterValueExpression, $4.v as CharacterValueExpression))
  }

trim_source:
  character_value_expression { $$.v = $1.v }

trim_specification:
  LEADING { $$.v = $1.v as string }
| TRAILING { $$.v = $1.v as string }
| BOTH { $$.v = $1.v as string }

trim_character:
  character_value_expression { $$.v = $1.v }

start_position:
  numeric_value_expression { $$.v = $1.v }

string_length:
  numeric_value_expression { $$.v = $1.v }

%%
