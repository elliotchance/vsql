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

common_value_expression:
  numeric_value_expression {
    $$.v = CommonValueExpression($1.v as NumericValueExpression)
  }
| string_value_expression {
    $$.v = CommonValueExpression($1.v as CharacterValueExpression)
  }
| datetime_value_expression {
    $$.v = CommonValueExpression($1.v as DatetimePrimary)
  }

%%
