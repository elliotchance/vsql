%%

value_expression:
  common_value_expression {
    $$.v = ValueExpression($1.v as CommonValueExpression)
  }
| boolean_value_expression {
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
