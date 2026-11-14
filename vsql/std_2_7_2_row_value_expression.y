%%

// ISO/IEC 9075-2:2023, 7.2, <row value expression>
//
// Specify a row value.

table_row_value_expression:
  row_value_constructor { $$.v = $1.v }

contextually_typed_row_value_expression:
  contextually_typed_row_value_constructor {
    $$.v = $1.v
  }

row_value_predicand:
  row_value_constructor_predicand {
    $$.v = $1.v
  }

%%
