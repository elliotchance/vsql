%%

// ISO/IEC 9075-2:2023, 11.19, <alter column data type clause>, Conformance Rules, 1
alter_column_data_type_clause:
  SET DATA TYPE data_type {
    flag(mut yylex, 'F382')
    $$.v = yy_box(AlterColumnDataTypeClause{$4.v as Type})
  }

%%
