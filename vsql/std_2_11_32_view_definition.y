%%

// ISO/IEC 9075-2:2023, 11.32, <view definition>
//
// There's no RECURSIVE (T131, #1284), WITH CHECK OPTION (F311-04, #1258) or
// <referenceable view specification> (S043). The query is kept as it was
// written (see written_view_query).
view_definition:
  CREATE VIEW table_name AS query_expression {
    $$.v = yy_box(ViewDefinition{
      table_name: $3.v as Identifier
      query:      $5.v as QueryExpression
      text:       written_view_query(mut yylex, yyrcvr.char >= 0)
    })
  }
| CREATE VIEW table_name left_paren view_column_list right_paren AS
  query_expression {
    $$.v = yy_box(ViewDefinition{
      table_name: $3.v as Identifier
      columns:    $5.v as []Identifier
      query:      $8.v as QueryExpression
      text:       written_view_query(mut yylex, yyrcvr.char >= 0)
    })
  }

view_column_list:
  column_name_list { $$.v = $1.v }

%%
