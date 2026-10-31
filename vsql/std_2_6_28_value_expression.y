%%

// ISO/IEC 9075-2:2016(E), 6.28, <value expression>
//
// Specify a value.

value_expression:
  common_value_expression {
    $$.v = ValueExpression($1.v as CommonValueExpression)
  }
| boolean_value_expression {
    // ISO/IEC 9075-2:2016(E), 6.28, <value expression>, Conformance Rules, 1
    // ISO/IEC 9075-2:2016(E), 6.39, <boolean value expression>, Conformance Rules, 1
    flag_if(mut yylex, is_boolean_operation($1.v as BooleanValueExpression), 'T031')
    $$.v = ValueExpression($1.v as BooleanValueExpression)
  }

// A value_expression_primary on its own could be a numeric, string, datetime
// or boolean expression, its type decides which. The parser can't know the
// type, so a common_value_expression must have an operator or a function that
// makes it one of these, and anything else is a boolean_value_expression (see
// boolean_predicand). The exception is a common_value_expression in
// parentheses, which can't be a boolean_value_expression. It's a
// DatetimePrimary because that's how it was parsed before (any type works).
common_value_expression:
  parenthesized_value_expression {
    $$.v = CommonValueExpression(DatetimePrimary(ValueExpressionPrimary($1.v as ParenthesizedValueExpression)))
  }
| operator_numeric_value_expression {
    $$.v = CommonValueExpression($1.v as NumericValueExpression)
  }
| concatenation {
    $$.v = CommonValueExpression(CharacterValueExpression($1.v as Concatenation))
  }
| string_value_function {
    $$.v = CommonValueExpression(CharacterValueExpression(CharacterPrimary($1.v as CharacterValueFunction)))
  }
| datetime_value_expression {
    $$.v = CommonValueExpression($1.v as DatetimePrimary)
  }

%%
