%%

cursor_specification:
  query_expression { $$.v = Stmt($1.v as QueryExpression) }

%%
