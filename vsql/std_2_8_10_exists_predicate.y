%%

exists_predicate:
  EXISTS table_subquery {
    flag_exists(mut yylex, ($2.v as TablePrimary).body as QueryExpression)
    $$.v = ExistsPredicate{new_subquery(($2.v as TablePrimary).body as QueryExpression)}
  }

%%
