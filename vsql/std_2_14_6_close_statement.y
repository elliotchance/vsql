%%

// ISO/IEC 9075-2:2023, 14.6, <close statement>
//
// Close a standing cursor.

close_statement:
  CLOSE cursor_name {
    flag(mut yylex, vsql_close_cursor)
    $$.v = yy_box(Stmt(CloseStatement{$2.v as string}))
  }

%%
