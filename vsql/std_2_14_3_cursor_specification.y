%%

// ISO/IEC 9075-2:2016(E), 14.3, <cursor specification>
//
// Define a result set.

cursor_specification:
  query_expression {
    flag_query_expression(mut yylex, $1.v as QueryExpression, .cursor)
    $$.v = Stmt($1.v as QueryExpression)
  }

// An <updatability clause> is only supported in a <declare cursor>, see
// declare_cursor.
updatability_clause:
  FOR READ ONLY { $$.v = UpdatabilityClause{} }
| FOR UPDATE { $$.v = UpdatabilityClause{for_update: true} }
| FOR UPDATE OF column_name_list {
    $$.v = UpdatabilityClause{true, $4.v as []Identifier}
  }

%%
