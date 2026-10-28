%%

// ISO/IEC 9075-2:2016(E), 14.3, <cursor specification>
//
// Define a result set.

cursor_specification:
  query_expression {
    flag_query_expression(mut yylex, $1.v as QueryExpression, .cursor)
    $$.v = Stmt($1.v as QueryExpression)
  }

%%
