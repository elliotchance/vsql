%%

// was: COUNT left_paren asterisk right_paren
aggregate_function:
  COUNT OPERATOR_LEFT_PAREN_ASTERISK right_paren {
    parsed_sort_key_part(mut yylex, .set_function)
    $$.v = AggregateFunction(AggregateFunctionCount{})
  }
| general_set_function {
    parsed_sort_key_part(mut yylex, .set_function)
    $$.v = $1.v as AggregateFunction
  }
| binary_set_function {
    parsed_sort_key_part(mut yylex, .set_function)
    $$.v = $1.v as AggregateFunction
  }

// ALL is the same as no <set quantifier>.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 3
general_set_function:
  set_function_type left_paren value_expression right_paren {
    flag_if(mut yylex, $1.v as string == 'COUNT', 'F441')
    $$.v = AggregateFunction(RoutineInvocation{
      $1.v as string, [$3.v as ValueExpression], false})
  }
| set_function_type left_paren set_quantifier value_expression right_paren {
    flag_set_quantifier(mut yylex, $1.v as string, $3.v as bool, $4.v as ValueExpression)
    $$.v = AggregateFunction(RoutineInvocation{
      $1.v as string, [$4.v as ValueExpression], $3.v as bool})
  }
| statistical_operation left_paren value_expression right_paren {
    flag(mut yylex, 'T621')
    $$.v = AggregateFunction(RoutineInvocation{
      $1.v as string, [$3.v as ValueExpression], false})
  }

// STDDEV_POP, STDDEV_SAMP, VAR_POP and VAR_SAMP are a <computational
// operation>, but they're a separate rule because they can't have a <set
// quantifier>. They're flagged with T621, like a <binary set function>.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 2
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Conformance Rules, 10 and 11
statistical_operation:
  STDDEV_POP { $$.v = $1.v as string }
| STDDEV_SAMP { $$.v = $1.v as string }
| VAR_SAMP { $$.v = $1.v as string }
| VAR_POP { $$.v = $1.v as string }

// DISTINCT is true.
set_quantifier:
  ALL { $$.v = false }
| DISTINCT { $$.v = true }

set_function_type:
  computational_operation { $$.v = $1.v as string }

computational_operation:
  AVG { $$.v = $1.v as string }
| MAX { $$.v = $1.v as string }
| MIN { $$.v = $1.v as string }
| SUM { $$.v = $1.v as string }
| COUNT { $$.v = $1.v as string }

binary_set_function:
  binary_set_function_type left_paren dependent_variable_expression comma
  independent_variable_expression right_paren {
    flag(mut yylex, 'T621')
    $$.v = AggregateFunction(RoutineInvocation{function_name: $1.v as string, args: [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression)),
      ValueExpression(CommonValueExpression($5.v as NumericValueExpression)),
    ]})
  }

binary_set_function_type:
  COVAR_POP { $$.v = $1.v as string }
| COVAR_SAMP { $$.v = $1.v as string }
| CORR { $$.v = $1.v as string }
| REGR_SLOPE { $$.v = $1.v as string }
| REGR_INTERCEPT { $$.v = $1.v as string }
| REGR_COUNT { $$.v = $1.v as string }
| REGR_R2 { $$.v = $1.v as string }
| REGR_AVGX { $$.v = $1.v as string }
| REGR_AVGY { $$.v = $1.v as string }
| REGR_SXX { $$.v = $1.v as string }
| REGR_SYY { $$.v = $1.v as string }
| REGR_SXY { $$.v = $1.v as string }

dependent_variable_expression:
  numeric_value_expression { $$.v = $1.v as NumericValueExpression }

independent_variable_expression:
  numeric_value_expression { $$.v = $1.v as NumericValueExpression }

%%
