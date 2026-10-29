%%

set_column_default_clause:
  SET default_clause {
    flag(mut yylex, 'F381')
    $$.v = SetColumnDefaultClause{$2.v as DefaultOption}
  }

%%
