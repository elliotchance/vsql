%%

// CREATE INDEX and DROP INDEX aren't part of the standard (see index.v). The
// name of the index can't be qualified, because it's always in the schema of
// the table.
create_index_statement:
  CREATE INDEX identifier ON table_name left_paren index_column_list
  right_paren {
    flag(mut yylex, vsql_create_index)
    $$.v = Stmt(CreateIndexStatement{
      index_name: new_table_identifier(($3.v as IdentifierChain).identifier)!
      table_name: $5.v as Identifier
      columns:    $7.v as []IndexColumn
    })
  }
| CREATE UNIQUE INDEX identifier ON table_name left_paren index_column_list
  right_paren {
    flag(mut yylex, vsql_create_index)
    flag(mut yylex, vsql_create_unique_index)
    $$.v = Stmt(CreateIndexStatement{
      unique:     true
      index_name: new_table_identifier(($4.v as IdentifierChain).identifier)!
      table_name: $6.v as Identifier
      columns:    $8.v as []IndexColumn
    })
  }
| CREATE INDEX if_not_exists identifier ON table_name left_paren
  index_column_list right_paren {
    flag(mut yylex, vsql_create_index)
    flag(mut yylex, vsql_create_index_if_not_exists)
    $$.v = Stmt(CreateIndexStatement{
      index_name:    new_table_identifier(($4.v as IdentifierChain).identifier)!
      table_name:    $6.v as Identifier
      columns:       $8.v as []IndexColumn
      if_not_exists: true
    })
  }
| CREATE UNIQUE INDEX if_not_exists identifier ON table_name left_paren
  index_column_list right_paren {
    flag(mut yylex, vsql_create_index)
    flag(mut yylex, vsql_create_unique_index)
    flag(mut yylex, vsql_create_index_if_not_exists)
    $$.v = Stmt(CreateIndexStatement{
      unique:        true
      index_name:    new_table_identifier(($5.v as IdentifierChain).identifier)!
      table_name:    $7.v as Identifier
      columns:       $9.v as []IndexColumn
      if_not_exists: true
    })
  }

index_column_list:
  index_column { $$.v = [$1.v as IndexColumn] }
| index_column_list comma index_column {
    $$.v = append_list($1.v as []IndexColumn, $3.v as IndexColumn)
  }

index_column:
  column_name {
    $$.v = IndexColumn{
      name: ($1.v as Identifier).sub_entity_name
    }
  }
| column_name ordering_specification {
    $$.v = IndexColumn{
      name: ($1.v as Identifier).sub_entity_name
      desc: !($2.v as bool)
    }
  }

drop_index_statement:
  DROP INDEX schema_qualified_name {
    flag(mut yylex, vsql_drop_index)
    $$.v = Stmt(DropIndexStatement{
      index_name: new_table_identifier(($3.v as IdentifierChain).identifier)!
    })
  }
| DROP INDEX if_exists schema_qualified_name {
    flag(mut yylex, vsql_drop_index)
    flag(mut yylex, vsql_drop_index_if_exists)
    $$.v = Stmt(DropIndexStatement{
      index_name: new_table_identifier(($4.v as IdentifierChain).identifier)!
      if_exists:  true
    })
  }

%%
