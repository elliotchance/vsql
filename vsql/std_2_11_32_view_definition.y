%%

// Only a <regular view specification> is supported, without RECURSIVE (T131)
// or CHECK OPTION (F311-04, F751).
view_definition:
  CREATE VIEW table_name AS query_expression {
    flag_view_query(mut yylex, $5.v as QueryExpression)
    $$.v = yy_box(ViewDefinition{
      view_name:      $3.v as Identifier
      query:          $5.v as QueryExpression
      has_parameters: has_dynamic_parameters(yylex)
    })
  }
| CREATE VIEW table_name left_paren view_column_list right_paren AS query_expression {
    flag_view_query(mut yylex, $8.v as QueryExpression)
    $$.v = yy_box(ViewDefinition{
      view_name:      $3.v as Identifier
      columns:        $5.v as []Identifier
      query:          $8.v as QueryExpression
      has_parameters: has_dynamic_parameters(yylex)
    })
  }

view_column_list:
  column_name_list { $$.v = $1.v }

%%
