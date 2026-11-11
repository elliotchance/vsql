%%

// was: COUNT left_paren asterisk right_paren
aggregate_function:
  COUNT OPERATOR_LEFT_PAREN_ASTERISK right_paren {
    parsed_sort_key_part(mut yylex, .set_function)
    $$.v = yy_box(AggregateFunction(AggregateFunctionCount{}))
  }
| COUNT OPERATOR_LEFT_PAREN_ASTERISK right_paren filter_clause {
    parsed_sort_key_part(mut yylex, .set_function)
    $$.v = yy_box(AggregateFunction(AggregateFunctionCount{
      filter: &BooleanValueExpression{
        ...$4.v as BooleanValueExpression
      }
    }))
  }
| general_set_function {
    parsed_sort_key_part(mut yylex, .set_function)
    $$.v = $1.v
  }
| general_set_function filter_clause {
    parsed_sort_key_part(mut yylex, .set_function)
    $$.v = yy_box(with_filter($1.v as AggregateFunction, $2.v as BooleanValueExpression))
  }
| binary_set_function {
    parsed_sort_key_part(mut yylex, .set_function)
    $$.v = $1.v
  }
| listagg_set_function {
    parsed_sort_key_part(mut yylex, .set_function)
    $$.v = yy_box(AggregateFunction($1.v as ListaggSetFunction))
  }
| listagg_set_function filter_clause {
    parsed_sort_key_part(mut yylex, .set_function)
    $$.v = yy_box(with_filter(AggregateFunction($1.v as ListaggSetFunction),
      $2.v as BooleanValueExpression))
  }
| ordered_set_function {
    parsed_sort_key_part(mut yylex, .set_function)
    $$.v = yy_box(AggregateFunction($1.v as OrderedSetFunction))
  }
| ordered_set_function filter_clause {
    parsed_sort_key_part(mut yylex, .set_function)
    $$.v = yy_box(with_filter(AggregateFunction($1.v as OrderedSetFunction),
      $2.v as BooleanValueExpression))
  }

// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Conformance Rules, 13
filter_clause:
  FILTER left_paren WHERE search_condition right_paren {
    flag(mut yylex, 'T612')
    $$.v = $4.v
  }

// ALL is the same as no <set quantifier>.
//
// SOME and ANY are also the quantifiers of a <quantified comparison predicate>,
// such as x = ANY (SELECT ...). So they aren't a <computational operation>
// here, which lets the parser wait until after the "(" to choose: a subquery
// is a quantified comparison, anything else is this aggregate function.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 3
general_set_function:
  set_function_type left_paren value_expression right_paren {
    flag_if(mut yylex, $1.v as string == 'COUNT', 'F441')
    $$.v = yy_box(AggregateFunction(RoutineInvocation{
      function_name: $1.v as string
      args:          [$3.v as ValueExpression]
    }))
  }
| set_function_type left_paren set_quantifier value_expression right_paren {
    flag_set_quantifier(mut yylex, $1.v as string, $3.v as bool, $4.v as ValueExpression)
    $$.v = yy_box(AggregateFunction(RoutineInvocation{
      function_name: $1.v as string
      args:          [$4.v as ValueExpression]
      distinct:      $3.v as bool
    }))
  }
| SOME left_paren value_expression right_paren {
    flag(mut yylex, 'T031')
    $$.v = yy_box(AggregateFunction(RoutineInvocation{
      function_name: $1.v as string
      args:          [$3.v as ValueExpression]
    }))
  }
| SOME left_paren set_quantifier value_expression right_paren {
    flag(mut yylex, 'T031')
    flag_set_quantifier(mut yylex, $1.v as string, $3.v as bool, $4.v as ValueExpression)
    $$.v = yy_box(AggregateFunction(RoutineInvocation{
      function_name: $1.v as string
      args:          [$4.v as ValueExpression]
      distinct:      $3.v as bool
    }))
  }
| ANY left_paren value_expression right_paren {
    flag(mut yylex, 'T031')
    $$.v = yy_box(AggregateFunction(RoutineInvocation{
      function_name: $1.v as string
      args:          [$3.v as ValueExpression]
    }))
  }
| ANY left_paren set_quantifier value_expression right_paren {
    flag(mut yylex, 'T031')
    flag_set_quantifier(mut yylex, $1.v as string, $3.v as bool, $4.v as ValueExpression)
    $$.v = yy_box(AggregateFunction(RoutineInvocation{
      function_name: $1.v as string
      args:          [$4.v as ValueExpression]
      distinct:      $3.v as bool
    }))
  }
