%%

// The "(a, b)" form uses the contextually typed elements of a VALUES row (which
// allow NULL and DEFAULT) so the parser doesn't have to choose between them
// before it sees IS. new_null_predicate_row rejects a NULL or DEFAULT.
null_predicate:
  row_value_predicand null_predicate_part_2 {
    $$.v = NullPredicate{NullPredicand($1.v as RowValueConstructorPredicand),
      !($2.v as bool)}
  }
| ROW left_paren row_value_constructor_element_list right_paren
  null_predicate_part_2 {
    flag(mut yylex, 'T051')
    flag_if(mut yylex, ($3.v as []ValueExpression).len > 1, 'F641')
    $$.v = NullPredicate{NullPredicand(ExplicitRowValueConstructor{$3.v as []ValueExpression}),
      !($5.v as bool)}
  }
| left_paren contextually_typed_row_value_constructor_element comma
  contextually_typed_row_value_constructor_element_list right_paren
  null_predicate_part_2 {
    flag(mut yylex, 'F641')
    $$.v = new_null_predicate_row(push_list(
      $2.v as ContextuallyTypedRowValueConstructorElement,
      $4.v as []ContextuallyTypedRowValueConstructorElement),
      !($6.v as bool))!
  }

null_predicate_part_2:
  IS NULL { $$.v = true }
| IS NOT NULL { $$.v = false }

%%
