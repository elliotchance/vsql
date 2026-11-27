%%

// ISO/IEC 9075-2:2023, 11.32, <view definition>
//
// There's no WITH CHECK OPTION (F311-04, #1258) or <referenceable view
// specification> (S043). The query is kept as it was written (see
// written_view_query), except for a RECURSIVE view (see
// recursive_view_definition).
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

| recursive_view_head query_expression {
    $$.v = yy_box(recursive_view_definition(mut yylex, $1.v as RecursiveViewHead,
      $2.v as QueryExpression, yyrcvr.char >= 0)!)
  }

// The name of a RECURSIVE view is in scope in its query, so it's known before
// the query is parsed.
recursive_view_head:
  CREATE RECURSIVE VIEW table_name AS {
    $$.v = yy_box(recursive_view_head(mut yylex, $4.v as Identifier, []Identifier{})!)
  }
| CREATE RECURSIVE VIEW table_name left_paren view_column_list right_paren AS {
    $$.v = yy_box(recursive_view_head(mut yylex, $4.v as Identifier,
      $6.v as []Identifier)!)
  }

view_column_list:
  column_name_list { $$.v = $1.v }

%%
