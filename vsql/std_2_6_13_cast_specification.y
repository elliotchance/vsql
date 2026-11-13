%%

cast_specification:
  CAST left_paren cast_operand AS cast_target right_paren {
	  $$.v = yy_box(new_cast_specification($3.v as CastOperand, $5.v as Type))
  }

cast_operand:
  value_expression { $$.v = yy_box(CastOperand($1.v as ValueExpression)) }
| implicitly_typed_value_specification {
    $$.v = yy_box(CastOperand($1.v as NullSpecification))
  }

cast_target:
  data_type { $$.v = $1.v }

// pg_cast is the PostgreSQL shorthand for a CAST (V303-01): "x::type" is
// "CAST(x AS type)". Like PostgreSQL, it applies to the value expression
// primary before it, so "-1::INT" is "-CAST(1 AS INT)" and "x::INT::BIGINT"
// casts twice.
pg_cast:
  value_expression_primary OPERATOR_DOUBLE_COLON cast_target {
    flag(mut yylex, vsql_double_colon_cast)
    $$.v = yy_box(new_cast_specification(CastOperand(ValueExpression(CommonValueExpression(DatetimePrimary($1.v as ValueExpressionPrimary)))),
      $3.v as Type))
  }
| null_specification OPERATOR_DOUBLE_COLON cast_target {
    flag(mut yylex, vsql_double_colon_cast)
    $$.v = yy_box(new_cast_specification(CastOperand($1.v as NullSpecification), $3.v as Type))
  }

%%
