%%

// ISO/IEC 9075-2:2016(E), 14.5, <fetch statement>
//
// Position a standing cursor on a specified row of the standing cursor's result
// set and retrieve values from that row.

// A <fetch statement> doesn't have a <fetch target list> (the row is returned
// instead). Only the NEXT <fetch orientation> is supported.
fetch_statement:
  FETCH cursor_name {
    flag(mut yylex, vsql_fetch_without_into)
    $$.v = Stmt(FetchStatement{$2.v as string})
  }
| FETCH FROM cursor_name {
    flag(mut yylex, vsql_fetch_without_into)
    $$.v = Stmt(FetchStatement{$3.v as string})
  }
| FETCH NEXT FROM cursor_name {
    flag(mut yylex, vsql_fetch_without_into)
    flag(mut yylex, 'F431')
    $$.v = Stmt(FetchStatement{$4.v as string})
  }

%%
