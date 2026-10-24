%%

alter_table_statement:
  ALTER TABLE table_name alter_table_action {
    $$.v = Stmt(AlterTableStatement{$3.v as Identifier, $4.v as AddColumnDefinition})
  }

alter_table_action:
  add_column_definition { $$.v = $1.v as AddColumnDefinition }

%%
