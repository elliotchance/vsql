%%

drop_column_default_clause:
  DROP DEFAULT {
    flag(mut yylex, 'F381')
    $$.v = DropColumnDefaultClause{}
  }

%%
