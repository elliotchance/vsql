%%

table_row_value_expression:
  row_value_constructor { $$.v = $1.v as RowValueConstructor }

contextually_typed_row_value_expression:
  contextually_typed_row_value_constructor {
    $$.v = $1.v as ContextuallyTypedRowValueConstructor
  }

row_value_predicand:
  row_value_constructor_predicand {
    $$.v = $1.v as RowValueConstructorPredicand
  }

%%