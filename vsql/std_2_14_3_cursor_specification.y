%%

// ISO/IEC 9075-2:2023(E), 14.3, <cursor specification>
//
// Define a result set.

cursor_specification:
  query_expression {
    flag_query_expression(mut yylex, $1.v as QueryExpression, .cursor)
    $$.v = yy_box(Stmt($1.v as QueryExpression))
  }
| query_expression updatability_clause {
    flag_query_expression(mut yylex, $1.v as QueryExpression, .cursor)
    flag_updatability_clause(mut yylex, $1.v as QueryExpression,
      CursorProperties{}, $2.v as UpdatabilityClause)
    $$.v = yy_box(Stmt(new_cursor_specification($1.v as QueryExpression,
      $2.v as UpdatabilityClause)))
  }

// An <updatability clause> of a <dynamic select statement> is used when the
// query is opened as a cursor by the SQL/CLI (or by an SQL-client module), see
// PreparedStmt.open_cursor. A query that's executed without a cursor can't
// have one (see PreparedStmt.query_internal).
updatability_clause:
  FOR READ ONLY { $$.v = yy_box(UpdatabilityClause{}) }
| FOR UPDATE { $$.v = yy_box(UpdatabilityClause{for_update: true}) }
| FOR UPDATE OF column_name_list {
    $$.v = yy_box(UpdatabilityClause{true, $4.v as []Identifier})
  }

%%
