%%

row_value_constructor:
  common_value_expression {
    $$.v = RowValueConstructor($1.v as CommonValueExpression)
  }
| boolean_value_expression {
    $$.v = RowValueConstructor($1.v as BooleanValueExpression)
  }
| explicit_row_value_constructor {
    $$.v = RowValueConstructor($1.v as ExplicitRowValueConstructor)
  }

explicit_row_value_constructor:
  ROW left_paren row_value_constructor_element_list right_paren {
    $$.v = ExplicitRowValueConstructor(ExplicitRowValueConstructorRow{$3.v as []ValueExpression})
  }
| row_subquery { $$.v = ExplicitRowValueConstructor($1.v as QueryExpression) }

row_value_constructor_element_list:
  row_value_constructor_element { $$.v = [$1.v as ValueExpression] }
| row_value_constructor_element_list comma row_value_constructor_element {
    $$.v = append_list($1.v as []ValueExpression, $3.v as ValueExpression)
  }

row_value_constructor_element:
  value_expression { $$.v = $1.v as ValueExpression }

contextually_typed_row_value_constructor:
  common_value_expression {
    $$.v = ContextuallyTypedRowValueConstructor($1.v as CommonValueExpression) 
  }
| boolean_value_expression {
    $$.v = ContextuallyTypedRowValueConstructor($1.v as BooleanValueExpression)
  }
| contextually_typed_value_specification {
    $$.v = ContextuallyTypedRowValueConstructor($1.v as NullSpecification)
  }
| left_paren contextually_typed_value_specification right_paren {
    $$.v = ContextuallyTypedRowValueConstructor($2.v as NullSpecification)
  }
| left_paren contextually_typed_row_value_constructor_element comma
  contextually_typed_row_value_constructor_element_list right_paren {
    $$.v = ContextuallyTypedRowValueConstructor(push_list(
      $2.v as ContextuallyTypedRowValueConstructorElement,
      $4.v as []ContextuallyTypedRowValueConstructorElement))
  }

contextually_typed_row_value_constructor_element_list:
  contextually_typed_row_value_constructor_element {
    $$.v = [$1.v as ContextuallyTypedRowValueConstructorElement]
  }
| contextually_typed_row_value_constructor_element_list comma
  contextually_typed_row_value_constructor_element {
    $$.v = append_list($1.v as []ContextuallyTypedRowValueConstructorElement,
      $3.v as ContextuallyTypedRowValueConstructorElement)
  }

contextually_typed_row_value_constructor_element:
  value_expression {
    $$.v = ContextuallyTypedRowValueConstructorElement($1.v as ValueExpression)
  }
| contextually_typed_value_specification {
    $$.v = ContextuallyTypedRowValueConstructorElement($1.v as NullSpecification)
  }

row_value_constructor_predicand:
  common_value_expression {
    $$.v = RowValueConstructorPredicand($1.v as CommonValueExpression)
  }
| boolean_predicand {
    $$.v = RowValueConstructorPredicand($1.v as BooleanPredicand)
  }

%%
