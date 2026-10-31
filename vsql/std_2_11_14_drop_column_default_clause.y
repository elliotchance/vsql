%%

// ISO/IEC 9075-2:2016(E), 11.14, <drop column default clause>, Conformance Rules, 1
drop_column_default_clause:
  DROP DEFAULT {
    flag(mut yylex, 'F381')
    $$.v = DropColumnDefaultClause{}
  }

%%
