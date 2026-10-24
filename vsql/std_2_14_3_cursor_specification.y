%%

// ISO/IEC 9075-2:2016(E), 14.3, <cursor specification>
//
// Define a result set.

cursor_specification:
  query_expression { $$.v = Stmt($1.v as QueryExpression) }

%%
