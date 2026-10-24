%%

table_value_constructor:
  VALUES row_value_expression_list {
    $$.v = SimpleTable($2.v as []RowValueConstructor)
  }

row_value_expression_list:
  table_row_value_expression { $$.v = [$1.v as RowValueConstructor] }
| row_value_expression_list comma table_row_value_expression {
    $$.v = append_list($1.v as []RowValueConstructor,
      $3.v as RowValueConstructor)
  }

contextually_typed_table_value_constructor:
  VALUES contextually_typed_row_value_expression_list {
    $$.v = $2.v as []ContextuallyTypedRowValueConstructor
  }

contextually_typed_row_value_expression_list:
  contextually_typed_row_value_expression {
    $$.v = [$1.v as ContextuallyTypedRowValueConstructor]
  }
| contextually_typed_row_value_expression_list comma
  contextually_typed_row_value_expression {
    $$.v = append_list($1.v as []ContextuallyTypedRowValueConstructor,
      $3.v as ContextuallyTypedRowValueConstructor)
  }

%%
