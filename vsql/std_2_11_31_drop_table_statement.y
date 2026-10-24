%%

drop_table_statement:
  DROP TABLE table_name {
    $$.v = Stmt(DropTableStatement{$3.v as Identifier, 'RESTRICT'})
  }
| DROP TABLE table_name drop_behavior {
    $$.v = Stmt(DropTableStatement{$3.v as Identifier, $4.v as string})
  }

%%
