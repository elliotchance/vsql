%%

where_clause:
  WHERE search_condition { $$.v = $2.v as BooleanValueExpression }

%%
