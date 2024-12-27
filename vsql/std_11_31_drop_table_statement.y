%%

drop_table_statement:
  DROP TABLE table_name { $$.v = Stmt(DropTableStatement{$3.v as Identifier}) }

%%