| statistical_operation left_paren value_expression right_paren {
    flag(mut yylex, 'T621')
    $$.v = yy_box(AggregateFunction(RoutineInvocation{
      function_name: $1.v as string
      args:          [$3.v as ValueExpression]
    }))
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

// The other <ordered set function>s are an OrderedSetFunction.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 11.c
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Conformance Rules, 23
listagg_set_function:
  LISTAGG left_paren character_value_expression comma listagg_separator
  right_paren within_group_specification {
    flag(mut yylex, 'T625')
    $$.v = yy_box(new_listagg_set_function(false, $3.v as CharacterValueExpression,
      $5.v as Value, ListaggOverflow{}, $7.v as []SortSpecification))
  }
| LISTAGG left_paren character_value_expression comma listagg_separator
  listagg_overflow_clause right_paren within_group_specification {
    flag(mut yylex, 'T625')
    $$.v = yy_box(new_listagg_set_function(false, $3.v as CharacterValueExpression,
      $5.v as Value, $6.v as ListaggOverflow, $8.v as []SortSpecification))
  }
| LISTAGG left_paren set_quantifier character_value_expression comma
  listagg_separator right_paren within_group_specification {
    flag(mut yylex, 'T625')
    $$.v = yy_box(new_listagg_set_function($3.v as bool, $4.v as CharacterValueExpression,
      $6.v as Value, ListaggOverflow{}, $8.v as []SortSpecification))
  }
| LISTAGG left_paren set_quantifier character_value_expression comma
  listagg_separator listagg_overflow_clause right_paren
  within_group_specification {
    flag(mut yylex, 'T625')
    $$.v = yy_box(new_listagg_set_function($3.v as bool, $4.v as CharacterValueExpression,
      $6.v as Value, $7.v as ListaggOverflow, $9.v as []SortSpecification))
  }

// A <hypothetical set function> or an <inverse distribution function>. A
// <listagg set function> is also an <ordered set function>, but it's a
// ListaggSetFunction.
//
// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Conformance Rules, 12
ordered_set_function:
  rank_function_type left_paren
  hypothetical_set_function_value_expression_list right_paren
  within_group_specification {
    flag(mut yylex, 'T612')
    $$.v = yy_box(OrderedSetFunction{
      name:  $1.v as string
      args:  $3.v as []ValueExpression
      order: $5.v as []SortSpecification
    })
  }
| inverse_distribution_function_type left_paren numeric_value_expression
  right_paren within_group_specification {
    flag(mut yylex, 'T612')
    $$.v = yy_box(OrderedSetFunction{
      name:  $1.v as string
      args:  [ValueExpression(CommonValueExpression($3.v as NumericValueExpression))]
      order: $5.v as []SortSpecification
    })
  }

rank_function_type:
  RANK { $$.v = $1.v as string }
| DENSE_RANK { $$.v = $1.v as string }
| PERCENT_RANK { $$.v = $1.v as string }
| CUME_DIST { $$.v = $1.v as string }

hypothetical_set_function_value_expression_list:
  value_expression { $$.v = yy_box([$1.v as ValueExpression]) }
| hypothetical_set_function_value_expression_list comma value_expression {
    $$.v = yy_box(append_list($1.v as []ValueExpression, $3.v as ValueExpression))
  }

inverse_distribution_function_type:
  PERCENTILE_CONT { $$.v = $1.v as string }
| PERCENTILE_DISC { $$.v = $1.v as string }

// The sort keys aren't the <sort key>s of an ORDER BY of a query, so they
// aren't flagged (see flag_sort_key).
within_group_specification:
  WITHIN GROUP left_paren ORDER BY within_group_sort_specification_list
  right_paren { $$.v = $6.v }

within_group_sort_specification_list:
  within_group_sort_specification {
    $$.v = yy_box([$1.v as SortSpecification])
  }
| within_group_sort_specification_list comma within_group_sort_specification {
    $$.v = yy_box(append_list($1.v as []SortSpecification, $3.v as SortSpecification))
  }

within_group_sort_specification:
  value_expression { $$.v = yy_box(SortSpecification{$1.v as ValueExpression, true}) }
| value_expression ordering_specification {
    $$.v = yy_box(SortSpecification{$1.v as ValueExpression, $2.v as bool})
  }

listagg_separator:
  character_string_literal { $$.v = $1.v }

// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>, Syntax Rules, 11.f and 11.g
listagg_overflow_clause:
  ON OVERFLOW ERROR { $$.v = yy_box(ListaggOverflow{}) }
| ON OVERFLOW TRUNCATE listagg_count_indication {
    $$.v = yy_box(ListaggOverflow{
      truncate:   true
      filler:     new_varchar_value('...')
      with_count: $4.v as bool
    })
  }
| ON OVERFLOW TRUNCATE listagg_truncation_filler listagg_count_indication {
    $$.v = yy_box(ListaggOverflow{
      truncate:   true
      filler:     $4.v as Value
      with_count: $5.v as bool
    })
  }

listagg_truncation_filler:
  character_string_literal { $$.v = $1.v }

// WITH COUNT is true.
listagg_count_indication:
  WITH COUNT { $$.v = true }
| WITHOUT COUNT { $$.v = false }

computational_operation:
  AVG { $$.v = $1.v as string }
| MAX { $$.v = $1.v as string }
| MIN { $$.v = $1.v as string }
| SUM { $$.v = $1.v as string }
| COUNT { $$.v = $1.v as string }
| EVERY {
    flag(mut yylex, 'T031')
    $$.v = $1.v as string
  }

binary_set_function:
  binary_set_function_type left_paren dependent_variable_expression comma
  independent_variable_expression right_paren {
    flag(mut yylex, 'T621')
    $$.v = yy_box(AggregateFunction(RoutineInvocation{function_name: $1.v as string, args: [
      ValueExpression(CommonValueExpression($3.v as NumericValueExpression)),
      ValueExpression(CommonValueExpression($5.v as NumericValueExpression)),
    ]}))
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
  numeric_value_expression { $$.v = $1.v }

independent_variable_expression:
  numeric_value_expression { $$.v = $1.v }

%%
