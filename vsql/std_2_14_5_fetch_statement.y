%%

// ISO/IEC 9075-2:2016(E), 14.5, <fetch statement>
//
// Position a standing cursor on a specified row of the standing cursor's result
// set and retrieve values from that row.

// A <fetch statement> doesn't have a <fetch target list> (the row is returned
// instead).
fetch_statement:
  FETCH cursor_name {
    flag(mut yylex, vsql_fetch_without_into)
    $$.v = Stmt(FetchStatement{name: $2.v as string})
  }
| FETCH FROM cursor_name {
    flag(mut yylex, vsql_fetch_without_into)
    $$.v = Stmt(FetchStatement{name: $3.v as string})
  }
| FETCH fetch_orientation FROM cursor_name {
    flag(mut yylex, vsql_fetch_without_into)
    flag(mut yylex, 'F431')
    $$.v = Stmt(FetchStatement{$4.v as string, $2.v as FetchOrientation})
  }

fetch_orientation:
  NEXT { $$.v = FetchOrientation{} }
| PRIOR { $$.v = FetchOrientation{direction: .prior} }
| FIRST { $$.v = FetchOrientation{direction: .first} }
| LAST { $$.v = FetchOrientation{direction: .last} }
| ABSOLUTE simple_value_specification {
    $$.v = FetchOrientation{
      direction: .absolute
      value:     $2.v as ValueSpecification
    }
  }
| RELATIVE simple_value_specification {
    $$.v = FetchOrientation{
      direction: .relative
      value:     $2.v as ValueSpecification
    }
  }

%%
