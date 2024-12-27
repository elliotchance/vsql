%%

cast_specification:
  CAST left_paren cast_operand AS cast_target right_paren {
	  $$.v = CastSpecification{$3.v as CastOperand, $5.v as Type}
  }

cast_operand:
  value_expression { $$.v = CastOperand($1.v as ValueExpression) }
| implicitly_typed_value_specification {
    $$.v = CastOperand($1.v as NullSpecification)
  }

cast_target:
  data_type { $$.v = $1.v as Type }

%%
