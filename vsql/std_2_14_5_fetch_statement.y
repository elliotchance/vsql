%%

// ISO/IEC 9075-2:2023, 14.5, <fetch statement>
//
// Position a standing cursor on a specified row of the standing cursor's result
// set and retrieve values from that row.

// A <fetch statement> doesn't have a <fetch target list> (the row is returned
// instead).
fetch_statement:
  FETCH cursor_name {
    flag(mut yylex, vsql_fetch_without_into)
    $$.v = yy_box(Stmt(FetchStatement{name: $2.v as string}))
  }
| FETCH FROM cursor_name {
    flag(mut yylex, vsql_fetch_without_into)
    $$.v = yy_box(Stmt(FetchStatement{name: $3.v as string}))
  }
| FETCH fetch_orientation FROM cursor_name {
    flag(mut yylex, vsql_fetch_without_into)
    $$.v = yy_box(Stmt(FetchStatement{$4.v as string, $2.v as FetchOrientation}))
  }

// ISO/IEC 9075-2:2023, 14.5, <fetch statement>, Conformance Rules, 1 to 6
fetch_orientation:
  NEXT {
    flag(mut yylex, 'F432')
    $$.v = yy_box(FetchOrientation{})
  }
| PRIOR {
    flag(mut yylex, 'F435')
    $$.v = yy_box(FetchOrientation{direction: .prior})
  }
| FIRST {
    flag(mut yylex, 'F433')
    $$.v = yy_box(FetchOrientation{direction: .first})
  }
| LAST {
    flag(mut yylex, 'F434')
    $$.v = yy_box(FetchOrientation{direction: .last})
  }
| ABSOLUTE simple_value_specification {
    flag(mut yylex, 'F436')
    $$.v = yy_box(FetchOrientation{
      direction: .absolute
      value:     $2.v as ValueSpecification
    })
  }
| RELATIVE simple_value_specification {
    flag(mut yylex, 'F437')
    $$.v = yy_box(FetchOrientation{
      direction: .relative
      value:     $2.v as ValueSpecification
    })
  }

%%
