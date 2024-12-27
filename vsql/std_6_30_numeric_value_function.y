%%

numeric_value_function:
  position_expression { $$.v = $1.v as RoutineInvocation }
| length_expression { $$.v = $1.v as RoutineInvocation }
| absolute_value_expression { $$.v = $1.v as RoutineInvocation }
| modulus_expression { $$.v = $1.v as RoutineInvocation }
| trigonometric_function { $$.v = $1.v as RoutineInvocation }
| common_logarithm { $$.v = $1.v as RoutineInvocation }
| natural_logarithm { $$.v = $1.v as RoutineInvocation }
| exponential_function { $$.v = $1.v as RoutineInvocation }
| power_function { $$.v = $1.v as RoutineInvocation }
| square_root { $$.v = $1.v as RoutineInvocation }
| floor_function { $$.v = $1.v as RoutineInvocation }
| ceiling_function { $$.v = $1.v as RoutineInvocation }

position_expression:
  character_position_expression { $$.v = $1.v as RoutineInvocation }

character_position_expression:
  POSITION left_paren character_value_expression_1 IN
  character_value_expression_2 right_paren {
    $$.v = RoutineInvocation{'POSITION', [
      ValueExpression(CommonValueExpression($3.v as CharacterValueExpression)),
      ValueExpression(CommonValueExpression($5.v as CharacterValueExpression)),
    ]}
  }

character_value_expression_1:
  character_value_expression { $$.v = $1.v as CharacterValueExpression }

character_value_expression_2:
  character_value_expression { $$.v = $1.v as CharacterValueExpression }

length_expression:
  char_length_expression { $$.v = $1.v as RoutineInvocation }
| octet_length_expression { $$.v = $1.v as RoutineInvocation }

char_length_expression:
  CHAR_LENGTH left_paren character_value_expression right_paren {
    $$.v = RoutineInvocation{'CHAR_LENGTH', [
      ValueExpression(CommonValueExpression($3.v as CharacterValueExpression)),
    ]}
  }
| CHARACTER_LENGTH left_paren character_value_expression right_paren {
    $$.v = RoutineInvocation{'CHAR_LENGTH', [
      ValueExpression(CommonValueExpression($3.v as CharacterValueExpression)),
    ]}
  }

octet_length_expression:
  OCTET_LENGTH left_paren string_value_expression right_paren {
    $$.v = RoutineInvocation{'OCTET_LENGTH', [
      ValueExpression(CommonValueExpression($3.v as CharacterValueExpression)),
    ]}
  }

absolute_value_expression:
  ABS left_paren numeric_value_expression right_paren {
    $$.v = RoutineInvocation{'ABS', [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
    ]}
  }

modulus_expression:
  MOD left_paren numeric_value_expression_dividend comma
  numeric_value_expression_divisor right_paren { 
    $$.v = RoutineInvocation{'MOD', [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
      ValueExpression(CommonValueExpression($5.v as NumericValueExpression))
    ]}
  }

numeric_value_expression_dividend:
  numeric_value_expression { $$.v = $1.v as NumericValueExpression }

numeric_value_expression_divisor:
  numeric_value_expression { $$.v = $1.v as NumericValueExpression }

trigonometric_function:
  trigonometric_function_name left_paren numeric_value_expression right_paren {
    $$.v = RoutineInvocation{$1.v as string, [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression)),
    ]}
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

common_logarithm:
  LOG10 left_paren numeric_value_expression right_paren {
    $$.v = RoutineInvocation{'LOG10', [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
    ]}
  }

natural_logarithm:
  LN left_paren numeric_value_expression right_paren {
    $$.v = RoutineInvocation{'LN', [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
    ]}
  }

exponential_function:
  EXP left_paren numeric_value_expression right_paren {
    $$.v = RoutineInvocation{'EXP', [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
    ]}
  }

power_function:
  POWER left_paren numeric_value_expression_base comma
  numeric_value_expression_exponent right_paren {
    $$.v = RoutineInvocation{'POWER', [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression)),
      ValueExpression(CommonValueExpression($5.v as NumericValueExpression))
    ]}
  }

numeric_value_expression_base:
  numeric_value_expression { $$.v = $1.v as NumericValueExpression }

numeric_value_expression_exponent:
  numeric_value_expression { $$.v = $1.v as NumericValueExpression }

square_root:
  SQRT left_paren numeric_value_expression right_paren {
    $$.v = RoutineInvocation{'SQRT', [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
    ]}
  }

floor_function:
  FLOOR left_paren numeric_value_expression right_paren {
    $$.v = RoutineInvocation{'FLOOR', [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
    ]}
  }

ceiling_function:
  CEIL left_paren numeric_value_expression right_paren {
    $$.v = RoutineInvocation{'CEILING', [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
    ]}
  }
| CEILING left_paren numeric_value_expression right_paren   { 
    $$.v = RoutineInvocation{'CEILING', [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression))
    ]}
  }

%%
