%%

// ISO/IEC 9075-2:2016(E), 7.3, <table value constructor>
//
// Specify a set of <row value expression>s to be constructed into a table.

table_value_constructor:
  VALUES row_value_expression_list {
    // ISO/IEC 9075-2:2016(E), 7.3, <table value constructor>, Conformance Rules, 2
    flag(mut yylex, 'F641')
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
    // ISO/IEC 9075-2:2016(E), 7.3, <table value constructor>, Conformance Rules, 1
    flag(mut yylex, 'F641')
    $$.v = append_list($1.v as []ContextuallyTypedRowValueConstructor,
      $3.v as ContextuallyTypedRowValueConstructor)
  }

%%
