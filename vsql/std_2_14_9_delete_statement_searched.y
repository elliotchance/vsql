%%

delete_statement_searched:
  DELETE FROM target_table {
    $$.v = Stmt(DeleteStatementSearched{$3.v as Identifier, none})
  }
| DELETE FROM target_table WHERE search_condition {
    $$.v = Stmt(DeleteStatementSearched{
      $3.v as Identifier
      $5.v as BooleanValueExpression
    })
  }

%%
