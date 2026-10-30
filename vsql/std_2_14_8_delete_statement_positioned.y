%%

// ISO/IEC 9075-2:2016(E), 14.8, <delete statement: positioned>
//
// Delete a row of a table.

delete_statement_positioned:
  DELETE FROM target_table WHERE CURRENT OF cursor_name {
    flag(mut yylex, vsql_delete_positioned)
    $$.v = Stmt(DeleteStatementPositioned{$3.v as Identifier, $7.v as string})
  }

target_table:
  table_name { $$.v = $1.v as Identifier }

%%
