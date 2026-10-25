%%

set_column_default_clause:
  SET default_clause {
    $$.v = SetColumnDefaultClause{$2.v as DefaultOption}
  }

%%
