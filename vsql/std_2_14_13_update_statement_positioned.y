%%

// ISO/IEC 9075-2:2016(E), 14.13, <update statement: positioned>
//
// Update a row of a table.

update_statement_positioned:
  UPDATE target_table SET set_clause_list WHERE CURRENT OF cursor_name {
    flag(mut yylex, vsql_update_positioned)
    $$.v = Stmt(UpdateStatementPositioned{$2.v as Identifier,
      $4.v as []SetClause, $8.v as string})
  }

%%
