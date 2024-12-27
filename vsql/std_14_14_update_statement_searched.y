%%

update_statement_searched:
  UPDATE target_table SET set_clause_list {
	  $$.v = Stmt(UpdateStatementSearched{$2.v as Identifier,
      $4.v as map[string]UpdateSource, none})
  }
| UPDATE target_table SET set_clause_list WHERE search_condition {
    $$.v = Stmt(UpdateStatementSearched{$2.v as Identifier,
      $4.v as map[string]UpdateSource, $6.v as BooleanValueExpression})
  }

%%
