%%

alter_column_definition:
  ALTER column_name alter_column_action {
    $$.v = AlterColumnDefinition{$2.v as Identifier, $3.v as AlterColumnAction}
  }
| ALTER COLUMN column_name alter_column_action {
    $$.v = AlterColumnDefinition{$3.v as Identifier, $4.v as AlterColumnAction}
  }

alter_column_action:
  set_column_default_clause {
    $$.v = AlterColumnAction($1.v as SetColumnDefaultClause)
  }
| drop_column_default_clause {
    $$.v = AlterColumnAction($1.v as DropColumnDefaultClause)
  }

%%
