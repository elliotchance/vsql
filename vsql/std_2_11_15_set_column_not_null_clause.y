%%

// ISO/IEC 9075-2:2023, 11.15, <set column not null clause>, Conformance Rules, 1
set_column_not_null_clause:
  SET NOT NULL {
    flag(mut yylex, 'F383')
    $$.v = yy_box(SetColumnNotNullClause{})
  }

%%
