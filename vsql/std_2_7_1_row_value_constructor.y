%%

// ISO/IEC 9075-2:2016(E), 7.1, <row value constructor>
//
// Specify a value or list of values to be constructed into a row.

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

// A row in parentheses is parsed with the contextually typed elements of a
// VALUES row (which allow NULL and DEFAULT), so that the parser doesn't have to
// choose between them before it sees what follows the row.
// new_explicit_row_value_constructor rejects a NULL or DEFAULT.
explicit_row_value_constructor:
  left_paren contextually_typed_row_value_constructor_element comma
  contextually_typed_row_value_constructor_element_list right_paren {
    $$.v = new_explicit_row_value_constructor(push_list(
      $2.v as ContextuallyTypedRowValueConstructorElement,
      $4.v as []ContextuallyTypedRowValueConstructorElement))!
  }
| ROW left_paren row_value_constructor_element_list right_paren {
    // ISO/IEC 9075-2:2016(E), 7.1, <row value constructor>, Conformance Rules, 1
    flag(mut yylex, 'T051')
    $$.v = ExplicitRowValueConstructor{$3.v as []ValueExpression}
  }

row_value_constructor_element_list:
  row_value_constructor_element { $$.v = [$1.v as ValueExpression] }
| row_value_constructor_element_list comma row_value_constructor_element {
    $$.v = append_list($1.v as []ValueExpression, $3.v as ValueExpression)
  }

row_value_constructor_element:
  value_expression { $$.v = $1.v as ValueExpression }

// Without F641, a VALUES of an INSERT can only have one row, in parentheses.
//
// ISO/IEC 9075-2:2016(E), 7.3, <table value constructor>, Conformance Rules, 1

contextually_typed_row_value_constructor:
  common_value_expression {
    expr := $1.v as CommonValueExpression
    flag_if(mut yylex, !is_parenthesized(expr), 'F641')
    $$.v = ContextuallyTypedRowValueConstructor($1.v as CommonValueExpression) 
  }
| boolean_value_expression {
    expr := $1.v as BooleanValueExpression
    flag_if(mut yylex, !is_parenthesized_boolean(expr), 'F641')
    $$.v = ContextuallyTypedRowValueConstructor($1.v as BooleanValueExpression)
  }
| contextually_typed_value_specification {
    flag(mut yylex, 'F641')
    $$.v = ContextuallyTypedRowValueConstructor($1.v as ContextuallyTypedValueSpecification)
  }
| left_paren contextually_typed_value_specification right_paren {
    $$.v = ContextuallyTypedRowValueConstructor($2.v as ContextuallyTypedValueSpecification)
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
    $$.v = ContextuallyTypedRowValueConstructorElement($1.v as ContextuallyTypedValueSpecification)
  }

row_value_constructor_predicand:
  common_value_expression {
    $$.v = RowValueConstructorPredicand($1.v as CommonValueExpression)
  }
| boolean_predicand {
    $$.v = RowValueConstructorPredicand($1.v as BooleanPredicand)
  }
| explicit_row_value_constructor {
    row := $1.v as ExplicitRowValueConstructor
    // ISO/IEC 9075-2:2016(E), 7.1, <row value constructor>, Conformance Rules, 3
    flag_if(mut yylex, row.exprs.len > 1, 'F641')
    $$.v = RowValueConstructorPredicand(row)
  }

%%
