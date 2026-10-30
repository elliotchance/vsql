%%

// ISO/IEC 9075-2:2016(E), 14.4, <open statement>
//
// Open a standing cursor.

open_statement:
  OPEN cursor_name {
    flag(mut yylex, vsql_open_cursor)
    $$.v = Stmt(OpenStatement{$2.v as string})
  }

%%
