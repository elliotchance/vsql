%%

// ISO/IEC 9075-2:2023, 11.13, <set column default clause>, Conformance Rules, 1
set_column_default_clause:
  SET default_clause {
    flag(mut yylex, 'F387')
    $$.v = yy_box(SetColumnDefaultClause{$2.v as DefaultOption})
  }

%%
