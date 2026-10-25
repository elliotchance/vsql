%%

exists_predicate:
  EXISTS table_subquery {
    $$.v = ExistsPredicate{new_subquery(($2.v as TablePrimary).body as QueryExpression)}
  }

%%
