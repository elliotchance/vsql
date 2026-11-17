%%

// ISO/IEC 9075-2:2023, 6.31, <numeric value function>
//
// Specify a function yielding a value of type numeric.
//
// Each function is flagged with its feature. EXTRACT needs F052, and F411 as
// well for a time zone field.
//
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Conformance Rules, 3-4
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Conformance Rules, 9-11
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Conformance Rules, 13-20

numeric_value_function:
  position_expression { $$.v = yy_box(NumericPrimary($1.v as RoutineInvocation)) }
| length_expression { $$.v = yy_box(NumericPrimary($1.v as RoutineInvocation)) }
| absolute_value_expression {
    flag(mut yylex, 'T441')
    $$.v = yy_box(NumericPrimary($1.v as RoutineInvocation))
  }
| modulus_expression {
    flag(mut yylex, 'T441')
    $$.v = yy_box(NumericPrimary($1.v as RoutineInvocation))
  }
| trigonometric_function {
    flag(mut yylex, 'T622')
    $$.v = yy_box(NumericPrimary($1.v as RoutineInvocation))
  }
| general_logarithm_function {
    flag(mut yylex, 'T623')
    $$.v = yy_box(NumericPrimary($1.v as RoutineInvocation))
  }
| common_logarithm {
    flag(mut yylex, 'T624')
    $$.v = yy_box(NumericPrimary($1.v as RoutineInvocation))
  }
| natural_logarithm {
    flag(mut yylex, 'T621')
    $$.v = yy_box(NumericPrimary($1.v as RoutineInvocation))
  }
| exponential_function {
    flag(mut yylex, 'T621')
    $$.v = yy_box(NumericPrimary($1.v as RoutineInvocation))
  }
| power_function {
    flag(mut yylex, 'T621')
    $$.v = yy_box(NumericPrimary($1.v as RoutineInvocation))
  }
| square_root {
    flag(mut yylex, 'T621')
    $$.v = yy_box(NumericPrimary($1.v as RoutineInvocation))
  }
| floor_function {
    flag(mut yylex, 'T621')
    $$.v = yy_box(NumericPrimary($1.v as RoutineInvocation))
  }
| ceiling_function {
    flag(mut yylex, 'T621')
    $$.v = yy_box(NumericPrimary($1.v as RoutineInvocation))
  }
| width_bucket_function {
    flag(mut yylex, 'T612')
    $$.v = yy_box(NumericPrimary($1.v as RoutineInvocation))
  }
| extract_expression {
    e := $1.v as ExtractExpression
    flag(mut yylex, 'F052')
    flag_if(mut yylex, e.field in ['TIMEZONE_HOUR', 'TIMEZONE_MINUTE'], 'F411')
    if feature := vsql_extract_fields[e.field] {
      flag(mut yylex, feature)
    }
    $$.v = yy_box(NumericPrimary(e))
  }

// The <extract source> can be any value expression (a datetime_value_expression
// is only a datetime value function, see datetime_primary), so its type is
// checked when it's compiled. There are no intervals (F052).
extract_expression:
  EXTRACT left_paren extract_field FROM value_expression right_paren {
    source := $5.v as ValueExpression
    $$.v = yy_box(ExtractExpression{$3.v as string, &source})
  }

extract_field:
  primary_datetime_field { $$.v = $1.v }
| time_zone_field { $$.v = $1.v }
// The fields that aren't in the standard, such as DOW, are a vsql extension
// (V402-02 to V402-08). They aren't keywords, so a field is any identifier, and
// one that isn't a field is an error when it's compiled.
| LITERAL_IDENTIFIER {
    name := ($1.v as IdentifierChain).identifier
    $$.v = if name.starts_with('"') { name } else { name.to_upper() }
  }

// primary_datetime_field and non_second_primary_datetime_field are from
// <interval qualifier> (10.1), but there are no intervals.
primary_datetime_field:
  non_second_primary_datetime_field { $$.v = $1.v }
| SECOND { $$.v = 'SECOND' }

non_second_primary_datetime_field:
  YEAR { $$.v = 'YEAR' }
| MONTH { $$.v = 'MONTH' }
| DAY { $$.v = 'DAY' }
| HOUR { $$.v = 'HOUR' }
| MINUTE { $$.v = 'MINUTE' }

time_zone_field:
  TIMEZONE_HOUR { $$.v = 'TIMEZONE_HOUR' }
| TIMEZONE_MINUTE { $$.v = 'TIMEZONE_MINUTE' }

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
