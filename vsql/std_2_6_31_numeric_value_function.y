%%

// ISO/IEC 9075-2:2023(E), 6.31, <numeric value function>
//
// Specify a function yielding a value of type numeric.
//
// Each function is flagged with its feature.
//
// ISO/IEC 9075-2:2023(E), 6.31, <numeric value function>, Conformance Rules, 9-11
// ISO/IEC 9075-2:2023(E), 6.31, <numeric value function>, Conformance Rules, 13-20

numeric_value_function:
  position_expression { $$.v = $1.v }
| length_expression { $$.v = $1.v }
| absolute_value_expression {
    flag(mut yylex, 'T441')
    $$.v = $1.v
  }
| modulus_expression {
    flag(mut yylex, 'T441')
    $$.v = $1.v
  }
| trigonometric_function {
    flag(mut yylex, 'T622')
    $$.v = $1.v
  }
| general_logarithm_function {
    flag(mut yylex, 'T623')
    $$.v = $1.v
  }
| common_logarithm {
    flag(mut yylex, 'T624')
    $$.v = $1.v
  }
| natural_logarithm {
    flag(mut yylex, 'T621')
    $$.v = $1.v
  }
| exponential_function {
    flag(mut yylex, 'T621')
    $$.v = $1.v
  }
| power_function {
    flag(mut yylex, 'T621')
    $$.v = $1.v
  }
| square_root {
    flag(mut yylex, 'T621')
    $$.v = $1.v
  }
| floor_function {
    flag(mut yylex, 'T621')
    $$.v = $1.v
  }
| ceiling_function {
    flag(mut yylex, 'T621')
    $$.v = $1.v
  }
| width_bucket_function {
    flag(mut yylex, 'T612')
    $$.v = $1.v
  }

position_expression:
  character_position_expression { $$.v = $1.v }

character_position_expression:
  POSITION left_paren character_value_expression_1 IN
  character_value_expression_2 right_paren {
    $$.v = yy_box(RoutineInvocation{function_name: 'POSITION', args: [
      ValueExpression(CommonValueExpression($3.v as CharacterValueExpression)),
      ValueExpression(CommonValueExpression($5.v as CharacterValueExpression)),
    ]})
  }

character_value_expression_1:
  character_value_expression { $$.v = $1.v }

character_value_expression_2:
  character_value_expression { $$.v = $1.v }

length_expression:
  char_length_expression { $$.v = $1.v }
| octet_length_expression { $$.v = $1.v }

char_length_expression:
  CHAR_LENGTH left_paren character_value_expression right_paren {
    $$.v = yy_box(RoutineInvocation{function_name: 'CHAR_LENGTH', args: [
      ValueExpression(CommonValueExpression($3.v as CharacterValueExpression)),
    ]})
  }
| CHARACTER_LENGTH left_paren character_value_expression right_paren {
    $$.v = yy_box(RoutineInvocation{function_name: 'CHAR_LENGTH', args: [
      ValueExpression(CommonValueExpression($3.v as CharacterValueExpression)),
    ]})
  }

octet_length_expression:
  OCTET_LENGTH left_paren string_value_expression right_paren {
    $$.v = yy_box(RoutineInvocation{function_name: 'OCTET_LENGTH', args: [
      ValueExpression(CommonValueExpression($3.v as CharacterValueExpression)),
    ]})
  }

absolute_value_expression:
  ABS left_paren numeric_value_expression right_paren {
    $$.v = yy_box(RoutineInvocation{function_name: 'ABS', args: [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
    ]})
  }

modulus_expression:
  MOD left_paren numeric_value_expression_dividend comma
  numeric_value_expression_divisor right_paren { 
    flag_mod_argument(mut yylex, $3.v as NumericValueExpression)
    flag_mod_argument(mut yylex, $5.v as NumericValueExpression)
    $$.v = yy_box(RoutineInvocation{function_name: 'MOD', args: [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
      ValueExpression(CommonValueExpression($5.v as NumericValueExpression))
    ]})
  }

numeric_value_expression_dividend:
  numeric_value_expression { $$.v = $1.v }

numeric_value_expression_divisor:
  numeric_value_expression { $$.v = $1.v }

trigonometric_function:
  trigonometric_function_name left_paren numeric_value_expression right_paren {
    $$.v = yy_box(RoutineInvocation{function_name: $1.v as string, args: [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression)),
    ]})
  }

trigonometric_function_name:
  SIN { $$.v = $1.v as string }
| COS { $$.v = $1.v as string }
| TAN { $$.v = $1.v as string }
| SINH { $$.v = $1.v as string }
| COSH { $$.v = $1.v as string }
| TANH { $$.v = $1.v as string }
| ASIN { $$.v = $1.v as string }
| ACOS { $$.v = $1.v as string }
| ATAN { $$.v = $1.v as string }

general_logarithm_function:
  LOG left_paren general_logarithm_base comma general_logarithm_argument
  right_paren {
    $$.v = yy_box(RoutineInvocation{function_name: 'LOG', args: [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression)),
      ValueExpression(CommonValueExpression($5.v as NumericValueExpression))
    ]})
  }

general_logarithm_base:
  numeric_value_expression { $$.v = $1.v }

general_logarithm_argument:
  numeric_value_expression { $$.v = $1.v }

common_logarithm:
  LOG10 left_paren numeric_value_expression right_paren {
    $$.v = yy_box(RoutineInvocation{function_name: 'LOG10', args: [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
    ]})
  }

natural_logarithm:
  LN left_paren numeric_value_expression right_paren {
    $$.v = yy_box(RoutineInvocation{function_name: 'LN', args: [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
    ]})
  }

exponential_function:
  EXP left_paren numeric_value_expression right_paren {
    $$.v = yy_box(RoutineInvocation{function_name: 'EXP', args: [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
    ]})
  }

power_function:
  POWER left_paren numeric_value_expression_base comma
  numeric_value_expression_exponent right_paren {
    $$.v = yy_box(RoutineInvocation{function_name: 'POWER', args: [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression)),
      ValueExpression(CommonValueExpression($5.v as NumericValueExpression))
    ]})
  }

numeric_value_expression_base:
  numeric_value_expression { $$.v = $1.v }

numeric_value_expression_exponent:
  numeric_value_expression { $$.v = $1.v }

square_root:
  SQRT left_paren numeric_value_expression right_paren {
    $$.v = yy_box(RoutineInvocation{function_name: 'SQRT', args: [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
    ]})
  }

floor_function:
  FLOOR left_paren numeric_value_expression right_paren {
    $$.v = yy_box(RoutineInvocation{function_name: 'FLOOR', args: [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
    ]})
  }

ceiling_function:
  CEIL left_paren numeric_value_expression right_paren {
    $$.v = yy_box(RoutineInvocation{function_name: 'CEILING', args: [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
    ]})
  }
| CEILING left_paren numeric_value_expression right_paren   { 
    $$.v = yy_box(RoutineInvocation{function_name: 'CEILING', args: [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
    ]})
  }

width_bucket_function:
  WIDTH_BUCKET left_paren numeric_value_expression comma
  numeric_value_expression comma numeric_value_expression comma
  numeric_value_expression right_paren {
    $$.v = yy_box(RoutineInvocation{function_name: 'WIDTH_BUCKET', args: [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
      ValueExpression(CommonValueExpression($5.v as NumericValueExpression))
      ValueExpression(CommonValueExpression($7.v as NumericValueExpression))
      ValueExpression(CommonValueExpression($9.v as NumericValueExpression))
    ]})
  }

%%
