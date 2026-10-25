%%

alter_table_statement:
  ALTER TABLE table_name alter_table_action {
    $$.v = Stmt(AlterTableStatement{$3.v as Identifier, $4.v as AlterTableAction})
  }

alter_table_action:
  add_column_definition {
    $$.v = AlterTableAction($1.v as AddColumnDefinition)
  }
| alter_column_definition {
    $$.v = AlterTableAction($1.v as AlterColumnDefinition)
  }
| add_table_constraint_definition {
    $$.v = AlterTableAction($1.v as AddTableConstraintDefinition)
  }
| drop_table_constraint_definition {
    $$.v = AlterTableAction($1.v as DropTableConstraintDefinition)
  }

%%
