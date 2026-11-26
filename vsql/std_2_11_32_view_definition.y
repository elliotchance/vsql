%%

// ISO/IEC 9075-2:2023, 11.32, <view definition>
//
// There's no <referenceable view specification> (S043). The query is kept as
// it was written (see written_view_query), except for a RECURSIVE view (see
// recursive_view_definition), which can't have a CHECK OPTION.
//
// ISO/IEC 9075-2:2023, 11.32, <view definition>, Syntax Rules, 9.c
view_definition:
  CREATE VIEW table_name AS query_expression {
    $$.v = yy_box(ViewDefinition{
      table_name: $3.v as Identifier
      query:      $5.v as QueryExpression
      text:       written_view_query(mut yylex, yyrcvr.char >= 0, 0)
    })
  }
| CREATE VIEW table_name AS query_expression view_check_option {
    check := $6.v as ViewCheckOption
    $$.v = yy_box(ViewDefinition{
      table_name:   $3.v as Identifier
      query:        $5.v as QueryExpression
      text:         written_view_query(mut yylex, yyrcvr.char >= 0, check.tokens)
      check_option: check.level
    })
    flag_view_check_option(mut yylex, yyrcvr.char >= 0, check.tokens)
  }
| CREATE VIEW table_name left_paren view_column_list right_paren AS
  query_expression {
    $$.v = yy_box(ViewDefinition{
      table_name: $3.v as Identifier
      columns:    $5.v as []Identifier
      query:      $8.v as QueryExpression
      text:       written_view_query(mut yylex, yyrcvr.char >= 0, 0)
    })
  }
| CREATE VIEW table_name left_paren view_column_list right_paren AS
  query_expression view_check_option {
    check := $9.v as ViewCheckOption
    $$.v = yy_box(ViewDefinition{
      table_name:   $3.v as Identifier
      columns:      $5.v as []Identifier
      query:        $8.v as QueryExpression
      text:         written_view_query(mut yylex, yyrcvr.char >= 0, check.tokens)
      check_option: check.level
    })
    flag_view_check_option(mut yylex, yyrcvr.char >= 0, check.tokens)
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

// A CHECK OPTION without a <levels clause> is CASCADED.
//
// ISO/IEC 9075-2:2023, 11.32, <view definition>, Syntax Rules, 16
view_check_option:
  WITH CHECK OPTION { $$.v = yy_box(ViewCheckOption{'CASCADED', 3}) }
| WITH levels_clause CHECK OPTION { $$.v = $2.v }

// ISO/IEC 9075-2:2023, 11.32, <view definition>, Conformance Rules, 2
levels_clause:
  CASCADED {
    $$.v = yy_box(ViewCheckOption{'CASCADED', 4})
    flag(mut yylex, 'F751')
  }
| LOCAL {
    $$.v = yy_box(ViewCheckOption{'LOCAL', 4})
    flag(mut yylex, 'F751')
  }

%%
