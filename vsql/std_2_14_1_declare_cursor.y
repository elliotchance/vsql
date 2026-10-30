%%

// ISO/IEC 9075-2:2016(E), 14.1, <declare cursor>
//
// Declare a standing cursor.

declare_cursor:
  DECLARE cursor_name cursor_properties FOR query_expression {
    flag(mut yylex, vsql_declare_cursor)
    flag_query_expression(mut yylex, $5.v as QueryExpression, .cursor)
    $$.v = Stmt(DeclareCursor{$2.v as string, $3.v as bool,
      $5.v as QueryExpression, none})
  }
| DECLARE cursor_name cursor_properties FOR query_expression
  updatability_clause {
    flag(mut yylex, vsql_declare_cursor)
    flag_query_expression(mut yylex, $5.v as QueryExpression, .cursor)
    flag_updatability_clause(mut yylex, $5.v as QueryExpression,
      $6.v as UpdatabilityClause)
    $$.v = Stmt(DeclareCursor{$2.v as string, $3.v as bool,
      $5.v as QueryExpression, $6.v as UpdatabilityClause})
  }

%%
