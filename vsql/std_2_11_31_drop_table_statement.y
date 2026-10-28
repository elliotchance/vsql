%%

drop_table_statement:
  DROP TABLE table_name {
    flag(mut yylex, vsql_drop_table_behavior)
    $$.v = Stmt(DropTableStatement{$3.v as Identifier, 'RESTRICT'})
  }
| DROP TABLE table_name drop_behavior {
    flag_if(mut yylex, $4.v as string == 'CASCADE', 'F032')
    $$.v = Stmt(DropTableStatement{$3.v as Identifier, $4.v as string})
  }

%%
