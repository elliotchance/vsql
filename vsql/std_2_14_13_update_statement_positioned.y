%%

// ISO/IEC 9075-2:2023(E), 14.13, <update statement: positioned>
//
// Update a row of a table.

update_statement_positioned:
  UPDATE target_table target_correlation_name SET set_clause_list WHERE CURRENT OF cursor_name {
    flag(mut yylex, vsql_update_positioned)
    $$.v = yy_box(Stmt(UpdateStatementPositioned{$2.v as Identifier,
      $3.v as Identifier, $5.v as []SetClause, $9.v as string}))
  }

%%
