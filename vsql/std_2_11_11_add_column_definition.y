%%

add_column_definition:
  ADD column_definition {
    $$.v = yy_box(AddColumnDefinition{$2.v as []TableElement})
  }
| ADD COLUMN column_definition {
    $$.v = yy_box(AddColumnDefinition{$3.v as []TableElement})
  }

%%
