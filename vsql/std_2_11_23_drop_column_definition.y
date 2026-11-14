%%

// ISO/IEC 9075-2:2023(E), 11.23, <drop column definition>
//
// Destroy a column of a base table.

// The <drop behavior> is optional (V105-01, see vsql_drop_column_behavior).
//
// ISO/IEC 9075-2:2023(E), 11.23, <drop column definition>, Conformance Rules, 1
drop_column_definition:
  DROP column_name {
    flag(mut yylex, 'F033')
    flag(mut yylex, vsql_drop_column_behavior)
    $$.v = yy_box(DropColumnDefinition{$2.v as Identifier, 'RESTRICT'})
  }
| DROP column_name drop_behavior {
    flag(mut yylex, 'F033')
    $$.v = yy_box(DropColumnDefinition{$2.v as Identifier, $3.v as string})
  }
| DROP COLUMN column_name {
    flag(mut yylex, 'F033')
    flag(mut yylex, vsql_drop_column_behavior)
    $$.v = yy_box(DropColumnDefinition{$3.v as Identifier, 'RESTRICT'})
  }
| DROP COLUMN column_name drop_behavior {
    flag(mut yylex, 'F033')
    $$.v = yy_box(DropColumnDefinition{$3.v as Identifier, $4.v as string})
  }

%%
