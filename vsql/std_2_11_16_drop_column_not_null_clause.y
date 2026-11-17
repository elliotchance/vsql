%%

// ISO/IEC 9075-2:2023, 11.16, <drop column not null clause>, Conformance Rules, 1
drop_column_not_null_clause:
  DROP NOT NULL {
    flag(mut yylex, 'F383')
    $$.v = yy_box(DropColumnNotNullClause{})
  }

%%
