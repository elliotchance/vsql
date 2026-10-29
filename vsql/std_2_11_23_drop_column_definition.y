%%

// ISO/IEC 9075-2:2016(E), 11.23, <drop column definition>
//
// Destroy a column of a base table.

drop_column_definition:
  DROP column_name {
    flag(mut yylex, 'F033')
    flag(mut yylex, vsql_drop_column_behavior)
    $$.v = DropColumnDefinition{$2.v as Identifier, 'RESTRICT'}
  }
| DROP column_name drop_behavior {
    flag(mut yylex, 'F033')
    $$.v = DropColumnDefinition{$2.v as Identifier, $3.v as string}
  }
| DROP COLUMN column_name {
    flag(mut yylex, 'F033')
    flag(mut yylex, vsql_drop_column_behavior)
    $$.v = DropColumnDefinition{$3.v as Identifier, 'RESTRICT'}
  }
| DROP COLUMN column_name drop_behavior {
    flag(mut yylex, 'F033')
    $$.v = DropColumnDefinition{$3.v as Identifier, $4.v as string}
  }

%%
